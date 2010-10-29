=begin 
    Copyright (C) 2010 by Stefano Crocco   
    stefano.crocco@alice.it   
  
    This program is free software; you can redistribute it andor modify  
    it under the terms of the GNU General Public License as published by  
    the Free Software Foundation; either version 2 of the License, or     
    (at your option) any later version.                                   
  
    This program is distributed in the hope that it will be useful,       
    but WITHOUT ANY WARRANTY; without even the implied warranty of        
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         
    GNU General Public License for more details.                          
  
    You should have received a copy of the GNU General Public License     
    along with this program; if not, write to the                         
    Free Software Foundation, Inc.,                                       
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             
=end

require 'ktexteditor'
require 'facets/boolean'

require 'ruber/editor/ktexteditor_wrapper'

module Ruber

  class EditorView < Qt::Widget
    
    include KTextEditorWrapper
    
    signal_data = {
      'information_message' => ['KTextEditor::View*, QString', [1, nil]],
      'context_menu_about_to_show' => ['KTextEditor::View*, QMenu*', [1, nil]],
      'focus_in' => ['KTextEditor::View*', [nil]],
      'focus_out' => ['KTextEditor::View*', [nil]],
#       'selection_changed' => ['KTextEditor::View*', [nil]],
      'vertical_scroll_position_changed' => ['KTextEditor::View*, KTextEditor::Cursor', [1, nil]],
      'horizontal_scroll_position_changed' => ['KTextEditor::View*', [nil]],
      'text_inserted' => ['KTextEditor::View*, KTextEditor::Cursor, QString', [1, 2, nil]],
    }
    
    @signal_table = KTextEditorWrapper.prepare_wrapper_connections self, signal_data
    
    signals 'closing()', 'cursor_position_changed(KTextEditor::Cursor, QWidget*)', 
    'view_mode_changed(QString, QWidget*)', 'edit_mode_changed(KTextEditor::View::EditMode, QWidget*)',
    'selection_mode_changed(bool, QWidget*)', 'mouse_position_changed(KTextEditor::Cursor, QWidget*)',
    'selection_changed(QWidget*)'
    
    slots 'slot_selection_changed(KTextEditor::View*)'
    
#     @view.connect(SIGNAL('selectionChanged(KTextEditor::View*)')) do |v|
#       changed = @view.block_selection ^ @block_selection
#       if changed
#         @block_selection = @view.block_selection
#         emit selection_mode_changed @block_selection, self
#       end
#     end
    


#     signals 'closing()', 'information_message(QString, QObject*)', 
# 'cursor_position_changed(KTextEditor::Cursor, QObject*)', 
# 'view_mode_changed(QString, QObject*)', 'edit_mode_changed(KTextEditor::View::EditMode, QObject*)',
# 'selection_mode_changed(bool, QObject*)', 'context_menu_about_to_show(QMenu*, QObject*)',
# 'focus_in(QObject*)', 'focus_out(QObject*)', 'horizontal_scroll_position_changed(QObject*)',
# 'mouse_position_changed(KTextEditor::Cursor, QObject*)', 'selection_changed(QObject*)',
# 'text_inserted(KTextEditor::Cursor, QString, QObject*)', 'vertical_scroll_position_changed(KTextEditor::Cursor, QObject*)'

    attr_reader :doc
    alias_method :document, :doc
    def initialize doc, internal, parent = nil
      super parent
      @block_selection = false
      @doc = doc
      @view = internal
      @view.parent = self
      initialize_wrapper @view, self.class.instance_variable_get(:@signal_table)
      self.focus_proxy = @view
      self.layout = Qt::VBoxLayout.new self
      layout.set_contents_margins 0,0,0,0
      layout.spacing = 0
      layout.add_widget @view

      connect @view, SIGNAL('selectionChanged(KTextEditor::View*)'), self, SLOT('slot_selection_changed(KTextEditor::View*)')
      
      @view.connect(SIGNAL('cursorPositionChanged(KTextEditor::View*, KTextEditor::Cursor)'))do |v, c| 
        emit cursor_position_changed( @view.cursor_position_virtual, self)
      end
      @view.connect(SIGNAL('mousePositionChanged(KTextEditor::View*, KTextEditor::Cursor)')) do |v, c|
        emit mouse_position_changed( @view.cursor_position_virtual, self)
      end
      @view.connect(SIGNAL('viewModeChanged(KTextEditor::View*)')) do |v|
        emit view_mode_changed( view_mode, self)
      end
      @view.connect(SIGNAL('viewEditModeChanged(KTextEditor::View*, KTextEditor::View::EditMode)')) do |v, m|
        emit edit_mode_changed( m, self)
      end

      am = @doc.interface('annotation_interface').annotation_model
      am.connect(SIGNAL('annotations_changed()')) do
        show = Ruber[:config][:general, :auto_annotations] && am.has_annotations?
        set_annotation_border_visible(show) rescue NoMethodError
      end
      
      @view.context_menu = @view.default_context_menu(Qt::Menu.new(@view))
      
    end
    
    def go_to row, col
      @view.cursor_position = KTextEditor::Cursor.new(row, col)
    end

    def show_annotation_border
      set_annotation_border_visible true
    end

    def hide_annotation_border
      set_annotation_border_visible false
    end

    def block_selection?
      @view.block_selection.to_bool
    end

    def close
      emit closing
      super
    end

    def set_annotation_border_visible vis
      @view.qobject_cast(KTextEditor::AnnotationViewInterface).set_annotation_border_visible vis
    end

=begin rdoc
Executes the action with name the view's action
collection. This is made by having the action emit the <tt>triggered()</tt> or
<tt>toggled(bool)</tt> signal (depending on whether it's a standard action or a
<tt>KDE::ToggleAction</tt>). In the second case, _arg_ is the argument passed to
the signal.

Returns *true* if an action with name _name_ was found and *false* otherwise.
=end
    def execute_action name, arg = nil
      a = action_collection.action(name)
      case a
      when KDE::ToggleAction then a.instance_eval{emit toggled(arg)}
      when nil then return false
      else a.instance_eval{emit triggered}
      end
      true
    end
    
    private
    
    def slot_selection_changed v
      emit selection_changed(self)
      changed = @view.block_selection ^ @block_selection
      if changed
        @block_selection = @view.block_selection
        emit selection_mode_changed(@block_selection, self)
      end
    end

  end

end
