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

require 'ruber/main_window/status_bar'
require 'ruber/main_window/workspace'

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
##
# :method: current_document_changed(QObject* obj) [SIGNAL]
# Signal emitted whenever the current document changes. _obj_ is the new current
# document and will be <tt>Qt::NilObject</tt> if there's no current document.
    
##
# :method: active_editor_changed(QObject* obj) [SIGNAL]
# Signal emitted whenever the active editor changes _obj_ is the new active editor
# and will be <tt>Qt::NilObject</tt> if there's no active editor
    
    
    signals 'current_document_changed(QObject*)', 'active_editor_changed(QObject*)'
        
    slots :load_settings
    
=begin rdoc
The widget which contains the tool widgets.

The primary use of this method is to connect to the signals emitted from the workspace
when a tool widget is raised, shown or hidden. All of its other methods are also
provided by the MainWindow, so you shouldn't need to access the workspace to use
them.
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
      @views = central_widget.instance_variable_get :@views
      @current_view = nil
      @active_editor = nil
      @auto_activate_editors = true
      @editors_mapper = Qt::SignalMapper.new self
      @ui_states = {}
      @actions_state_handlers = Hash.new{|h, k| h[k] = []}
      @about_plugin_actions = []
      @last_session_data = nil
      self.status_bar = StatusBar.new self
      self.connect(SIGNAL('current_document_changed(QObject*)')) do |doc|
        change_state 'current_document', !doc.nil_object?
      end
      connect Ruber[:components], SIGNAL('component_loaded(QObject*)'), self, SLOT('add_about_plugin_action(QObject*)')
      connect Ruber[:components], SIGNAL('unloading_component(QObject*)'), self, SLOT('remove_about_plugin_action(QObject*)')
      connect Ruber[:components], SIGNAL('unloading_component(QObject*)'), self, SLOT('remove_plugin_ui_actions(QObject*)')
      connect @editors_mapper, SIGNAL('mapped(QWidget*)'), self, SLOT('remove_view(QWidget*)')
      setup_actions action_collection
      @views.connect(SIGNAL('currentChanged(int)')) do |idx|
        if @auto_activate_editors then activate_editor idx 
        else activate_editor nil
        end
      end
      Ruber[:projects].connect( SIGNAL('current_project_changed(QObject*)') ) do |prj|
        change_state "active_project_exists", !prj.nil?
        make_title
      end
      connect Ruber[:projects], SIGNAL('closing_project(QObject*)'), self, SLOT('close_project_files(QObject*)')
      
      setup_GUI
      create_shell_GUI true
      
      config_obj = Ruber[:config].kconfig
      apply_main_window_settings KDE::ConfigGroup.new( config_obj, 'MainWindow')
      recent_files = KDE::ConfigGroup.new config_obj, 'Recent files'
      action_collection.action("file_open_recent").load_entries recent_files
      recent_projects = KDE::ConfigGroup.new config_obj, 'Recent projects'
      action_collection.action("project-open_recent").load_entries recent_projects
      status_bar.show
      setup_initial_states
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
Returns the editor view for the given document, creating it if needed

@param [Document, String, KDE::Url] doc the document. If it is a string representing
  a relative path, it'll be considered relative to the current directory
@return [EditorView,nil] an editor associated with the document or *nil* if _doc_
  is interpreted as document name but no documents with that name exists
@raise [ArgumentError] if _doc_ is an absolute path or a @KDE::Url@ but the file
  doesn't exist
=end
    def editor_for! doc
      if doc.is_a? KDE::Url then doc = Ruber[:documents].document doc
      elsif doc.is_a? String
        doc = File.expand_path doc unless Pathname.new(doc).absolute?
        doc = Ruber[:documents].document doc
      end
      return unless doc
      create_editor_if_needed doc
    end
    
=begin rdoc
Similar to <tt>editor_for!</tt> but it doesn't create the document or the editor
if they don't exist. If a Document for the string _doc_ doesn't exist, or if it
doesn't have an editor, returns *nil*.
=end
    def editor_for doc
      doc = Ruber[:documents][doc] if doc.is_a? String
      return unless doc
      doc.view
    end
    
=begin rdoc
Returns the active editor, or *nil* if there's no active editor.

<b>Note:</b> strictly speaking, this is not the same as <tt>tab_widget.current_widget</tt>.
For an editor to be active, it's not enough to be in the current tab, but it also
need to having been its gui merged with the main window gui.

TODO: in all places this is called, change the name from <tt>current_view</tt> to
<tt>active_editor</tt>.
=end
    def active_editor
      @active_editor
    end
    
=begin rdoc
Returns the editor in the current tab, or *nil* if there's no tab. Note that this
may not be the active editor.
=end
    def current_editor
      @views.current_widget
    end
    
=begin rdoc
Activates an editor. _arg_ can be either the index of a widget in the tab widget
(for internal uses only) or the editor to activate, or *nil*. If the editor to
activate is not in the current tab, the tab which contains it will become the current
one. Activating an editor deactivates the previously active one.

Activating an editor means merging its GUI with the main window's GUI, changing
the title of the main window accordingly and telling the status bar to refer to
that view. Also, the <tt>current_document_changed</tt> and <tt>active_editor_changed</tt>
signals are emitted.
=end
    def activate_editor arg
      view = arg.is_a?(Integer) ? @views.widget( arg ) : arg
      @views.current_widget = view if view and @views.current_widget != view
      deactivate_editor @active_editor if @active_editor != view
      @active_editor = view
      if @active_editor
        gui_factory.add_client @active_editor.doc.view.send(:internal)
        @active_editor.document.activate
      end
      make_title
      status_bar.view = @active_editor
      emit current_document_changed @active_editor ?  @active_editor.document : Qt::NilObject
      emit active_editor_changed @active_editor || Qt::NilObject
    end
    
=begin rdoc
  Returns the document associated with the active editor or *nil* if there's no
  current editor.
  
  It's almost the same as <tt>active_editor.doc</tt>, but already takes care of
  the case when <tt>active_editor</tt> is *nil*.
=end
    def current_document
      view = @views.current_widget
      view ? view.doc : nil
    end
    
=begin rdoc
Similar to <tt>editor_for!</tt> but, after having retrieved/created the editor
view, it activates and gives focus to it and moves the cursor to the line _line_
and column _col_ (both of them are 0-based indexes).
=end
    def display_doc doc, line = nil, col = 0
      ed = editor_for! doc
      return unless ed
      activate_editor ed
      ed.go_to line, col if line and col
      ed.set_focus
    end
    alias display_document display_doc
    
=begin rdoc
Executes the contents of the block with automatical editor activation disabled.
This should be used, for example, when more than one editor should be opened at
once. Without this, every new editor would become (for a little time) the active
one, with its gui merged with the main window and so on. This slows things down
and should be avoided. To do so, you use this method:
  Ruber[:main_window].without_activating do
    ed = nil
    files.each do |f|
      ed = Ruber[:main_window].editor_for! f
    end
    Ruber[:main_window].activate_editor ed
  end
After the block has been called, if there is no editor, or if the current widget
in the tab widget is different from the active editor, the current widget will
be activated.
<b>Note:</b> automatical editor activation will be restored at the end of this
method (even if exceptions occur).
=end
    def without_activating
      begin
        @auto_activate_editors = false
        yield
      ensure
        @auto_activate_editors = true
        if @views.current_index < 0 then activate_editor nil
        elsif @views.current_widget != @active_editor
          activate_editor @views.current_widget
        end
      end
    end
    
=begin rdoc
Closes the editor _ed_, deleting its tab and closing the corresponding document
and activating the next tab if auto activating is on. If _ask_ is *true*, the document
will ask whether to save modifications, otherwise it won't
=end
    def close_editor ed, ask = true
      ed.document.close_view ed, ask
    end
    
=begin rdoc
  This method is meant to be called in situation where the user may want to save
  a number of documents, for example when the application is quitting, as it avoids
  displaying a dialog box for each modified document.
    
  _docs_ can be either an array containing the documents which can be saved (documents
  in it which aren't modified will be ignored) or *nil*. In this case, all the
  open documents (with or without an open editor) will be taken into account.
  
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
    
  In the second and third cases, the method simply returns respectively +true+ or
  *false*.
    
  The value returned by this method is *false* if the user choose to abort the
  operation and *true* otherwise. Calling methods should act appropriately (for
  example, if this is called from a method which closes all documents and returns
  *false*, the documents should't be closed. If it returns true, instead, they
  should be closed, without asking again to save them).
    
  <b>Note:</b> if _docs_ only contains non-modified documents, this method will
  do nothing and immediately return *true*.
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
Asks the user whether to save the modified documents and saves the chosen ones.
Returns *true* all the selected documents where saved and *false* if some of the
document couldn't be saved.
MOVE: this should be moved to DocumentList, as there might be documents without
a window
=end
    def query_close
      if Ruber[:app].session_saving
        @session_data = Ruber[:components].session_data
      end
      true
    end
    
=begin rdoc
Provides a standard interface to creating a project from a project file named _file_, automatically
handling the possible exceptions. In particular, a message box will be displayed
if the project file doesn't exist or if it exists but it's not a valid project file.
A message box is also displayed if <i>allow_reuse</i> is *false* and the project
list already contains a project corresponding to _file_. In all cases in which a
message box is displayed *nil* is returned. Otherwise, the +Project+ object
corresponding to +file+ is returned.

If a project was created from the project file, it will be made active and the
old active project (if any) will be closed.

<b>Note:</b> _file_ must be an absolute path.
=end
    def safe_open_project file, allow_reuse = false
      prj = Ruber[:projects][file]
      if !allow_reuse and prj
        text = "A project corresponding to the file #{file} is already open. Please, close it before attempting to open it again"
        KDE::MessageBox.sorry self, KDE.i18n(text)
        return nil
      elsif prj then return prj
      end
      begin prj = Ruber[:projects].project file
      rescue Project::InvalidProjectFile => ex
        text = <<-EOS
#{file} isn't a valid project file. The error reported was:
#{ex.message}
        EOS
        KDE::MessageBox.sorry self, KDE.i18n(text)
        return nil
      rescue LoadError
        KDE::MessageBox.sorry self, KDE.i18n(ex.message)
        return nil
      end
# The following two lines should be removed when we'll allow more than one project
# open at the same time
      Ruber[:projects].current_project.close if Ruber[:projects].current_project
      Ruber[:projects].current_project = prj
      prj
    end

=begin rdoc
Saves recent files and projects, the position of the splitters and the size of
the window.

TODO: since restoring window position seems to work correctly in Kate (even if
there's still an open bug, it seems to work, at least for me) see whether it's
still necessary to store the window size.
=end
    def save_settings
      @workspace.store_sizes
# TODO use Ruber[:config] as soon as it works
#       config = Ruber[:config].kconfig
      config = KDE::Global.config
      recent_files = KDE::ConfigGroup.new config, 'Recent files'
      action_collection.action("file_open_recent").save_entries recent_files
      recent_projects = KDE::ConfigGroup.new config, 'Recent projects'
      action_collection.action("project-open_recent").save_entries recent_projects
      config.sync
      c = Ruber[:config][:main_window]
      c.window_size = rect.size
    end
    
=begin rdoc
Loads the settings (in particular, the default script directory and the
default project directory)
=end
    def load_settings
      c = Ruber[:config][:general]
      @default_script_dir = KDE::Url.from_path c.default_script_directory
      @default_project_dir = KDE::Url.from_path c.default_project_directory
    end
    
=begin rdoc
Gives the focus to the current editor view. _ed_ can be:
* an EditorView
* any argument acceptable by <tt>editor_for!</tt>
* *nil*
In the first two cases, the editor corresponding to _ed_ is activated and given
focus; in the last case the active editor is given focus.
=end  
    def focus_on_editor ed = nil
      if ed
        ed = editor_for! ed unless ed.is_a? EditorView
        activate_editor ed if ed
      end
      @active_editor.set_focus if @active_editor
    end
    
=begin rdoc
The directory where to save files which don't belong to a project
=end
#     def scripts_directory
#       @default_script_dir
#     end
    
=begin rdoc
The directory where to create new projects by default
=end
    def projects_directory
      @default_project_dir
    end
    
=begin rdoc
Executes the action with name _action_ contained in the main window's action collection.

See <tt>GuiPlugin#execute_action</tt> for more details
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
    
  end
  
end