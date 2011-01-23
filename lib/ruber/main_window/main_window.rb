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

# Special comments used here to mark things to do:
# OBSOLETE: method to remove (or likely so)
# MOVE: method which should be moved somewhere else (to another class)

require 'forwardable'

require 'ruber/plugin_like'
require 'ruber/gui_states_handler'

require 'ruber/main_window/main_window_internal'
require 'ruber/main_window/main_window_actions'
require 'ruber/main_window/hint_solver'
require 'ruber/main_window/view_manager'

require 'ruber/main_window/status_bar'
require 'ruber/main_window/workspace'
require_relative 'ui/workspace_settings_widget'

module Ruber

=begin rdoc
The application's main window. It is made of a menu bar, a tool bar, a workspace
and a status bar. The workspace (see Workspace) is the main window's central widget
and where most of the user interaction happens. It contains the editors and the
tool widgets.
=end
  class MainWindow < KParts::MainWindow
    
    include PluginLike
    
    include GuiStatesHandler
    
    extend Forwardable    
    
    signals 'current_document_changed(QObject*)', 'active_editor_changed(QObject*)'
        
    slots :load_settings
    
=begin rdoc
The default hints used by methods like {#editor_for} and {#editor_for!}
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
The widget which contains the tool widgets.

The primary use of this method is to connect to the signals emitted from the workspace
when a tool widget is raised, shown or hidden. All of its other methods are also
provided by the MainWindow, so you shouldn't need to access the workspace to use
them.

@return [Workspace] the workspace associated with the main window
=end
    attr_reader :workspace
    
=begin rdoc
A hash with the data stored in the session manager by plugins. The hash is only
availlable after the <tt>restore</tt> method has been called (which means that it
will always be unavaillable if ruber wasn't started by the session manager). If
the hash isn't availlable, *nil* is returned

<b>NOTE:</b> only for use by Application when restoring the session
=end
    attr_reader :last_session_data
        
=begin rdoc
Creates a new MainWindow. <i>_manager</i> is the component manager, while _pdf_
is the plugin description for this object.
=end
    def initialize _manager, pdf
      super nil, 0
      initialize_plugin pdf
      initialize_states_handler
      self.central_widget = Workspace.new self
      # We need the instance variable to use it with Forwardable
      @workspace = central_widget 
      @tabs = central_widget.instance_variable_get :@views
      @tabs.tabs_closable = Ruber[:config][:workspace, :close_buttons]
      @view_manager = ViewManager.new @tabs, self
      @auto_activate_editors = true
      @ui_states = {}
      @actions_state_handlers = Hash.new{|h, k| h[k] = []}
      @about_plugin_actions = []
      @switch_to_actions = []
      @last_session_data = nil
      self.status_bar = StatusBar.new self
      self.connect(SIGNAL('current_document_changed(QObject*)')) do |doc|
        change_state 'current_document', !doc.nil?
      end
      connect Ruber[:components], SIGNAL('component_loaded(QObject*)'), self, SLOT('add_about_plugin_action(QObject*)')
      connect Ruber[:components], SIGNAL('unloading_component(QObject*)'), self, SLOT('remove_about_plugin_action(QObject*)')
      connect Ruber[:components], SIGNAL('unloading_component(QObject*)'), self, SLOT('remove_plugin_ui_actions(QObject*)')
      connect @view_manager, SIGNAL('active_editor_changed(QWidget*)'), self, SLOT('slot_active_editor_changed(QWidget*)')
      connect Ruber[:documents], SIGNAL('document_created(QObject*)'), self, SLOT('document_created(QObject*)')
      connect Ruber[:documents], SIGNAL('closing_document(QObject*)'), self, SLOT(:update_switch_to_list)

      setup_actions action_collection
      Ruber[:projects].connect( SIGNAL('current_project_changed(QObject*)') ) do |prj|
        change_state "active_project_exists", !prj.nil?
        change_title
      end
      connect @tabs, SIGNAL('tabCloseRequested(int)'), self, SLOT('close_tab(int)')
      connect Ruber[:projects], SIGNAL('closing_project(QObject*)'), self, SLOT('close_project_files(QObject*)')
      setup_GUI
      create_shell_GUI true
      
      config_obj = Ruber[:config].kconfig
      apply_main_window_settings KDE::ConfigGroup.new( config_obj, 'MainWindow')
      recent_files = KDE::ConfigGroup.new config_obj, 'Recent files'
      open_recent_action =action_collection.action("file_open_recent")
      open_recent_action.load_entries recent_files
      switch_to_recent_action = action_collection.action("window-switch_to_recent_file")
      switch_to_recent_action.load_entries recent_files
      
      # Synchronize the two menus, so that when the user clears one of them the also
      # is also cleared
      connect open_recent_action, SIGNAL(:recentListCleared), switch_to_recent_action, SLOT(:clear)
      connect switch_to_recent_action, SIGNAL(:recentListCleared), open_recent_action, SLOT(:clear)
      
      recent_projects = KDE::ConfigGroup.new config_obj, 'Recent projects'
      action_collection.action("project-open_recent").load_entries recent_projects
      status_bar.show
      setup_initial_states
    end
    
=begin rdoc
The open tabs

@return [Array<Pane>] a list of the top-level pane for each tab
=end
    def tabs
      @tabs.to_a
    end
    
=begin rdoc
The views contained in the main window

If a document is given as argument, returns all views associated with the document;
if no document is given, all views are returned.

The order of the views in the returned list is the activation order: the view
which was activated more recently is at position 0 in the array, the one activated
before that is at position 1 and so on. Views which have never been activated are
at the end of the array, in an arbitrary order

@param [Document,nil] doc the document to return the views for. If *nil*, all the
  views will be returned
@return [Array<EditorView>] the views associated with the given document, if any,
  or all the views, in activation order, from most recently activated to less recently
  activated
=end
    def views doc = nil
      if doc then @view_manager.activation_order.select{|v| v.document == doc}
      else @view_manager.activation_order.dup
      end
    end
    
    ##
    # :method: add_tool
    # Adds a tool widget to the main window. See Workspace#add_tool_widget for more information.
    def_delegator :@workspace, :add_tool_widget, :add_tool
    
    ##
    # :method: remove_tool
    # Removes a tool widget from the main window. See Workspace#remove_tool_widget for more information.
    def_delegator :@workspace, :remove_tool_widget, :remove_tool
    
    ##
    # :method: toggle_tool
    # Activates a tool widget if it was hidden and hides it if it was active.
    # See Workspace#toggle_tool for more information.
    def_delegators :@workspace, :toggle_tool
    
    ##
    # :method: raise_tool
    # Activates a tool widget. See Workspace#raise_tool for more information.
    def_delegators :@workspace, :raise_tool
    
    ##
    # :method: show_tool
    # Displays a tool widget. See Workspace#show_tool for more information.
    def_delegators :@workspace, :show_tool
    
    ##
    # :method: activate_tool
    # Shows and gives focus to a tool. See Workspace#activate_tool for more information.
    def_delegators :@workspace, :activate_tool
    
    ##
    # :method: hide_tool
    # Hides a tool widget. See Workspace#hide_tool for more information.
    def_delegators :@workspace, :hide_tool
    
    ##
    # :method: tool_widgets
    # Returns a hash having the tool widgets as keys and their positions as values.
    # See Workspace#tool_widgets for more information.
    def_delegators :@workspace, :tool_widgets
    
=begin rdoc
Returns an editor associated with the given document, creating it if needed

If _doc_ is not a document and no document for the file representing by the string
or URL _doc_ is open, it will be created.

Since there can be more than one editor associated with the document, the optional
_hints_ argument can be used to specify which one should be returned. If no editor
exists for the document, or none of the exisiting ones statisfy the @existing@
hint, a new one will be created, unless the @create_if_needed@ hint is *false*.

@param [Document, String, KDE::Url] doc the document. If it is a string representing
  a relative path, it'll be considered relative to the current directory. If the
  string is an Url, it'll be interpreted as such
@param [Hash] hints options to tailor the algorithm used to retrieve or create the editor

@option hints [Symbol] :existing (:always) when it is acceptable to return an already existing
  editor. It can be:
  * @:always@: if there's an existing editor, always use it
  * @:never@: never use an exisiting editor
  * @:current_tab@: use an exisiting editor only if it is in the current pane
@option hints [Boolean] :create_if_needed (true) whether or not a new editor for
  the given document should be created if none exists. This is different from
  passing @:always@ as the value of the @:existing@ option because the latter would
  cause a new editor to be created in case no one already exists for the document
@option hints [Symbol, Array<Symbol>] :strategy ([:current, :current_tab, :first])
  how to choose the exisiting editor to use in case there's more than one. If it
  is an array, the strategies will be applied in turn until one has success.
  If none of the given strategies succeed, @:first@ will be used. The possible
  values are
  * @:current@: if the current editor is associated with _doc_, use it
  * @:current_tab@: if there are editors associated with _doc_ in the current
  tab, the first of them will be used
  * @:last_current_tab@: if there are editors associated with _doc_ in the current
  tab, the first of them will be used
  * @:next@: starting from the current tab, the first editor found associated
  with _doc_ will be used
  * @:previous@: the first editor associated with _doc_ found by looking in all
  tabs from the current one in reverse order will be used (the current tab will
  be the last one where the editor will be looked for)
  * @:first@: the first editor associated with the document will be used
  * @:last@: the last editor associated the document will be used
  
  This option is only useful when using an existing editor
@option hints [Symbol,Integer,EditorView] :new (:new_tab) where to place the new editor, if
  it needs to be created. It can have one of the following values:
  * @:new_tab@: put the new editor as the single editor in a new tab
  * @:current@: place the new editor in the pane obtained splitting the 
  current editor
  * @:current_tab@: place the new editor in the pane obtained splitting the first
  editor in the current tab
  * @:replace@: replace the current editor, if any, with the new one. If no active
    editor exists, it's the same as @:new_tab@. This value (if there's an active
    editor), implies that the @:existing@ option is set to @:never@
  * an integer: place the new editor in the tab associated with that index (0-based),
  in the pane obtained by splitting the first view
  * an {EditorView}: place the new editor in the pane obtained splitting the
  pane associated with the given editor

  This option is only used when when creating a new editor
@option hints [Symbol] :split (:horizontal) the orientation in which an existing
  editor should be split to accomodate the new editor. It can be @:horizontal@
  or @:vertical@. This option is only used when when creating a new editor
@option hints [Boolean] :show (true) whether the new editor should be shown or
  not. If it's *false*, the editor won't be placed in any pane. This option is
  only used when when creating a new editor
@return [EditorView,nil] an editor associated with the document and *nil* if no
  editor associated with the given document exists and the @:create_if_needed@ hint is
  set to *false*.
@raise [ArgumentError] if _doc_ is a path or a @KDE::Url@ but the corresponding
  file doesn't exist
=end
    def editor_for! doc, hints = DEFAULT_HINTS
      hints = DEFAULT_HINTS.merge hints
      if hints[:new] == :replace
        if active_editor
          hints[:existing] = :never
          hints[:show] = false
        else hints[:new] = :new_tab
        end
      end
      docs = Ruber[:documents].documents
      unless doc.is_a? Document
        unless hints.has_key? :close_starting_document
          hints[:close_starting_document] = docs.size == 1 && 
              docs[0].extension(:ruber_default_document).default_document && 
              docs[0].pristine?
        end
        url = doc
        if url.is_a? String
          url = KDE::Url.new url
          if url.relative?
            path = File.expand_path url.path
            url.path = path
          end
        end
        doc = Ruber[:documents].document url
      end
      return unless doc
      ed = @view_manager.without_activating{@view_manager.editor_for doc, hints}
      if hints[:new] == :replace
        replace_editor active_editor, ed
      else ed
      end
    end
    
=begin rdoc
Returns an editor associated with the given document

It works mostly like {#editor_for!}, but it doesn't attempt to create the document
if it doesn't exist an always sets the @create_if_needed@ hint to *false*. See
{#editor_for!} for the values it can contain.

@param (see #editor_for!)
@return [EditorView,nil] an editor associated with the document and *nil* if no
editor associated with the given document exists or no document corresponds to _doc_
@raise [ArgumentError] if _doc_ is a path or a @KDE::Url@ but the corresponding
file doesn't exist
=end
    def editor_for doc, hints = DEFAULT_HINTS
      hints = DEFAULT_HINTS.merge hints
      hints[:create_if_needed] = false
      unless doc.is_a? Document
        url = doc
        if url.is_a? String
          url = KDE::Url.new url
          if url.relative?
            path = File.expand_path url.path
            url.path = path
          end
        end
        doc = Ruber[:documents].document_for_url url
      end
      return unless doc
      @view_manager.editor_for doc, hints
    end
    
=begin rdoc
The active editor
    
The active editor is the editor which has its GUI merged with the main window's.
This means it is the editor which last received focus and the one which would receive
focus when the tab widget does. If the focus already is in the tab widget, then
the active editor is the one whose @is_active_window@ method returns *true*.

@return [EditorView,nil] the active editor or *nil* if there's no active editor.
=end
    def active_editor
      @view_manager.active_editor
    end
    alias_method :current_editor, :active_editor

=begin rdoc
Activates an editor

If the editor is not in the current tab, the tab it belongs to becomes active.

Activating an editor means merging its GUI with the main window's GUI, changing
the title of the main window accordingly and telling the status bar to refer to
that view.
    
After activating the editor, the {#current_document_changed} and {#active_editor_changed}
signals are emitted.
@param [EditorView,nil] editor the editor to activate. If *nil*, then the currently active
  editor will be deactivated
=end
  def activate_editor editor
    tab = @view_manager.tab editor
    return unless tab
    @tabs.current_widget = tab
    return if active_editor == editor
    @view_manager.make_editor_active editor
    editor
  end
    
=begin rdoc
Replaces an editor with another

If the editor to be replaced is the only one associated witha given document and
the document is modified, the user is asked whether he wants to save it or not. If
he chooses to abort, the editor is not replaced, otherwise the document is closed.

The new editor is put in the same pane which contained the old one (without splitting
it).

@overload replace_editor old, new_ed
  @param [EditorView] old the editor to replace
  @param [EditorView] new_ed the editor to replace _old_ with
  @return [EditorView,nil]
@overload replace_editor old, doc
  @note whether or not the user needs to be asked about saving the document is determined
    regardless of the value of _doc_. This means that the user may be asked
    to save the document even if _doc_ is the same document associated with
    the view (or the URL corresponding to it). To avoid this, create the replacement
    editor before calling this method, using @editor_for doc, :existing => :never, :show => false@,
    then use the overloaded version of this method which takes an editor
  @param [EditorView] old the editor to replace
  @param [Document,String,KDE::Url] doc the document to create the editor for or
    the name of the corresponding file (absolute or relative to the current directory)
    or the corresponding URL
  @return [EditorView,nil]
@return [EditorView,nil] the new editor or *nil* if the user choose to abort
=end
    def replace_editor old, editor_or_doc
      if old.document.views.size == 1
        return unless old.document.query_close
        close_doc = true
      end
      if editor_or_doc.is_a?(EditorView) then ed = editor_or_doc
      else ed = editor_for! editor_or_doc, :existing => :never, :show => false
      end
      old.parent.replace_view old, ed
      close_editor old, false
      ed
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
      @view_manager.tab arg
    end
    
=begin rdoc
The document associated with the active editor

This is a convenience method for @active_editor.document@ which takes care of the
case when there's no active editor.

@return [Document,nil] the document associated with the active editor or *nil*
  if there's no active editor
=end
    def current_document
      (ed = active_editor) ? ed.document : nil
    end
    alias_method :active_document, :current_document
    
=begin rdoc
Displays an editor for the given document

This method is similar to {#editor_for!} but, after retrieving the editor (creating
it and/or the document as needed), it activates and gives focus to it and moves
the cursor to the given position.

Besides the keys listed in {#editor_for!}, _hints_ can also contain the two entries
@:line@ and @:column@.

@see #editor_for! editor_for! for the possible entries in _hints_
@param (see #editor_for!)
@option hints [Integer,nil] line (nil) the line to move the cursor to. If *nil*,
  the cursor won't be moved
@option hints [Integer] column (0) the column to move the cursor to. Ignored if
  the @:line@ entry is *nil*
@return [EditorView,nil] the editor which has been activated or *nil* if the
  editor couldn't be found (or created)
=end
    def display_doc doc, hints = DEFAULT_HINTS
      ed = editor_for! doc, hints
      return unless ed
      activate_editor ed
      line = hints[:line]
      ed.go_to line, hints[:column] || 0 if line
      ed.set_focus
      ed
    end
    alias_method :display_document, :display_doc
    
=begin rdoc
Executes the given block without automatically activating an editor whenever the
current tab changes

This method should be used, for example, when more than one editor should be opened at
once. Without this, every new editor would become (for a little time) the active
one, with its gui merged with the main window and so on. This slows things down
and should be avoided. To do so, you use this method:

bc. Ruber[:main_window].without_activating do
    ed = nil
    files.each do |f|
      ed = Ruber[:main_window].editor_for! f
    end
    Ruber[:main_window].activate_editor ed
  end

After calling this method, the focus widget of the current tab gets focus

@note automatical editor activation will be restored at the end of this
  method (even if exceptions occur).
@yield the block which should be executed without automatically activating editors
@return [Object] the value returned by the block
=end
    def without_activating &blk
      @view_manager.without_activating &blk
    end
    
=begin rdoc
Closes an editor view

If the editor to be closed is the last editor associated with the document the
document will be closed. If _ask_ is *true* and the document is modified, the user
will be asked whether to save or discard the changes and will have the possibility
of aborting closing the editor (and the document). If _ask_ is false, the document
will be closed without user interaction.

If there are other editors associated with the document besides the one to close,
the latter will be closed without affecting the document.

@param [EditorView] editor the editor to close
@param [Boolean] ask whether or not to ask confirmation from the user if the document
  associated with _editor_ should be closed
@return [Boolean] *true* if the editor is closed and *false* if it isn't.
@note Always use this method to close an editor, rather than calling its {EditorView#close close}
  method directly, unless you want to leave the corresponding document without a view
=end
    def close_editor editor, ask = true
#       editor_tab = self.tab(editor)
#       has_focus = editor_tab.is_active_window if editor_tab
#       if has_focus
#         views = editor_tab.to_a
#         idx = views.index(editor)
#         new_view = views[idx-1] || views[idx+1]
#       end
      doc = editor.document
      if doc.views.size > 1 
        editor.close
        true
      else doc.close ask
      end
#       focus_on_editor new_view if new_view
    end
    
=begin rdoc
Asks the user to save multiple documents

This method is meant to be called in situation where the user may want to save
a number of documents, for example when the application is quitting, as it avoids
displaying a dialog box for each modified document.

It displays a dialog where the user can choose, among the documents passed as
first argument, which ones he wants to save. The user has three choiches:
* save some (or all) the files, then proceed with the operation which has caused
the dialog to be shown (for example, quitting the application)
* don't save any file and go on with the operation
* abort the operation.

In the first case, this method attempts to perform save the selected files. If
any of them can't be saved, the dialog to choose the files to save will be
displayed again, with only those files which couldn't be saved (after informing
the user of the failure). The user can again chose which of those files this method
should attempt to save again, or whether to abort the operation or skip saving.
This will be repeated until all files have been saved or the user gives up

In the second and third cases, the method simply returns respectively *true* or
*false*.

@param [Array<Document>] docs the list of documents to save. If any document isn't
  modified, it'll be ignored. If no document is mdified, nothing will be done
@return [Boolean] *true* if the operation which caused the dialog to be shown
  can be carried on and *false* if the user chose to abort it
=end
    def save_documents docs = nil
      docs ||= Ruber[:docs]
      to_save = docs.select{|d| d.modified?}
      until to_save.empty?
        dlg = SaveModifiedFilesDlg.new to_save, self
        case dlg.exec
        when KDE::Dialog::Yes
          to_save = Ruber[:docs].save_documents dlg.to_save
          unless to_save.empty?
            msg = "The following documents couldn't be saved: #{to_save.join "\n"}\nPlease, choose how to proceed"
            KDE::MessageBox.sorry nil, KDE.i18n(msg)
          end
        when KDE::Dialog::No then to_save.clear
        when Qt::Dialog::Rejected then return false
        end
      end
      true
    end
    
=begin rdoc
Override of {PluginLike#query_close}

It stores the session data retrieved by the component manager in case of session
saving and does nothing otherwise.

@return [TrueClass]
=end
    def query_close
      if Ruber[:app].session_saving
        @session_data = Ruber[:components].session_data
      end
      true
    end
    
=begin rdoc
Opens a project, displaying amessage boxe in case of errors

This method provides a standard interface for creating a project from a project
file named, automatically handling the possible exceptions.
    
In particular, a message box will be displayed if the project file doesn't exist
or if it exists but it's not a valid project file.

If the project corresponding to the given file is already open, the behaviour
depends on the value of _allow_reuse_. If *false*, the user is warned with a message
box that the project is already open and nothing is done. If _allow_reuse_ is
*true*, the existing project is returned.

The new project will be made active and the existing one (if any) will be closed
@param [String] file the absolute path of the project file to open
@param [Boolean] allow_reuse what to do in case the project associated to _file_
  is already open. If *true*, the existing project will be returned; if *false*,
  the user will be warned and *nil* will be returned
@return [Project,nil] the project associated with _file_ or *nil* if an error occurs
  (including the project being already open in case _allow_reuse_ is *false*)
=end
    def safe_open_project file, allow_reuse = false
      prj = Ruber[:projects][file]
      if !allow_reuse and prj
        text = "A project corresponding to the file #{file} is already open. Please, close it before attempting to open it again"
        KDE::MessageBox.sorry self, KDE.i18n(text)
        return nil
      elsif prj then return prj
      end
      message = nil
      begin prj = Ruber[:projects].project file
      rescue Project::InvalidProjectFile => ex
        text = "%s isn't a valid project file. The error reported was:\n%s"
        message = KDE.i18n(text) % [file, ex.message]
      rescue LoadError then message = KDE.i18n(ex.message)
      end
      if prj
        # The following two lines should be removed when we'll allow more than one project
        # open at the same time
        Ruber[:projects].current_project.close if Ruber[:projects].current_project
        Ruber[:projects].current_project = prj
        prj
      else
        KDE::MessageBox.sorry self, message
        nil
      end
    end

=begin rdoc
Override of {PluginLike#save_settings}

It saves recent files and projects, the position of the splitters and the size of
the window.

@return [nil]
=end
    def save_settings
      @workspace.store_sizes
# TODO see if the following line works. Otherwise, remove it and uncomment the one
# following it
      config = Ruber[:config].kconfig
#       config = KDE::Global.config
      recent_files = KDE::ConfigGroup.new config, 'Recent files'
      action_collection.action("file_open_recent").save_entries recent_files
      recent_projects = KDE::ConfigGroup.new config, 'Recent projects'
      action_collection.action("project-open_recent").save_entries recent_projects
      config.sync
      c = Ruber[:config][:main_window]
      c.window_size = rect.size
      nil
    end
    
=begin rdoc
Override of {PluginLike#load_settings}
@return [nil]
=end
    def load_settings
      c = Ruber[:config][:general]
      @default_script_dir = KDE::Url.from_path c.default_script_directory
      @default_project_dir = KDE::Url.from_path c.default_project_directory
      @tabs.tabs_closable = Ruber[:config][:workspace, :close_buttons] if @tabs
      nil
    end
    
=begin rdoc
Gives focus to an editor view

Giving focus to the editor implies:
* bringing the tab containing it to the foreground
* activating the editor
* giving focus to the editor

@overload focus_on_editor
  Gives focus to the active editor
  @return [EditorView,nil]
@overload focus_on_editor editor
  @param [EditorView] editor the editor to give focus to
  @return [EditorView,nil]
@overload focus_on_editor doc, hints = DEFAULT_HINTS
  @param [Document, String, KDE::Url] doc the document. If it is a string representing
    a relative path, it'll be considered relative to the current directory. If the
    string is an Url, it'll be interpreted as such
  @param [Hash] hints options to tailor the algorithm used to retrieve or create the editor.
    See {#editor_for!} for a description of the values it can contain
  @return [EditorView,nil]
@return [EditorView,nil] the editor which was given focus or *nil* if no editor
  received focus
=end  
    def focus_on_editor ed = nil, hints = DEFAULT_HINTS
      if ed
        ed = editor_for! ed, hints unless ed.is_a? EditorView
        activate_editor ed
        ed.set_focus
      else active_editor.set_focus if active_editor
      end
      active_editor
    end
        
=begin rdoc
@return [String] the default directory where to look for, and create, projects
=end
    def projects_directory
      @default_project_dir
    end
    
=begin rdoc
Executes a given action

@param [String] name the name by which the action has been registered in the
  main window's @action_collection@
@param [Array] args a list of parameters to pass to the signal or slot associated
  to the action

@see GuiPlugin#execute_action
=end
    def execute_action name, *args
      data = plugin_description.actions[name.to_s]
      if data
        slot = data.slot.sub(/\(.*/, '')
        instance_eval(data.receiver).send slot, *args
        true
      elsif (action = action_collection.action(name))
        if action.class == KDE::ToggleAction then KDE::ToggleAction
          action.instance_eval{emit toggled(*args)}
        elsif action.class == KDE::Action 
          action.instance_eval{emit triggered()}
        else action.instance_eval{emit triggered(*args)}
        end
        true
      else false
      end
    end
   
=begin rdoc
Settings widget for the workspace group
=end
    class WorkspaceSettingsWidget < Qt::Widget
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::WorkspaceSettingsWidgetBase.new
        @ui.setup_ui self
      end
    end
    
  end
  
end