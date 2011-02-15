=begin 
    Copyright (C) 2010,2011 by Stefano Crocco   
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
    
=begin rdoc
Class which manages the views in the tab widget

It takes care of activating a view when it gets focus, removing a tab when the
last view in it is closed, and so on.

@note this class is only for internal use by {MainWindow}. Its API is likely to
  change and the whole class may disappear in the future. So, *do not* use it outside
  of {MainWindow}
=end
    class ViewManager < Qt::Object
      
=begin rdoc
@return [KDE::PartManager] the part manager which manages the document parts
=end
      attr_reader :part_manager
      
=begin rdoc
@return [EditorView,nil] the active editor (that is, the editor whose GUI is merged
  with the main window GUI) or *nil* if no main window exists
=end
      attr_reader :active_editor
      
=begin rdoc
@return [Array<EditorView>] a list of all the editors in all tabs, in activation
  order, from more recently activated to less recently activated
=end
      attr_reader :activation_order
      
=begin rdoc
@return [Boolean] whether to automatically activate an editor when it is created
=end
      attr_accessor :auto_activate_editors
      
=begin rdoc
@return [KDE::TabWidget] the tab widget containing the editors
=end
      attr_accessor :tabs
      
=begin rdoc
Signal emitted whenever an editor is created
@param [EditorView] editor the newly created editor
=end
      signals 'view_created(QWidget*)'
      
=begin rdoc
Signal emitted whenever the active editor changes

This signal is emitted _after_ the editor has become active
@param [EditorView,nil] editor the editor which become active or *nil* if no editor
  become active
=end
      signals 'active_editor_changed(QWidget*)'

=begin rdoc
@param [KDE::TabWidget] tabs the tab widget used by the main window
@param [Ruber::MainWindow] parent the main window
=end
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
            @activation_order << editor
            view = @solver.place_editor hints
            if view 
              dir = Qt.const_get hints[:split].to_s.capitalize
#               tab(view).split view, editor, dir
              view.parent.split view, editor, dir
            else 
              if hints[:close_starting_document]
                if @tabs.count == 1 and @tabs.widget(0).single_view?
                  doc_to_close = @tabs.widget(0).view.document
                end
              end
              add_tab editor, doc.icon, doc.document_name
              doc_to_close.close if doc_to_close
            end
            editor.parent.label = label_for_editor editor
          end
        end
        editor
      end
      
=begin rdoc
Makes the given editor active

Besides merging the editor's GUI with the main window's, this method also deactivates
the previously active editor, updates the activation order, activates the document
associated with the new active editor, updates the tab where the new editor is
and emits the {#active_editor_changed} signal.

Nothing is done if the given editor was already active
@param [EditorView] editor the editor to activate
@return [EditorView] the new active editor
=end
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
      
=begin rdoc
Deactivates the given editor

To deactivate the editor, its GUI is removed from the main window's and the corresponding
document is deactivated.

If the given editor wasn't the active one, nothing is done
@param [EditorView] view the editor to deactivate
@return [nil]
=end
      def deactivate_editor view
        return unless @active_editor and view == @active_editor
        @active_editor.document.deactivate
        parent.gui_factory.remove_client view.send(:internal)
        @active_editor = nil
        nil
      end

=begin rdoc
Executes a block without automatically activating editors

Usually, whenever a tab becomes active, one of the editors it contains becomes
active. Sometimes, you don't want this to happen (for example, when opening multiple
documents in sequence). To do so, do what you need from a block passed to this method.

After the block has been executed, the last activated method in the current tab
becomes active.

@yield the block to call without automatically activating editors
@return [Object] the value returned by the block
=end
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
      
=begin rdoc
The label to use for an editor

@param [EditorView] ed the editor to return the label for
@return [String] the text to show below the given editor
=end
      def label_for_editor ed
        url = ed.document.url
        if url.valid? then url.local_file? ? url.path : url.pretty_url
        else ed.document.document_name
        end
      end

      private
      
=begin rdoc
Creates an editor for a document

@param [Document] doc the document to create the editor for
@return [EditorView] the new editor for the document
=end
      def create_editor doc
        editor = doc.create_view
        connect editor, SIGNAL('focus_in(QWidget*)'), self, SLOT('focus_in_view(QWidget*)')
        connect editor, SIGNAL('closing(QWidget*)'), self, SLOT('view_closing(QWidget*)')
        editor
      end
      
=begin rdoc
Adds a new tab to the tab widget

The tab is created with a view inserted in it and is assigned an icon an a label
@param [EditorView] view the view to insert in the new pane
@param [Qt::Icon] icon the icon to associate with the new tab
@param [String] label the label to use for the new tab
@return [Pane] the pane corresponding to the new tab
=end
      def add_tab view, icon, label
        new_tab = Pane.new(view)
        idx = @tabs.add_tab new_tab, icon, label
        @focus_editors[idx] = view
        connect new_tab, SIGNAL('closing_last_view(QWidget*)'), self, SLOT('remove_tab(QWidget*)')
        connect new_tab, SIGNAL('pane_split(QWidget*, QWidget*, QWidget*)'), self, SLOT('update_tab(QWidget*)')
        connect new_tab, SIGNAL('removing_view(QWidget*, QWidget*)'), self, SLOT('update_tab(QWidget*)')
        connect new_tab, SIGNAL('view_replaced(QWidget*, QWidget*, QWidget*)'), self, SLOT('update_tab(QWidget*)')
        new_tab
      end
      
=begin rdoc
Removes the tab corresponding to the given toplevel pane

@param [Pane] pane the toplevel pane whose tab should be removed
@return [nil]
=end
      def remove_tab pane
        idx = @tabs.index_of pane
        if idx
          @focus_editors.delete_at idx
          @tabs.remove_tab idx 
        end
        nil
      end
      slots 'remove_tab(QWidget*)'

=begin rdoc
Slot called whenever a view receives focus

The views is activated, unless it was already active
@param [EditorView] view the view which received focus
@return [nil]
=end
      def focus_in_view view
        if view != @active_editor
          make_editor_active view
        end
        nil
      end
      slots 'focus_in_view(QWidget*)'
      
=begin rdoc
Slot called whenever a view is closed

It deactivates the view (if it was active), performs some cleanup and gives focus
to the editor which had focus before (if any).
@param [EditorView] view the view which is being closed
@return [nil]
=end
      def view_closing view
        view_tab = self.tab(view)
        has_focus = view_tab.is_active_window if view_tab
        if has_focus
          views = view_tab.to_a
          idx = views.index(view)
          new_view = views[idx-1] || views[idx+1]
        end
        @activation_order.delete view
        disconnect view, SIGNAL('focus_in(QWidget*)'), self, SLOT('focus_in_view(QWidget*)')
        deactivate_editor view
        if new_view
          make_editor_active new_view
          new_view.set_focus
        end
        nil
      end
      slots 'view_closing(QWidget*)'
      
=begin rdoc
Slot called whenever the current tab changes

Unless called from within a {#without_activating} block, it activates and gives focus
to the view in the new current tab which last got focus.

If called from within a {#without_activating} block, or if there's no current tab,
all editors are deactivated
@param [Integer] idx the index of the current tab
@return [nil]
=end
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
        nil
      end
      slots 'current_tab_changed(int)'
      
=begin rdoc
Updates the tab containing the given toplevel pane

Updating the tab means changing its icon, its label, its tooltip and the label
associated with each of the editors it contains
@param [Pane] pane the toplevel pane contained in the pane to update
@return [nil]
=end
      def update_tab pane
        idx = @tabs.index_of tab(pane)
        return if idx < 0
        doc = @focus_editors[idx].document
        @tabs.set_tab_text idx, doc.document_name
        @tabs.set_tab_icon idx, doc.icon
        pane.each_pane{|pn| pn.label = label_for_editor(pn.view) if pn.single_view?}
        update_tool_tip idx
        nil
      end
      slots 'update_tab(QWidget*)'
      
=begin rdoc
Updates the tooltip for the given tab

A pane's tooltip contains the list of the documents associated with the views in
the tab, separated by newlines.

@param [Integer] idx the index of the tab whose tooltip should be updated
@param [Array<EditorView>] ignore a list of views which shouldn't be considered
  when creating the tool tip. This is necessary because, when a view is closed,
  this method is called _before_ the view is removed from the pane, so the document
  associated with it would be included in the tooltip if it weren't specified here
@return [nil]
=end
      def update_tool_tip idx, *ignore
        docs = @tabs.widget(idx).reject{|v| ignore.include? v}.map{|v| v.document.document_name}.uniq
        @tabs.set_tab_tool_tip idx, docs.join("\n")
        nil
      end
      
    end
    
  end
  
end