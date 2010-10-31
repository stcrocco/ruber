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

@return [nil]
=end
    def new_file
      display_doc Ruber[:docs].new_document
      nil
    end
    
=begin rdoc
Slot connected to the 'Open File' action.

It opens in an editor and activates a document associated with a file chosen by the
user with an OpenFile dialog (the document is created if needed). It also adds
the file to the list of recently opened files.

@return [nil]
=end
    def open_file
      dir = KDE::Url.from_path(Ruber.current_project.project_directory) rescue KDE::Url.new
      filenames = KDE::FileDialog.get_open_urls(dir, OPEN_DLG_FILTERS.join("\n") , self)
      without_activating do
        filenames.each{|f| gui_open_file f}
      end
      nil
    end
    
=begin rdoc
Slot connected to the 'Open Recent File' action

It opens the file associated with the specified URL in an editor and gives it focus

@param [KDE::Url] the url of the file to open
@return [nil]
=end
    def open_recent_file url
      gui_open_file url.path
      nil
    end
    
=begin rdoc
Slot connected to the 'Close Current' action

It closes the current editor, if any. If the documents is modified,
it allows the user to choose what to do via a dialog. If the user chooses to abort
closing, nothing is done

@return [nil]
=end
    def close_current_editor
      close_editor active_editor if active_editor
      nil
    end

=begin rdoc
Slot connected to the 'Close All Other' action
    
It closes all the editors except the current one. If some documents are modified,
it allows the user to choose what to do via a dialog. If the user chooses to abort
closing, nothing is done.

@return [nil]
=end
    def close_other_views
      to_close = @views.select{|w| w != @views.current_widget}.map{|w| w.document}
      if save_documents to_close
        without_activating do
          to_close.dup.each{|d| d.close_view d.view, false}
        end
      end
      nil
    end
    
=begin rdoc
Slot connected with the 'Close All' action

It closes all the editors. If some documents are modified,
it allows the user to choose what to do via a dialog. If the user chooses to abort
closing, nothing is done.

@return [nil]
=end
    def close_all_views ask = true
      return if ask and !save_documents @views.map{|v| v.document}
      without_activating do
        @views.to_a.each do |w| 
          close_editor w, false
        end
      end
      nil
    end
    
=begin rdoc
Slot connected to the 'Open Recent Projet' action

It opens a project and activates a project

@param [KDE::Url] the url of the project file to open
@return [nil]
=end
    def open_recent_project url
      return unless safe_open_project url.path
      action_collection.action('project-open_recent').add_url url, url.file_name
      nil
    end

=begin rdoc
Slot connected to the 'Open Project' action

It opens the project chosen by the user using an open dialog

@return [nil]
=end
    def open_project
      filename = KDE::FileDialog.get_open_file_name KDE::Url.from_path( 
        ENV['HOME'] ), '*.ruprj|Ruber project files (*.ruprj)', self,
        KDE::i18n('Open project')
      return unless filename
      prj = safe_open_project filename
      url = KDE::Url.new prj.project_file
      action_collection.action('project-open_recent').add_url url, url.file_name
      nil
    end
    
=begin rdoc
Slot connectedto the 'Close Current Project' action
=end
    def close_current_project
      unless Ruber[:projects].current_project.close
        KDE::MessageBox.sorry self, "The project couldn't be saved"
      end
    end
    
=begin rdoc
Slot connected to the 'Quick Open File' action

It opens the file chosen by the user in a quick open file dialog

@retrun [nil]
=end
    def open_file_in_project
      dlg = OpenFileInProjectDlg.new self
      if dlg.exec == Qt::Dialog::Accepted
        display_doc dlg.chosen_file
        action_collection.action( 'file_open_recent').add_url( KDE::Url.new(dlg.chosen_file) )
      end
      nil
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
      prj = Ruber.current_project
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
      FileUtils.mkdir dir
      prj = Ruber[:projects].new_project dlg.project_file, dlg.project_name
      prj.save
      action_collection.action('project-open_recent').add_url KDE::Url.new(dlg.project_file)
      Ruber[:projects].close_current_project if Ruber[:projects].current
      Ruber[:projects].current_project = prj
      nil
    end
    
=begin rdoc
Slot connected with the 'Next Document' action

Makes the editor to the right of the current one active. If there's no editor to
the right, the first editor becomes active

@return [nil]
=end
    def next_document
      idx = @views.current_index
      new_idx = idx + 1 < @views.count ? idx + 1 : 0
      activate_editor new_idx
      nil
    end

=begin rdoc
Slot connected with the 'Previous Document' action

Makes the editor to the left of the current one active. If there's no editor to
the left, the last editor becomes active

@return [nil]
=end
    def previous_document
      idx = @views.current_index
      new_idx = idx > 0 ? idx - 1 : @views.count - 1
      activate_editor new_idx
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

*Notes:* 
# this method doesn't check whether the action already exists for the given
  plugin. Since it's usually called in response to the {ComponentManager#component_loaded component_loaded}
  signal of the component manager, there shouldn't be problems with this
# this method does nothing for core components

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

*Notes:* 
# this method doesn't check whether the action for the given
plugin actually exists. Since it's usually called in response to the {ComponentManager#unloading_component unloading_component}
signal of the component manager, there shouldn't be problems with this
# this method does nothing for core components

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
      current_document.own_project.dialog.exec
      nil
    end
    
=begin rdoc
Slot associated with the Toggle * Tool Widget

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
    
  end
  
=begin rdoc
Class containing the settings associated with the main window
=end
  class MainWindowSettingsWidget < Qt::Widget
    
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