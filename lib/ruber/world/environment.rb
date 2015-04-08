=begin 
    Copyright (C) 2011 by Stefano Crocco   
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

require 'ruber/world/hint_solver'
require 'ruber/world/document_list'

module Ruber
  
  module World
    
=begin rdoc
An environment contains everything related to a project. Currently, this means
the project itself, and any editors opened while the project was active.

An environment also contains and manages the tab widget where the views are
displayed.

Environments can also be created without being associated with a project. There's
a single environment of this kind, which constitutes the default environment.

An environment without a project, when created, contains a special document,
called the default document, which will be closed (unless modified, of course),
as soon as a new view is created in the environment.

Currently, environments associated with projects are implemented using project
extensions. This is only an implementation detail, however, and should have no
effect on users of this class.
=end
    class Environment < Qt::Object

=begin rdoc
Helper class containing a list of views
=end
     class ViewList
        
=begin rdoc
@return [<EditorView>] a list of the views existing in the environment in
  activation order, from the most recently activated to the last recently
  activated
=end
attr_reader :by_activation
       
=begin rdoc
A list of the views in the environment sorted according to the document
they're associated with

@return [{Document => <EditorView>}] a list of the documents in the environment
  sorted according to the document they're associated with. Each element of the
  hash is an array containing all the views associated with the document representing
  the corresponding key. Views for a single view are sorted in activation order
=end
        attr_reader :by_document
        
=begin rdoc
A list of the views in the environment sorted according to the tab they belong
to

@return [{Pane => <EditorView>}] a hash whose keys are the toplevel {Pane}s
  corresponding to the various tabs in the environment. The values are arrays
  containing all the views in the pane, sorted by activation order
=end
        attr_reader :by_tab
        
=begin rdoc
A list of the tabs in the environment, sorted by views

@return [{EditorView => Pane}] a hash associating views to panes, so that each
  view is the key having the pane containing it as value
=end
        attr_reader :tabs
        
        def initialize
          @by_activation = []
          @by_tab = {}
          @by_document = {}
          @tabs = {}
        end
        
=begin rdoc
Adds a view to the list

@param [EditorView] view the view to add
@param [Pane] tab the toplevel pane the view is in
@return [EditorView] _view_
=end
        def add_view view, tab
          @by_activation << view
          (@by_tab[tab] ||= []) << view
          (@by_document[view.document] ||= []) << view
          @tabs[view] = tab
          view
        end
        
=begin rdoc
Removes a view from the list
@param [EditorView] view the view to remove
@return [EditorView] _view_
=end
        def remove_view view
          tab = @tabs[view]
          @by_activation.delete view
          @by_tab[tab].delete view
          @by_tab.delete tab if @by_tab[tab].empty?
          @by_document[view.document].delete view
          @by_document.delete view.document if @by_document[view.document].empty?
          @tabs.delete view
          view
        end
        
=begin rdoc
Moves a view to the beginning of the order

This method should be called whenever a view is activated, so that activation
order is preserved

@param [EditorView] view the view to move at the beginning of the list. It must
  have already been added to the list
@return [EditorView] _view_
=end
        def move_to_front view
          @by_activation.unshift @by_activation.delete(view)
          tab = @tabs[view]
          @by_tab[tab].unshift @by_tab[tab].delete(view)
          doc = view.document
          @by_document[doc].unshift @by_document[doc].delete(view)
          view
        end
        
      end
      
      include Activable
      
      include Extension
      
=begin rdoc
The default hints used by methods like {#editor_for}
=end
    DEFAULT_HINTS = {
      :exisiting => :always, 
      :strategy => [:current, :current_tab, :first],
      :new => :new_tab,
      :split => :horizontal,
      :show => true,
      :create_if_needed => true
    }.freeze
    
=begin rdoc
Signal emitted whenever the active editor changes

@param [EditorView,nil] view the new active editor or *nil* if there's no
  active editor
=end
    signals 'active_editor_changed(QWidget*)'
    
=begin rdoc
Signal emitted whenever the environment is deactivated
=end
    signals :deactivated
    
=begin rdoc
Signal emitted whenever the environment is activated
=end
    signals :activated
    
=begin rdoc
Signal emitted just before the environment is closed

Note that, if the environment is associated with a project, it'll be closed
when the project itself is closed.

@param [Environment] env *self*
=end
    signals 'closing(QObject*)'
      
=begin rdoc
@return [Project,nil] the project associated with the environment or *nil* if the
  environment is not associated with a project
=end
      attr_reader :project
      
=begin rdoc
@return [KDE::TabWidget] the tab widget containing the views contained in the
  environment
=end
      attr_reader :tab_widget
      
=begin rdoc
@return [EditorView,nil] the active editor or *nil* if no active editor exists
=end
      attr_reader :active_editor
      
=begin rdoc
@param [Project,nil] prj the project the environment is associated with or *nil*
  if the new environment shouldn't be associated with a project
@param [Qt::Object,nil] parent the parent object
=end
      def initialize prj, parent = nil
        super parent
        @project = prj
        @tab_widget = KDE::TabWidget.new{self.document_mode = true}
        @tab_widget.tabs_closable = true if Ruber[:config][:workspace, :close_buttons]
        connect @tab_widget, SIGNAL('currentChanged(int)'), self, SLOT('current_tab_changed(int)')
        connect @tab_widget, SIGNAL('tabCloseRequested(int)'), self, SLOT('close_tab(int)')
        @views = ViewList.new
        @hint_solver = HintSolver.new @tab_widget, nil, @views.by_activation
        @documents = MutableDocumentList.new
        @active_editor = nil
        @active = false
        @focus_on_editors = true
        unless prj
          @default_document = Ruber[:world].new_document 
          @default_document.object_name = 'default_document'
          @default_document.connect(SIGNAL('closing(QObject*)')){@default_document = nil}
          editor_for! @default_document
        end
      end
      
=begin rdoc
Retrieves an editor for a given document or file

@overload editor_for doc, hints = DEFAULT_HINTS
  Retrieves an editor for the given document, creating it if needed.
  
  This is the preferred method to create an editor. Unless you have very special
  needs, you shouldn't need to directly call {Document#create_view}.
  
  If there is more than one editor in the environment for the given document,
  one will be chosen according to the option specified in the _hints_ parameter.
  
  If an editor needs to be created, where it'll be placed is decided according
  to the options specified in _hints_.
  
  @param [Document] doc the document to retrieve an editor for
  @param [Hash] hints see below
  @return [EditorView,nil] an editor for the document. If a view for the document
    doesn't exist in the environment (or the ones existing don't satisfy the
    constraints specified in _hints_), another one will be created according
    to _hints_ , unless the @:create_if_needed@ entry of _hints_ is *false* or
    *nil*, in which case *nil* is returned.
@overload editor_for file, hints = DEFAULT_HINTS
  Retrieves an editor for the given file, creating it if needed. If a document
  associated with the given file doesn't exist, one will be created
  
  @param file [String,KDE::Url] the file associated with the document (as for 
    {World#document}). If a document associated with that file doesn't exist,
    it'll be created
  @param [Hash] hints see below
@return [EditorView,nil] an editor associated with the given document or *nil*
  if no editor was found and _hints_ had the @:create_if_needed@ entry set to
  a false value
@param [Hash] hints the hints to decide which editor should be returned or
  how a new view should be created. Note that any values not explicitly set will
  retain their default value (the one found in {DEFAULT_HINTS})
@option hints [Symbol] :existing (:always) when to use an existing editor. It can have
  the following values:
  
  - @:always@ := always use an existing editor for the document, if it exists
    in the environment
    
  - @:current_tab@ := use an existing editor for the document only if it is
    in the current tab; otherwise create a new editor
    
@option hints [<Symbol>] :strategy ([:current, :current_tab, :first]) controls the behaviour if more than one editor
  matches the requirements. Each element in the array correspond to a strategy.
  All of them will be tried, first to last, until one of them is successful.
  The possible values are:
  
  - @:current@ := if the current editor is associated with the document, choose
    it
  - @:last_used@ := choose the most recently activated among the editors associated
    with the document
  - @:current_tab@ := if the current tab contains an editor associated with the
    document, choose it
  - @:next@ := if the tab after the current one contains an editor associated with the
    document, choose it
  - @:previous@ := if the tab before the current contains an editor associated with the
    document, choose it
  - @:first@ := choose the first among the editors for the document (the one
    in the leftmost tab)
  - @:last@ := choose the last among the editors for the document (the one
    in the rightmost tab)
    
  Note that in all cases except the first two, if there is more than one editor
  in the same tab, the last activated one will be used
@option hints [Symbol,Integer,EditorView] :new controls where a new editor (if one is needed) should
  be placed. It can have one of the following values:
  
  - @:new_tab@ := place the new editor in a new, empty tab
  - @:current@ := split the current view and place the new editor in one of the
    halves. If there are no tabs, create a new one and put the editor there
  - @:current_tab@ := split the first editor in the current tab and place the
    new editor in one of the halves. If there are no tabs, create a new one
    and put the editor there
  - an integer := split the the first editor in the pane corresponding to the
    given integer and place the new editor in one of the halves. If index doesn't
    correspond to a tab, create a new one and put the editor there
  - an {EditorView} := split the given editor and put the new editor in one
    of the halves. Creates a new tab if the editor isn't part of a pane
@option hints [Boolean] :create_if_needed (true) if *true* and an editor for
  the given document doesn't exist, create one. If *false*, returns *nil* if
  no suitable editor is found
@option hints [Symbol] :split (:horizontal) the direction to split a view along.
  It can be either @:horizontal@ or @:vertical@
=end
      def editor_for doc, hints = DEFAULT_HINTS
        doc = Ruber[:world].document doc unless doc.is_a? Document
        hints = DEFAULT_HINTS.merge hints
        editor = @hint_solver.find_editor doc, hints
        unless editor
          return nil unless hints[:create_if_needed]
          view_to_split = @hint_solver.place_editor hints
          editor = doc.create_view self
          if view_to_split
            orientation = hints[:split] == :vertical ? Qt::Vertical : Qt::Horizontal
            view_to_split.parent.split view_to_split, editor, orientation
          else 
            new_pane = create_tab(editor)
            add_editor editor, new_pane
            @tab_widget.add_tab new_pane, doc.icon, doc.document_name
            connect @tab_widget, SIGNAL('mouseMiddleClick(QWidget*)'), self, SLOT('tab_middle_clicked(QWidget*)')
            new_pane.label = label_for_document doc
          end
        end
        editor
      end
      alias_method :editor_for!, :editor_for
      
=begin rdoc
Retrieves a document and projects it on the environment
@param file (see World#document)
@return [ProjectedDocument] a document projected on *self*
=end
      def document file
        doc = Ruber[:world].document file
        doc.project_on self if doc
      end
      
=begin rdoc
A list of the document contained in the environment

A document is contained in the environment if the environment contains at least
one view associated with the document
@return [DocumentList] a list of documents associated with the environment
=end
      def documents
        DocumentList.new @documents
      end
      
=begin rdoc
@return [<Pane>] a list of all tabs in the environment
=end
      def tabs
        @tab_widget.to_a
      end
            
=begin rdoc
A list of the views in the environment

@return [<EditorView>] a list of views in the environment

@overload views
  @return [<EditorView>] a list of all the views in the environment, in activation
    order
@overload views doc
  Returns all the views in the environment associated with a document
  @param [Document] doc the document
  @return [<EditorView>] a list of all the views in the environment associated
    with _doc_
=end
      def views doc = nil
        doc ? @views.by_document[doc].dup : @views.by_activation.dup
      end
      
=begin rdoc
A tab in the environment

@return [Pane,nil] the pane corresponding to the argument
@overload tab idx
  The tab at a given index
  @param [Integer] idx]
  @return [Pane,nil] the tab at position _idx_ or *nil* if _idx_ is out of range
@overload tab pane
  The tab which contains the given pane
  @param [Pane] pane
  @return [Pane,nil] the tab containing _pane_ or *nil* if _pane_ is not part
    of the environment
=end
      def tab arg
        if arg.is_a?(Pane)
          pane = arg
          while parent = pane.parent_pane
            pane = parent
          end
          @tab_widget.index_of(pane) > -1 ? pane : nil
        else @views.tabs[arg]
        end
      end
      
=begin rdoc
Activates an editor

Activating an editor means merging it's GUI with the main window's, activating
the document associated with the view, changing the text and icon of the tab
containing the view and giving focus to the view (only if the previously active
view had focus)

@param [EditorView] view the view to activate
@return [EditorView] _view_
=end
      def activate_editor view
        return view if @active_editor == view
        deactivate_editor @active_editor
        if view
          if active?
            Ruber[:main_window].gui_factory.add_client view.send(:internal)
            @active_editor = view
          end
          @views.move_to_front view
          view_tab = tab(view)
          idx = @tab_widget.index_of view_tab
          @tab_widget.set_tab_text idx, view.document.document_name
          @tab_widget.set_tab_icon idx, view.document.icon
          @tab_widget.current_index = idx
        end
        if active?
          view.document.activate if view
          emit active_editor_changed(view) 
        end
        view.set_focus if view and focus_on_editors?
        view
      end
      slots 'activate_editor(QWidget*)'
      
=begin rdoc
The active document

@return [Document,nil] the active document, that is the document associated with
  the active editor or *nil* if there's not an active editor
=end
      def active_document
        @active_editor ? @active_editor.document : nil
      end
      
=begin rdoc
Closes the given editor view

If the editor is the last one associated with a document, the document is closed,
too (in this case, the user may be asked what to do with unsaved changes, according
to the _ask_ parameter). If there are other editors associated with the same
document, only the editor is closed.

Usually, calling this method is the correct way to close an editor, because it
makes sure that the associated document is closed if no other views are associated
with it. You should directly call {EditorView#close} only if you want the document
to remain open.

@param [EditorView] editor the editor to close
@param [Boolean] ask it's passed as argument to {Document#close} in case the
  document associated with the editor needs to be closed.
@return [Boolean] *true* if there were other editors associated with the view
  or if the document associated with the view was closed and *false* if {Document#close}
  returned *false*
=end
      def close_editor editor, ask = true
        doc = editor.document
        if doc.views.count > 1 
          editor.close
          true
        else doc.close ask
        end
      end
      
=begin rdoc
Closes the environment

If the environment is associated with a project, this simply calls {AbstractProject#save Project#save},
otherwise, it closes all the documents and views and schedules itself for
disposing.

If _ask_ is *true*, the user will be asked about unsaved documents, and has the
possibility of aborting closing the environment
@param [Boolean] save whether or not documents should be saved before closing them
@return [Boolean] *true* if the environment was closed and *false* otherwise
=end
      def close save = true
        if @project then @project.close save
        else 
          docs_to_close = @views.by_document.to_a.select{|d, v| (d.views - v).empty?}
          docs_to_close.map!{|d| d[0]}
          if save
            return false unless Ruber[:main_window].save_documents docs_to_close
          end
          emit closing(self)
          self.active = false
          docs_to_close.each{|d| d.close false}
          @views.by_activation.dup.each{|v| v.close}
          delete_later
          true
        end
      end
      slots :close
      
=begin rdoc
Displays the given document in an editor, activates it and moves the cursor to
a given position

This method works as a combination of {#editor_for}, {#activate_editor} and
{EditorView#go_to}.

If {#editor_for} is unable to find or create an editor for the given document,
nothing is done.
@param [Document,String,KDE::Url] doc the document to display. Has the same
  meaning as in {#editor_for}
@param hints (see #editor_for)
@option hints (see #editor_for)
@option hints [Integer,nil] line (nil) if non-*nil*, move the cursor to the given
  line. If *nil*, the cursor will be left where it is
@option hints [Integer,nil] column (nil) if the @:line@ hint has been specified,
  moves the cursor to the given column (or to the beginning of the line if *nil*).
  If the @:line@ hint has not been given, this hint has no effect
@return [EditorView,nil] the editor the document is being displayed in or *nil*
  if no such editor was found and it was impossible to create a new one
=end
      def display_document doc, hints = {}
        ed = editor_for! doc, hints
        return unless ed
        activate_editor ed
        line = hints[:line]
        ed.go_to line, hints[:column] || 0 if hints[:line]
        ed
      end

=begin rdoc
Close the given editors

It is almost the same as calling {#close_editor} for each editor given as argument
but asks the user about unsaved documents using a single dialog (calling {MainWindow#save_documents}), rather than displaying a dialog for each document.

If the user chooses to abort closing, neither editors nor documents are closed
@param [<EditorView>] editors the editors to close
@param [Boolean] ask whether the user should be asked about unsaved documents
@return [Boolean] *true* if the editors were closed and *false* if the user
  aborted the operation
=end
      def close_editors editors, ask = true
        editors_by_doc = editors.group_by &:document
        docs = editors_by_doc.keys
        to_close = docs.select{|doc| (doc.views - editors_by_doc[doc]).empty?}
        if ask
          return false unless Ruber[:main_window].save_documents to_close 
        end
        to_close.each do |doc| 
          doc.close false
          editors_by_doc.delete doc
        end
        editors_by_doc.each_value do |a|
          a.each &:close
        end
        true
      end
      
=begin rdoc
Takes an editor from the pane structure and replaces it with another one at the
same position

If the view to replace 

@param [EditorView] old the editor to replace
@param [EditorView,Document,String,KDE::Url] new the editor to replace _old_
  with or the document associated with the editor or the file name or url of
  the file associated with the document (as in {World#document}).
@param [Boolean] ask whether to ask the user about unsaved documents (only if
  _old_ is the last view associated with its document)
  If _new_ is not an editor, a new editor will always be created
@return [EditorView,nil] the editor which has replaced _old_ or *nil* if _ask_
  was true and the user chooses to abort
=end
      def replace_editor old, new, ask = true
        if new.is_a? Document
          new = new.create_view
        elsif new.is_a? String or new.is_a? KDE::Url
          new = Ruber[:world].document(new).create_view
        end
        if old.document.views.count == 1
          if ask
            return unless old.document.query_close
          end
          close_doc = true
        end
        old.parent.replace_view old, new
        close_editor old, false
        new
      end
      
=begin rdoc
@return [Boolean] whether the last time the environment was active an editor
  had focus
=end
      def focus_on_editors?
        @views.tabs.empty? || @focus_on_editors
      end
  
=begin rdoc
Override of {Extension#query_close}

This method can be called either because the user closed the project associated
with it or because Ruber is closing. In the first case, it saves all the documents
whose views are all in the environment. In the second case, it does nothing
(the documents will be saved by the world component)
@return [Boolean] if the project is being closed, *true* if the documents were
  saved successfully and *false* otherwise. If Ruber is being closed, always
  *true*
=end
      def query_close
        if Ruber[:app].status != :asking_to_quit
          docs = @views.by_document.select{|d, v| (d.views - v).empty?}
          Ruber[:main_window].save_documents docs.map{|a| a[0]}
        else true
        end
      end
      
=begin rdoc
Override of {Extension#remove_from_project}

If closes itself, all the editors inside it and all the documents which remain
without views.
@return [nil]
@note Unsaved documents are *not* saved
@raise [RuntimeError] if the document is not associated with a project
=end
      def remove_from_project
        raise "environment not associated with a project" unless @project
        emit closing(self)
        self.active = false
        docs_to_close = @views.by_document.select{|d, v| (d.views - v).empty?}
        docs_to_close.each{|d| d[0].close false}
        @views.dup.by_activation.each{|v| v.close}
        nil
      end
      
      private
      
=begin rdoc
Closes the default document when opening a new one, if appropriate

The default document is *not* closed if:
* there is no default document (which is always the case for environments associated
    with projects)
* the default document is not pristine
* the default document has more than one editor associated with it
@return [nil]
=end
      def maybe_close_default_document doc
        return unless @default_document
        return if @default_document == doc
        return unless @default_document.pristine?
        return if @default_document.views.count != 1
        @default_document.close
        nil
      end
      
=begin rdoc
Adds an editor to the environment

@param [EditorView] editor the editor to add
@param [Pane] pane the pane the editor is in
@return [nil]
=end
      def add_editor editor, pane
        maybe_close_default_document editor.document
        @views.add_view editor, pane
        doc = editor.document
        editor.parent.label = label_for_document doc
        unless @documents.include? doc
          @documents.add doc
          connect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT('document_url_changed(QObject*)')
        end
        connect editor, SIGNAL('focus_in(QWidget*)'), self, SLOT('editor_got_focus(QWidget*)')
        connect doc, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('document_modified_status_changed(bool, QObject*)')
        connect editor, SIGNAL('focus_out(QWidget*)'), self, SLOT('editor_lost_focus(QWidget*)')
        update_pane pane
      end
      
=begin rdoc
Removes an editor from the environment
@param [Pane] _ unused
@param [EditorView] editor the editor to remove
@return [nil]
=end
      def remove_editor _, editor
        editor_tab = @views.tabs[editor]
        if @active_editor == editor
          to_activate = @views.by_tab[editor_tab][1]
          activate_editor to_activate
          deactivate_editor editor
        end
        disconnect editor, SIGNAL('focus_in(QWidget*)'), self, SLOT('editor_got_focus(QWidget*)')
        disconnect editor, SIGNAL('focus_out(QWidget*)'), self, SLOT('editor_lost_focus(QWidget*)')
        @views.remove_view editor
        unless @views.by_tab[editor_tab]
          @tab_widget.remove_tab @tab_widget.index_of(editor_tab) 
        end
        doc = editor.document
        unless @views.by_document[doc]
          @documents.remove doc 
          disconnect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT('document_url_changed(QObject*)')
          disconnect doc, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('document_modified_status_changed(bool, QObject*)')
        end
        nil
      end
      slots 'remove_editor(QWidget*, QWidget*)'
      
=begin rdoc
Closes the tab at the given index

@param [Integer] idx the index of the tab to close
@return [nil]
=end
      def close_tab idx
        views = @tab_widget.widget(idx).views
        close_editors views
        nil
      end
      slots 'close_tab(int)'
      
=begin rdoc
Slot called whenever an editor gets focus

It activates the editor and remembers than an editor has focus

@param [EditorView] editor the editor which received focus
@return [nil]
=end
      def editor_got_focus editor
        @focus_on_editors = true
        activate_editor editor
      end
      slots 'editor_got_focus(QWidget*)'
      
=begin rdoc
Slot called whenever an editor lost focus

If the editor has lost focus for any reason except because it was closed or
because Ruber itself looses focus, it remembers that editors don't have focus

@param [EditorView] editor the editor which lost focus
@return [nil]
=end
      def editor_lost_focus editor
        #When an editor is closed, the editor's parent pane is made parentless before the removing_editor
        #signal is emitted by the pane, which means the editor is hidden (and thus
        #looses focus) before it is actually closed. We don't want @focus_on_editors
        #to be changed in that case (otherwise closing an editor which had focus
        #would cause focus not to be given to the next active editor). The only
        #check I can think of is whether the editor's parent pane has a parent
        #or not
        if editor.is_active_window and editor.parent.parent
          @focus_on_editors = false 
        end
        nil
      end
      slots 'editor_lost_focus(QWidget*)'
      
=begin rdoc
Override of {Activable#do_deactivation}
@return [nil]
=end
      def do_deactivation
        #hiding the tab widget would make the editors all loose focus, but we
        #want that setting to be kept until the environment becomes active again,
        #so we store the original value in a temp variable and restore it afterwards
        old_focus_on_editors = @focus_on_editors
#         @tab_widget.hide
        deactivate_editor @active_editor
        @focus_on_editors = old_focus_on_editors
        super
        nil
      end

=begin rdoc
Override of {Activable#do_activation}

It activates the last activated editor in the environment
@return [nil]
=end
      def do_activation
        activate_editor @views.by_activation[0]
        super
        nil
      end

=begin rdoc
Deactivates the given editor view

If the given editor view is not active, nothing is done
@param [EditorView] view the view to activate
@return [nil]
=end
      def deactivate_editor view
        if view and @active_editor == view
          view.document.deactivate
          Ruber[:main_window].gui_factory.remove_client view.send(:internal)
          @active_editor = nil
        end
        nil
      end
      
=begin rdoc
@return [String] a label suitable for the given document
@param [Document] doc the document to retrieve the label for
=end
      def label_for_document doc
        url = doc.url
        label = if url.local_file? then doc.path
        elsif url.valid? then url.pretty_url
        else doc.document_name
        end
        label << ' [modified]' if doc.modified?
        label
      end
      
=begin rdoc
Creates a tab containing the given view

Note that the tab has not yet been inserted in the tab widget
@param [EditorView] view the view to insert in the new pane
@return [Pane] a pane corresponding to the new tab.
=end
      def create_tab view
        pane = Pane.new view
        pane.label = label_for_document view.document
        connect pane, SIGNAL('removing_view(QWidget*, QWidget*)'), self, SLOT('remove_editor(QWidget*, QWidget*)')
        connect pane, SIGNAL('pane_split(QWidget*, QWidget*, QWidget*)'), self, SLOT('pane_split(QWidget*, QWidget*, QWidget*)')
        connect pane, SIGNAL('view_replaced(QWidget*, QWidget*, QWidget*)'), self, SLOT('view_replaced(QWidget*, QWidget*, QWidget*)')
        pane
      end
      
=begin rdoc
Slot called whenever a pane is split

It adds the new editor to the list of editors in the environment

@param [Pane] pane the pane (not necessarily toplevel) which was split
@param [EditorView] old the view which was split
@param [EditorView] new the new view
@return [nil]
=end
      def pane_split pane, old, new
        add_editor new, tab(pane)
        nil
      end
      slots 'pane_split(QWidget*, QWidget*, QWidget*)'

=begin rdoc
Slot called whenever a view is replaced by another in a pane

It adds the new editor to the list of editors in the environment and removes
the old one

@param [Pane] pane the pane (not necessarily toplevel) where the replacement
  happened
@param [EditorView] old the view which was replaced
@param [EditorView] new the view which replaced _old_
@return [nil]
=end

      def view_replaced pane, old, new
        toplevel_pane = tab(pane)
        add_editor new, toplevel_pane
        remove_editor toplevel_pane, old
        update_pane toplevel_pane
        nil
      end
      slots 'view_replaced(QWidget*, QWidget*, QWidget*)'
      
=begin rdoc
Changes the tool tip of a tab so that it contains all the documents inside it

@param [Pane] pane the pane whose tool tip to update
@return [nil]
=end
      def update_pane pane
        docs = @views.by_tab[pane].map(&:document).uniq
        tool_tip = docs.map(&:document_name).join "\n"
        @tab_widget.set_tab_tool_tip @tab_widget.index_of(pane), tool_tip
        nil
      end
      slots 'update_pane(QWidget*)'
      
=begin rdoc
Slot called whenever the current tab changes

It activates the last activated editor in that pane
@param [Integer] idx the index of the active pane
@return [EditorView] the active editor
=end
      def current_tab_changed idx
        current_tab = @tab_widget.widget idx
        view = idx >= 0 ? @views.by_tab[current_tab][0] : nil
        activate_editor view
        view
      end
      slots 'current_tab_changed(int)'
      
=begin rdoc
Removes a tab from the tab widget
@param [Pane] the toplevel pane to remove
@return [nil]
=end
      def remove_tab pane
        @tab_widget.remove_tab @tab_widget.index_of(pane)
        nil
      end
      slots 'remove_tab(QWidget*)'
      
=begin rdoc
Slot called whenever the url of a document having a view in the environment
  changes
It updates the label of each view associated with the document and the caption
of each tab containing a view associated with the document if it is the last
activated view in that pane
@param [Document] doc the document
@return [nil]
=end
      def document_url_changed doc
        @tab_widget.each{|t| update_pane t}
        label = label_for_document doc
        @views.by_document[doc].each{|v| v.parent.label = label}
        @tab_widget.each_with_index do |w, i|
          if @views.by_tab[w][0].document == doc 
            @tab_widget.set_tab_text i, doc.document_name 
            @tab_widget.set_tab_icon i, doc.icon
          end
        end
        nil
      end
      slots 'document_url_changed(QObject*)'

=begin rdoc
Slot called whenever the modified status of a document having views in the environment
changes

It updates the label of each view associated with the document and the caption
of each tab containing a view associated with the document if it is the last
activated view in that pane
@param [Document] doc the document
@return [nil]
=end
      def document_modified_status_changed mod, doc
        label = label_for_document doc
        @views.by_document[doc].each{|v| v.parent.label = label}
        @tab_widget.each_with_index do |w, i|
          if @views.by_tab[w][0].document == doc 
            @tab_widget.set_tab_icon i, doc.icon
          end
        end
        nil
      end
      slots 'document_modified_status_changed(bool, QObject*)'
      
=begin rdoc
Slot called whenever the middle mouse button is clicked on a tab

It closes the tab if the @workspace/middle_button_close@ setting is *true*
@param [Pane] w the tab where the mouse was clicked
@return [nil]
=end
      def tab_middle_clicked w
        idx = @tab_widget.index_of w
        close_tab idx if idx >= 0 and Ruber[:config][:workspace, :middle_button_close]
        nil
      end
      slots 'tab_middle_clicked(QWidget*)'
      
    end
    
  end
  
end