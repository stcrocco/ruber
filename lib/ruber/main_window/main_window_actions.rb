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

require 'ruber/main_window/save_modified_files_dlg'
require 'ruber/main_window/open_file_in_project_dlg'
require_relative 'ui/main_window_settings_widget'
require 'ruber/main_window/choose_plugins_dlg'
require 'ruber/main_window/ui/new_project_widget'


module Ruber
  
  class MainWindow < KParts::MainWindow
    
    slots 'open_recent_project(KUrl)', :close_current_project, :open_file,
        :open_project, :open_file_in_project, :preferences, :choose_plugins,
        :new_project, :configure_project, 'open_recent_file(KUrl)',
        :close_current, :close_other_views, :save_all, :new_file, :activate_editor,
        :close_all_views, 'activate_editor(int)', :close_current_editor, :focus_on_editor,
        'add_about_plugin_action(QObject*)', 'remove_about_plugin_action(QObject*)',
        :display_about_plugin_dlg, :configure_document, :toggle_tool_widget
    
    private
   
=begin rdoc
Slot connected to the 'New File' action

It creates and activates a new, empty file

@return [EditorView] the editor used to display the new file
=end
    def new_file
      display_doc Ruber[:world].new_document
    end
    
=begin rdoc
Slot connected to the 'Open File' action.

It asks the user for the file(s) or URL(s) to open, then creates a document and
and editor for each of them. If a document for some of the files already exists,
it will be used. If an editor for one of the files already exists, it will be
used.

After calling this method, the editor associated with the last file chosen by the
user will become active

@return [Array<EditorView>] a list of the editors used for the files
=end
    def open_file
      dir = KDE::Url.from_path(@active_environment.project.project_directory) rescue KDE::Url.new
      filenames = KDE::FileDialog.get_open_urls(dir, OPEN_DLG_FILTERS.join("\n") , self)
#       editors = []
#       without_activating do
      editors = filenames.map{|f| gui_open_file(f, false)}
#       end
      editors[-1].set_focus unless editors.empty?
      editors
    end
    
=begin rdoc
Slot connected to the 'Open Recent File' action

It opens the file associated with the specified URL in an editor and gives it focus

@param [KDE::Url] the url of the file to open
@return [EditorView] the editor used to display the URL
=end
    def open_recent_file url
      gui_open_file url.path
    end
    
=begin rdoc
Slot connected to the 'Close Current' action

It closes the current editor, if any. If this is the last editor associated with
its document and the document is modified, the user is asked to choose whether to
save it, discard changes or not close the view.

@return [Boolean] *true* if the editor was closed and *false* otherwise
=end
    def close_current_editor
      close_editor active_editor if active_editor
    end
    
    def close_current_tab
      @active_environment.close_tab @active_environment.tab_widget.current_index
    end
    slots :close_current_tab

=begin rdoc
Slot connected to the Close Current Tab action

Closes all the editors in a given tab. If the tab contains the only view for a document,
the document is closed, too. If some of these documents are modified, the user
is asked what to do. If the user cancels the dialog, nothing is done.
@param [Integer,nil] idx the index of the tab to close. If *nil*, the current tab
  is closed
@return [Boolean] *true* if the tab was closed successfully (or the tab widget was
  empty) and *false* if the user canceled the save dialog
=end
#     def close_tab idx = nil
#       tab = idx ? @tabs.widget(idx) : @tabs.current_widget
#       return true unless tab
#       docs = tab.map(&:document).select{|d| d.views.size == 1}.uniq
#       return false unless save_documents docs
#       views = tab.to_a
#       without_activating do
#         views.each{|v| close_editor v, false} 
#       end
#       true
#     end
#     slots :close_tab
#     slots 'close_tab(int)'

=begin rdoc
Slot connected to the 'Close All Other' action
    
It closes all the editors except the current one. All documents with an open editor,
except for the one associated with the current editor, will be closed. If any document
is modified, the user will be ask whether to save them, discard the changes or
don't close the views. In the latter case, nothing will be done

@return [Boolean] *true* if the editors where successfully closed and *false*
  otherwise
=end
    def close_other_views
      to_close = @active_environment.tab_widget.inject([]) do |res, pn|
        res += pn.each_view.to_a
        res
      end
      to_close.delete active_editor
      if save_documents to_close.map{|v| v.document}.uniq
        to_close.each{|v| close_editor v, false}
        true
      else false
      end
    end
    
=begin rdoc
Slot connected with the 'Close All' action

It closes all the editors and documents associated with them. If any document
is modified and _ask_ is *true*, the user will be ask whether to save them,
discard the changes or don't close the views. In the latter case, nothing will be
done. If _ask_ is *false*, the documents will be closed even if they're modified,
without asking the user. 

@param [Boolean] ask whether or not to ask the user how to proceed if any document
  is modified. Please, set this to *false* only if you've already asked the user
  whether he wants to save the documents or not
@return [Boolean] *true* if the editors where successfully closed and *false*
otherwise
=end
    def close_all_views ask = true
      views = @active_environment.views 
      docs = views.map(&:document).uniq
      return false if ask and !save_documents docs
      @active_environment.activate_editor nil
      views.to_a.each{|v| close_editor v, false}
      true
    end
    
=begin rdoc
Slot connected to the 'Open Recent Projet' action

It opens and activates the project associated with the file described by the
given URL

@param [KDE::Url] the url of the project file to open
@return [Project,nil] the open project or *nil* if an error occurs
=end
    def open_recent_project url
      prj = safe_open_project url.path
      return unless prj
      Ruber[:world].active_project = prj
      action_collection.action('project-open_recent').add_url url, url.file_name
      prj
    end

=begin rdoc
Slot connected to the 'Open Project' action

It opens the project chosen by the user using an open dialog

@return [Project,nil] the project chosen by the user or *nil* if either the user
  cancels the dialog or an error occurs while loading the project
=end
    def open_project
      filename = KDE::FileDialog.get_open_file_name KDE::Url.from_path( 
        ENV['HOME'] ), '*.ruprj|Ruber project files (*.ruprj)', self,
        KDE::i18n('Open project')
      return unless filename
      prj = safe_open_project filename
      return unless prj
      Ruber[:world].active_project = prj
      url = KDE::Url.new prj.project_file
      action_collection.action('project-open_recent').add_url url, url.file_name
      prj
    end
    
=begin rdoc
Slot connectedto the 'Close Current Project' action

It closes the current project, if any, warning the user if, for any reason, the
project couldn't be saved
@return [nil]
=end
    def close_current_project
      unless @active_environment.project.close
        KDE::MessageBox.sorry self, "The project couldn't be saved"
      end
      nil
    end
    
=begin rdoc
Slot connected to the 'Quick Open File' action

It opens the file chosen by the user in a quick open file dialog

@return [EditorView,nil] the editor where the document has been displayed
=end
    def open_file_in_project
      dlg = OpenFileInProjectDlg.new @active_environment.project, self
      if dlg.exec == Qt::Dialog::Accepted
        editor = @active_environment.display_document dlg.chosen_file
        editor.set_focus
        action_collection.action('file_open_recent').add_url( KDE::Url.new(dlg.chosen_file) )
        editor
      end
    end

=begin rdoc
Slot connected to the 'Configure Ruber' action

It displays the configuration dialog

@return [nil]
=end
    def preferences
      Ruber[:config].dialog.exec
      nil
    end
    
=begin rdoc
Slot connected with the 'Choose Plugins' action
    
It displays the choose plugins dialog then (unless the user canceled  the dialog)
unloads all plugins and reloads them.

If there's a problem while reloading the plugins, the application is closed after
informing the user

@return [nil]
=end
    def choose_plugins
      dlg = ChoosePluginsDlg.new self
      return if dlg.exec == Qt::Dialog::Rejected
      loaded = []
      Ruber[:components].plugins.each do |pl|
        pl.save_settings
        loaded << pl.plugin_name
      end
      loaded.each{|pl| Ruber[:components].unload_plugin pl}
      res = Ruber[:app].safe_load_plugins dlg.plugins.keys.map(&:to_s)
      close unless res
      nil
    end
    
=begin rdoc
Slot connected with the 'Configure Project' action
    
It displays the configure project dialog for the current project. It does nothing
if there's no active project

@return [nil]
=end
    def configure_project
      prj = @active_environment.project
      raise "No project is selected" unless prj
      prj.dialog.exec
      nil
    end
    
=begin rdoc
Slot connected with the 'New Project' action
    
It displays the new project dialog. Unless the user cancels the dialog, it creates
the project directory and creates and saves a new project with the parameters chosen
by the user. The new project is then activated. If there was another active project,
it's closed

@return [nil]
=end
    def new_project
      dlg = NewProjectDialog.new self
      return if dlg.exec == Qt::Dialog::Rejected
      dir = File.dirname dlg.project_file
      FileUtils.mkdir dir unless File.directory? dir
      prj = Ruber[:world].new_project dlg.project_file, dlg.project_name
      prj.save
      action_collection.action('project-open_recent').add_url KDE::Url.new(dlg.project_file)
#       Ruber[:projects].close_current_project if Ruber[:projects].current
      Ruber[:world].active_project = prj
      nil
    end
    
=begin rdoc
Slot connected with the 'Next Document' action

Activates the tab to the right of the current one. If the current tab is the last
one, it returns to the first

@return [EditorView,nil] the active editor
=end
    def next_document
      tabs = @active_environment.tab_widget
      idx = tabs.current_index
      new_idx = idx + 1 < tabs.count ? idx + 1 : 0
      tabs.current_index = new_idx
      active_editor
    end

=begin rdoc
Slot connected with the 'Previous Document' action

Activates the tab to the left of the current one. If the current tab is the first
one, it jumps to the last

@return [EditorView,nil] the active editor
=end
    def previous_document
      tabs = @active_environment.tab_widget
      idx = tabs.current_index
      new_idx = idx > 0 ? idx - 1 : tabs.count - 1
      tabs.current_index = new_idx
      nil
    end
    
=begin rdoc
Slot connected to the 'Ruber User Manual' action

Opens the user's browser and points it to the user manual

@return [nil]
=end
    def show_user_manual
      KDE::Run.run_url KDE::Url.new('http://stcrocco.github.com/ruber/user_manual'), 'text/html', self
      nil
    end
    slots :show_user_manual
    
=begin rdoc
Slot connected to the actions in the "about_plugins_list" action list.

Displays a dialog with the about data regarding a plugin. The plugin to use is
determined from the triggered action

@return [nil]
=end
    def display_about_plugin_dlg
      name = sender.object_name.to_sym
      data = Ruber[name].about_data
      dlg = KDE::AboutApplicationDialog.new data, self
      dlg.exec
      nil
    end
    
=begin rdoc
Creates an About entry for a component in the "about plugins list" of the Help menu

@note this method doesn't check whether the action already exists for the given
  plugin. Since it's usually called in response to the {ComponentManager#component_loaded component_loaded}
  signal of the component manager, there shouldn't be problems with this
@note this method does nothing for core components

@param [Plugin] comp the plugin object of the plugin to create the action for
@return [nil]
=end
    def add_about_plugin_action comp
      name = comp.plugin_name
      return unless comp.is_a? Plugin
      unplug_action_list 'about_plugins_list'
      a = action_collection.add_action "__about_#{name}", self, SLOT(:display_about_plugin_dlg)
      a.object_name = name.to_s
      a.text = comp.plugin_description.about.human_name
      unless comp.plugin_description.about.icon.empty?
        a.icon = KDE::Icon.new(comp.plugin_description.about.icon) 
      end
      @about_plugin_actions << a
      plug_action_list 'about_plugins_list', @about_plugin_actions
      nil
    end
    
=begin rdoc
Removes the About entry for the given menu from the "about plugins list" of the Help menu

@note this method doesn't check whether the action for the given
  plugin actually exists. Since it's usually called in response to the
  {ComponentManager#unloading_component unloading_component} signal of the
  component manager, there shouldn't be problems with this
@note this method does nothing for core components

@param [Plugin] comp the plugin object of the plugin to remove the action for
@return [nil]
=end
    def remove_about_plugin_action comp
      name = comp.plugin_name.to_s
      return unless comp.is_a? Plugin
      unplug_action_list 'about_plugins_list'
      a = @about_plugin_actions.find{|i| i.object_name == comp.plugin_name.to_s}
      @about_plugin_actions.delete a
      plug_action_list 'about_plugins_list', @about_plugin_actions
      a.delete_later
    end
    
=begin rdoc
Slot associated with the Configure Document action

Displays the configuration dialog for the current document, if it exists

@return [nil]
=end
    def configure_document
      active_document.own_project.dialog.exec
      nil
    end
    
=begin rdoc
Slot associated with the Toggle * Tool Widget action

It identifies the tool widget to toggle basing on the name of the triggered action

@return [nil]
=end
    def toggle_tool_widget
      side = sender.object_name.match(/(left|right|bottom)/)[1].to_sym
      w = @workspace.current_widget(side)
      return unless w
      @workspace.toggle_tool w
      nil
    end
    
=begin rdoc
Slot associated with the Split Horizontally action

It splits the active view horizontally, so that a new copy of the view is created.
@note@ this method can only be called when there's an active view.

@return [EditorView] the newly created editor
=end
    def split_horizontally
      ed = @active_environment.active_editor
      @active_environment.display_document ed.document, :existing => :never,
          :new => ed, :split => :horizontal
      ed.set_focus
    end
    slots :split_horizontally

=begin rdoc
Slot associated with the Split Vertically action

It splits the active view vertically, so that a new copy of the view is created.
@note@ this method can only be called when there's an active view.

@return [EditorView] the newly created editor
=end
    def split_vertically
      ed = @active_environment.active_editor
      @active_environment.display_document ed.document, :existing => :never,
          :new => ed, :split => :vertical
      ed.set_focus
    end
    slots :split_vertically
    
=begin rdoc
Slot associated with the Switch to New Document action

It creates a new empty document, replaces the current editor with an editor
associated to it and gives focus to it. 
@note@ this method can only be called when there's an active view

@return [EditorView] the newly created editor
=end
    def switch_to_new_document
      old = active_editor
      ed = replace_editor old, Ruber[:world].new_document
      ed.set_focus if ed
    end
    slots :switch_to_new_document
    
=begin rdoc
Slot associated with the Switch to File action

It allows the user to choose a file, then creates a document for that file, replaces
the active editor with a new one associated with the document and gives focus to it.
@note@ this method can only be called when there's an active view

@return [EditorView] the newly created editor
=end
    def switch_to_file
      dir = KDE::Url.from_path(@active_environment.project.project_directory) rescue KDE::Url.new
      filename = KDE::FileDialog.get_open_url(dir, OPEN_DLG_FILTERS.join("\n") , self)
      return unless filename.valid?
      Ruber::Application.process_events
      ed = replace_editor active_editor, filename
      ed.set_focus if ed
      ed
    end
    slots :switch_to_file
    
=begin rdoc
Slot which updates the @window-switch_to_open_document_list@ action list

This method is called whenever a document is created or deleted. It updates the
action list so that it contains an action for each of the open documents
=end
    def update_switch_to_list
      unplug_action_list "window-switch_to_open_document_list"
      @switch_to_actions = Ruber[:world].documents.map do |doc|
        a = action_collection.add_action "switch_to_#{doc.document_name}", self, SLOT(:switch_to_document)
        a.text = KDE.i18n("Switch to %s") % [doc.document_name]
        a.object_name = doc.document_name
        a
      end
      @switch_to_actions = @switch_to_actions.sort_by{|a| a.object_name}
      plug_action_list "window-switch_to_open_document_list", @switch_to_actions
    end
    slots :update_switch_to_list
    
=begin rdoc
Updates the Active Project menu

@param [Project,nil] project if not *nil*, a project to exclude from the menu. This
  is meant to be used when a project is closed, since the project list notifies
  that a project is being closed _before_ removing it from the list
@return [nil]
=end
    def update_active_project_menu project = nil
      activate_action = action_collection.action 'project-active_project'
      old_actions = activate_action.actions
      activate_action.remove_all_actions
      activate_action.add_action old_actions.delete_at(0)
      old_actions.each{|a| a.delete_later}
      Ruber[:world].projects.sort_by{|pr| pr.project_name}.each do |prj|
        next if prj == project
        name = "projects-activate_project-project_file_#{prj.project_file}"
        a = activate_action.add_action prj.project_name
        a.object_name = name
      end
      nil
    end
    slots :update_active_project_menu
    slots 'update_active_project_menu(QObject*)'
    
=begin rdoc
Checks the entry in the Active Project action which corresponds to the current
project

If there's no current project, the action which deactivates all projects is selected.

If the action corresponding to the current project is already selected, nothing is
done.
@return [nil]
=end
    def select_active_project_entry
      active_project_action = action_collection.action 'project-active_project'
      to_select = action_for_project Ruber[:world].active_project
      unless to_select == active_project_action.current_action
        active_project_action.current_action = to_select
      end
      nil
    end

=begin rdoc
The action in the Active Project action list associated with a project

@param [Project,nil] prj the project. If *nil*, the action which deactivates
  all projects is returned
@return [KDE::Action] the action associated with the given project
=end
    def action_for_project prj
      active_project_action = action_collection.action 'project-active_project'
      if prj
        file = prj.project_file
        active_project_action.actions.find do |a| 
          a.object_name == "projects-activate_project-project_file_#{file}"
        end
      else active_project_action.action 0
      end
    end
    
=begin rdoc
Slot connected with the active project action

It makes the project corresponding to the selected action active. If the selected
action is the None action, then all projects will be deactivated.

If the project associated with the action is already the current project, nothing
will be done
@param [Qt::Action] act the selected action
@return [Project,nil] the new current project
=end
    def change_active_project act
      #object_name returns nil instead of an empty string if not set
      match = (act.object_name || '').match(/projects-activate_project-project_file_(.*)$/)
      prj = match ? Ruber[:world].projects[match[1]] : nil
      Ruber[:world].active_project = prj
      prj
    end
    slots 'change_active_project(QAction*)'
    
=begin rdoc
Slot associated with the actions in the Switch to Document submenu

It creates a new editor for an already-existing document and replaces the active
editor with it, giving focus to it. The document to use is determined from the
@object_name@ of the action.
@note this method can only be called when there's an active view
@note this method uses @sender@ to find out the action which emitted the signal,
  so it shouldn't be called directly
@return [EditorView] the newly created editor
=end
    def switch_to_document
      doc = Ruber[:world].documents.document_with_name sender.object_name
      ed = replace_editor active_editor, doc
      ed.set_focus if ed
    end
    slots :switch_to_document
    
=begin rdoc
Slot associated with Switch to Recent File action

It creates a new document for the given URL (if needed), creates a new editor
for it, replaces the active editor with it and gives focus to it.

@note@ this method can only be called when there's an active view
@param [KDE::Url] url the URL associated with the editor
@return [EditorView] the newly created editor

=end
    def switch_to_recent_file url
      ed = replace_editor active_editor, url
      ed.set_focus if ed
    end
    slots 'switch_to_recent_file(KUrl)'
    
=begin rdoc
Slot associated with the Next/Previous View Horizontally/Vertically actions

According to the name of the action, it gives focus to the next/previous view in
the current tab going horizontally/vertically. If the current tab only contains
one view, nothing is done.

@note@ this method uses @sender@ to find out which action emitted the signal,
  so you can't call it directly
@return [EditorView] the view which received focus
=end
    def move_among_views
      action_name = sender.object_name
      direction = action_name.match('next') ? :next : :previous
      orientation = action_name.match(/horizontal/) ? Qt::Horizontal : Qt::Vertical
      pane = find_next_pane active_editor.parent, orientation, direction
      tabs = @active_environment.tab_widget
      view = pane ? pane.view : tabs.current_widget.views[direction == :next ? 0 : -1]
      view.set_focus
    end
    slots :move_among_views
    
=begin rdoc
Finds the next or previous pane in single view mode from a given pane

According to the second argument, the direction will be either horizontal or
vertical.
    
The search will be carried out first among siblings and their children, then among
ancestors.

@param [Pane] from the pane next/previous is relative to. It *must* be a single
  view pane
@param [Integer] orientation whether to look for the next/previous pane horizontally
  or vertically. It may be either @Qt::Horizontal@ or @Qt::Vertical@
@param [Symbol] direction whether to look for the next or previous pane. It must
  be either @:next@ or @:previous@
@return [Pane,nil] the next/previous single view mode pane or *nil* if no such pane
  has been found (either because the pane is toplevel or because it's the first/last)
@todo Maybe move this method to {Pane} class
=end
    def find_next_pane from, orientation, direction
      loop do
        parent = from.parent_pane
        return nil unless parent
        idx = parent.splitter.index_of from
        if parent.orientation == orientation
          new_idx = idx + (direction == :next ? 1 : -1)
          pane = parent.splitter.widget new_idx
          return pane.views[0].parent if pane
        end
        to_try = parent.panes[direction == :next ? (idx+1)..-1 : 0...idx]
        until to_try.empty? do
          idx = direction == :next ? 0 : -1
          pane = to_try[idx]
          if pane.single_view? then to_try.delete_at idx
          else
            if pane.orientation == orientation then return pane.views[idx].parent
            else 
              to_try.delete_at idx
              to_try.unshift *pane.panes
            end
          end
        end
        from = parent
      end
    end
    
  end
  
=begin rdoc
Class containing the settings associated with the main window
=end
  class MainWindowSettingsWidget < Qt::Widget
    
=begin rdoc
Mapping between modes to open files from tool widgets and indexes in the corresponding
combo box
=end
    TOOL_OPEN_FILES = [:split_horizontally, :split_vertically, :new_tab]
    
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
    def initialize parent = nil
      super
      @ui = Ui::MainWindowSettingsWidget.new
      @ui.setupUi self
      @ui._general__default_script_directory.mode = KDE::File::Directory
      @ui._general__default_project_directory.mode = KDE::File::Directory
    end
    
=begin rdoc
Override of @Qt::Widget#sizeHint@

@return [Qt::Size] the suggested size for the widget
=end
    def sizeHint
      Qt::Size.new(380,150)
    end
    
=begin rdoc
Read method for the @general/tool_open_files@ setting
@param [Symbol] value the value of the option. It can have any value contained
  in the {TOOL_OPEN_FILES} array
@return [Symbol] value
=end
    def tool_open_files= value
      @ui._general__tool_open_files.current_index = TOOL_OPEN_FILES.index(value) || 0
      value
    end
    
=begin rdoc
Store method for the @general/tool_open_files@ setting

@return [Integer] the entry in {TOOL_OPEN_FILES} corresponding to the one selected in
the combo box
=end
    def tool_open_files
      TOOL_OPEN_FILES[@ui._general__tool_open_files.current_index]
    end
    
  end
  
=begin rdoc
Dialog where the user enters the parameters to create a new project
=end
  class NewProjectDialog < KDE::Dialog
    
=begin rdoc
Main widget for the {NewProjectDialog}
=end
    class NewProjectWidget < Qt::Widget
      
=begin rdoc
Signal emitted when the user changes the data in the widget

@param [Boolean] complete whether or not the user has filled all the necessary
      fields with correct data
=end
      signals 'complete_status_changed(bool)'
      
      slots 'data_changed()'
      
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::NewProjectWidget.new
        @ui.setupUi self
        @ui.container_dir.url = KDE::Url.new Ruber[:config][:general, :default_project_directory]
        @ui.container_dir.mode = KDE::File::Directory | KDE::File::LocalOnly|
        KDE::File::ExistingOnly
        connect @ui.project_name, SIGNAL('textChanged(QString)'), self, SLOT('data_changed()')
        connect @ui.container_dir, SIGNAL('textChanged(QString)'), self, SLOT('data_changed()')
        @ui.project_name.set_focus
        self.focus_proxy = @ui.project_name
      end
      
=begin rdoc
@return [String] the name chosen by the user for the project
=end
      def project_name
        @ui.project_name.text
      end
      
=begin rdoc
@return [String] the path of the project file
=end
      def project_file
        @ui.final_location.text
      end
      
      private
      
=begin rdoc
Slot called whenever the user changes data in the widget

It updates the Final location widget, displays the Invalid final location message
if the project directory already exists and emit the {#complete_status_changed}
signal

@return [nil]
=end
      def data_changed
        name = @ui.project_name.text
        container = @ui.container_dir.url.path || ''
        file = name.gsub(/\W/,'_')
        @ui.final_location.text = File.join container, file, "#{file}.ruprj"
        valid_container = File.exist?(container)
        valid =  (valid_container and !(name.empty? or container.empty? or 
                                        File.exist? File.join(container, file)))
        @ui.invalid_project.text = valid ? '' : 'Invalid final location'
        emit complete_status_changed(valid)
        nil
      end
      
    end
    
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
    def initialize parent = Ruber[:main_window]
      super
      self.caption = 'New Project'
      self.main_widget = NewProjectWidget.new self
      enableButtonOk false
      self.main_widget.set_focus
      connect main_widget, SIGNAL('complete_status_changed(bool)'), self, SLOT('enableButtonOk(bool)')
    end
    
=begin rdoc
@return [String] the path of the project file
=end
    def project_file
      main_widget.project_file
    end

=begin rdoc
@return [String] the name chosen by the user for the project
=end
    def project_name
      main_widget.project_name
    end
    
  end
  
end