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
      
=begin rdoc
Returns an editor associated with the given document, creating it if needed

It works as {MainWindow#editor_for!}.

_hints_ may contain the same values as in {MainWindow#editor_for!}. It may also
contain another value, @:close_starting_document@
@param [Document] doc the document to retrieve an editor for
@param hints (see MainWindow#editor_for!)
@option hints [Boolean] :close_starting_document (false) if given, specifies that
  the default document created by ruber at startup exists and it's in the first
  tab. If a new view is created in a new tab, this document is closed
@return [EditorView] the view to use for the document
=end
      def editor_for doc, hints
        editor = @solver.find_editor doc, hints
        if !editor and hints[:create_if_needed]
          editor = create_editor doc
          if hints[:show]
            view = @solver.place_editor hints
            if view 
              dir = Qt.const_get hints[:split].to_s.capitalize
              view.parent.split view, editor, dir
            else 
              if hints[:close_starting_document]
                if @tabs.count == 1 and @tabs.widget(0).single_view?
                  doc_to_close = @tabs.widget(0).view.document
                end
              end
              add_tab editor, doc.icon, doc.document_name
#               new_tab = Pane.new(editor)
#               @tabs.add_tab new_tab, doc.icon, doc.document_name
#               new_tab.connect(SIGNAL('closing_last_view(QWidget*)')) do
#                 idx = @tabs.index_of new_tab
#                 if idx
#                   @focus_editors.delete_at idx
#                   @tabs.remove_tab idx 
#                 end
#               end
              doc_to_close.close if doc_to_close
            end
            editor.parent.label = label_for_editor editor
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
      
      def make_editor_active editor
        return if editor and @active_editor == editor
        deactivate_editor @active_editor
        @active_editor = editor
        if editor
          parent.gui_factory.add_client editor.send(:internal)
          @activation_order.delete editor
          @activation_order.insert 0, editor
          editor_tab = tab(editor)
          tab_idx = @tabs.index_of editor_tab 
          @focus_editors[tab_idx] = editor
          update_tab editor_tab
          editor.document.activate
        end
        emit active_editor_changed @active_editor
        @active_editor
      end
      
      def deactivate_editor view
        return unless view and view == @active_editor
        @active_editor.document.deactivate
        parent.gui_factory.remove_client view.send(:internal)
        @active_editor = nil
      end
      
      def without_activating
        begin
          @auto_activate_editors = false
          yield
        ensure
          @auto_activate_editors = true
          if @tabs.current_index < 0 then make_editor_active nil
          else make_editor_active @focus_editors[@tabs.current_index]
          end
        end
      end
      
=begin rdoc
The toplevel pane corresponding to the given index or widget

@overload tab idx
  @param [Integer] idx the index of the tab
  @return [Pane] the toplevel pane in the tab number _idx_
@overload tab editor
  @param [EditorView] editor the editor to retrieve the pane for
  @return [Pane,nil] the toplevel pane containing the given editor or *nil* if the
    view isn't contained in a pane
@overload tab pane
  @param [Pane] pane the pane to retrieve the toplevel pane for
  @return [Pane, nil] the toplevel pane containing the given pane or *nil* if the
    pane isn't contained in another pane
=end
      def tab arg
        if arg.is_a? Integer then @tabs.widget arg
        else
          pane = arg.is_a?(Pane) ? arg : arg.parent
          return unless pane
          pane = pane.parent_pane while pane.parent_pane
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
      
      def label_for_editor ed
        url = ed.document.url
        if url.valid? then url.local_file? ? url.path : url.pretty_url
        else ed.document.document_name
        end
      end
      
      private
      
      def add_tab view, icon, label
        new_tab = Pane.new(view)
        @tabs.add_tab new_tab, icon, label
        connect new_tab, SIGNAL('closing_last_view(QWidget*)'), self, SLOT('remove_tab(QWidget*)')
        connect new_tab, SIGNAL('pane_split(QWidget*, QWidget*, QWidget*)'), self, SLOT('update_tab(QWidget*)')
        connect new_tab, SIGNAL('removing_view(QWidget*, QWidget*)'), self, SLOT('update_tab(QWidget*)')
        connect new_tab, SIGNAL('view_replaced(QWidget*, QWidget*, QWidget*)'), self, SLOT('update_tab(QWidget*)')
      end
      
      def remove_tab pane
        idx = @tabs.index_of pane
        if idx
          @focus_editors.delete_at idx
          @tabs.remove_tab idx 
        end
      end
      slots 'remove_tab(QWidget*)'

      def focus_in_view view
#         active = active_editor
        if view != @active_editor
          make_editor_active view #if active_editor
        end
      end
      slots 'focus_in_view(QWidget*)'
      
      def view_closing view
        @activation_order.delete view
        disconnect view, SIGNAL('focus_in(QWidget*)'), self, SLOT('focus_in_view(QWidget*)')
        deactivate_editor view
#         idx = @focus_editors.each_index.find{|i| @focus_editors[i] == view}
#         @focus_editors[idx] = nil if idx
      end
      slots 'view_closing(QWidget*)'
      
      def current_tab_changed idx
        if idx > -1
          @focus_editors[idx] ||= @tabs.widget(idx).to_a[0]
          ed = @focus_editors[idx]
          if @auto_activate_editors then ed.set_focus
          else make_editor_active nil
          end
        else
          make_editor_active nil
        end
      end
      slots 'current_tab_changed(int)'
      
      def update_tab pane
        idx = @tabs.index_of tab(pane)
        return if idx < 0
        doc = @focus_editors[idx].document
        @tabs.set_tab_text idx, doc.document_name
        @tabs.set_tab_icon idx, doc.icon
        pane.each_pane{|pn| pn.label = label_for_editor(pn.view) if pn.single_view?}
        update_tool_tip idx
      end
      slots 'update_tab(QWidget*)'
      
      def update_tool_tip idx, *ignore
        docs = @tabs.widget(idx).reject{|v| ignore.include? v}.map{|v| v.document.document_name}.uniq
        @tabs.set_tab_tool_tip idx, docs.join("\n")
      end
      
    end
    
  end
  
end