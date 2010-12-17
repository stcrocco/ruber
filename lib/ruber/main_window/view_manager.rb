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

require 'ruber/main_window/hint_solver'
require 'ruber/pane'

module Ruber
  
  class MainWindow
    
    class ViewManager < Qt::Object
      
      attr_reader :part_manager, :active_editor
      
      attr_accessor :auto_activate_editors
      
      signals 'view_created(QWidget*)'
      
      signals 'active_editor_changed(QWidget*)'
      
      def initialize tabs, parent
        super parent
        @tabs = tabs
        @focus_editors = []
        @part_manager = KParts::PartManager.new parent, self
        @activation_order = []
        @active_editor = nil
        @solver = MainWindow::HintSolver.new @tabs, @part_manager, @activation_order
        @auto_activate_editors = true
        connect @tabs, SIGNAL('currentChanged(int)'), self, SLOT('current_tab_changed(int)')
      end
      
      def editor_for doc, hints
        editor = @solver.find_editor doc, hints
        if !editor and hints[:create_if_needed]
          editor = create_editor doc
          if hints[:show]
            view = @solver.place_editor hints
            if view then view.parent.split view, editor, hints[:split]
            else @tabs.add_tab Pane.new(editor), doc.icon, doc.document_name
            end
          end
        end
        editor
      end
      
      def create_editor doc
        editor = doc.create_view
        connect editor, SIGNAL('focus_in(QWidget*)'), self, SLOT('focus_in_view(QWidget*)')
        connect editor, SIGNAL('closing(QWidget*)'), self, SLOT('view_closing(QWidget*)')
        editor
      end
      
      def activate_editor view
        return if @active_editor == view
        deactivate_editor @active_editor if @active_editor
        @part_manager.active_part = view.document.send(:internal) rescue nil
        if view
          @active_editor = view
          @activation_order.delete view
          @activation_order.insert 0, view
          parent.gui_factory.add_client view.send(:internal)
          tab_idx = @tabs.index_of tab(view)
          @focus_editors[tab_idx] = view
          @tabs.current_index = tab_idx
          emit active_editor_changed(view)
          view.document.activate
        end
        @active_editor
      end
      
      def deactivate_editor view
        return unless view and view == @active_editor
        @active_editor.document.deactivate
        parent.gui_factory.remove_client view.send( :internal)
        @active_editor = nil
      end
      
      def without_activating
        begin
          @auto_activate_editors = false
          yield
        ensure
          @auto_activate_editors = true
          if @tabs.current_index < 0 then activate_editor nil
          else activate_editor @focus_editors[@tabs.current_index]
          end
        end
      end
      
=begin rdoc
The toplevel pane corresponding to the given index or editor

@overload tab idx
  @param [Integer] idx the index of the tab
  @return [Pane] the toplevel pane in the tab number _idx_
@overload tab editor
  @param [EditorView] editor the editor to retrieve the pane for
  @return [Pane] the toplevel pane containing the given editor
=end
      def tab arg
        if arg.is_a? Integer then @tabs.widget arg
        else
          pane = arg.parent
          pane = pane.parent_pane while pane && pane.parent_pane
          pane
        end
      end
      
=begin rdoc
Whether the given view is a focus editor

@overload focus_editor? editor
  Whether the given view is the focus editor for any tab
  @param [EditorView] editor the view to test
  @return [Boolean] *true* if there's a tab which has _editor_ as focus editor and
    *false* otherwise
@overload focus_editor? editor, tab
  Whether the given view is the focus editor for the given tab
  @param [EditorView] editor the view to test
  @param [Pane,Integer] tab the tab the view must be focus editor for. If a {Pane}
    it must be the toplevel pane of the tab; if an @Integer@, it must be the index
    of the pane to test
  @note this method doesn't test whether _tab_ actually is a toplevel pane
  @return [Boolean] *true* if _editor_ is the focus widget for _tab_ and
    *false* otherwise
=end
      def focus_editor? editor, tab = nil
        if tab 
          tab = @tabs.index_of(tab) unless tab.is_a? Integer
          @focus_editors[tab] == editor
        else @focus_editors.any?{|k, v| v == editor}
        end
      end
      
      private
            
      def focus_in_view view
        active = active_editor
        if view != active
          activate_editor view if active and view.document == active.document
        end
      end
      slots 'focus_in_view(QWidget*)'
      
      def view_closing view
        @activation_order.delete view
        deactivate_editor view if @active_editor == view
        idx = @focus_editors.each_index.find{|i| @focus_editors[i] == view}
        @focus_editors[idx] = nil if idx
      end
      slots 'view_closing(QWidget*)'
      
      def current_tab_changed idx
        if idx > -1
          @focus_editors[idx] ||= @tabs.widget(idx).to_a[0]
          activate_editor @auto_activate_editors ? @focus_editors[idx] : nil
        end
      end
      slots 'current_tab_changed(int)'
      
    end
    
  end
  
end