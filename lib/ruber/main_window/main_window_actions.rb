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
  
=begin rdoc
===Slots
* <tt>new_file()</tt>
=end
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
=end
    def new_file
      display_doc Ruber[:docs].new_document
    end
    
=begin rdoc
Slot connected to the 'Open File' action. It displays an 'open file' dialog where
the user can choose the file to open, then creates a new document for it, creates
an editor for it and activates and gives focus to it. It also adds the url to the
list of recently opened files.

The open file dialog is initially in the project directory of the current project,
if there's a current project and in the default script thirectory otherwise.
=end
    def open_file
      dir = KDE::Url.from_path(Ruber.current_project.project_directory) rescue KDE::Url.new
      filenames = KDE::FileDialog.get_open_file_names(dir, OPEN_DLG_FILTERS.join("\n") , self)
      without_activating do
        filenames.each{|f| gui_open_file f}
      end
    end
    
=begin rdoc
Slot connected to the 'Open Recent File' action
=end
    def open_recent_file url
      gui_open_file url.path
    end
    
=begin rdoc
Slot connected to the 'Close Current' action. It closes the current editor
=end
    def close_current_editor
      close_editor active_editor if active_editor
    end

=begin rdoc
Slot connected to the 'Close All Other' action. It closes all the editors except
the current one
=end
    def close_other_views
      to_close = @views.select{|w| w != @views.current_widget}.map{|w| w.document}
      if save_documents to_close
        without_activating do
          to_close.dup.each{|d| d.close_view d.view, false}
        end
      end
    end
    
=begin rdoc
Slot connected with the 'Close All' action
=end
    def close_all_views ask = true
      return if ask and !save_documents @views.map{|v| v.document}
      without_activating do
        @views.to_a.each do |w| 
          close_editor w, false
        end
      end
    end
    
=begin rdoc
Slot connected to the 'Open Recent Projet' action
=end
    def open_recent_project url
      return unless safe_open_project url.path
      action_collection.action('project-open_recent').add_url url, url.file_name
    end

=begin rdoc
Slot connected to the 'Open Project' action
=end
    def open_project
      filename = KDE::FileDialog.get_open_file_name KDE::Url.from_path( 
        ENV['HOME'] ), '*.ruprj|Ruber project files (*.ruprj)', self,
        KDE::i18n('Open project')
      return unless filename
      prj = safe_open_project filename
      url = KDE::Url.new prj.project_file
      action_collection.action('project-open_recent').add_url url, url.file_name
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
Slot connected to the 'Quick Open File' action. Displays the QuickOpenFile dialog
TODO: MOVE? Changed name?
=end
    def open_file_in_project
      dlg = OpenFileInProjectDlg.new self
      if dlg.exec == Qt::Dialog::Accepted
        display_doc dlg.chosen_file
        action_collection.action( 'file_open_recent').add_url( KDE::Url.new(dlg.chosen_file) )
      end
    end

=begin rdoc
Slot connected to the 'Configure Ruber' action
=end
    def preferences
      Ruber[:config].dialog.show
    end
    
=begin rdoc
Slot connected with the 'Choose Plugins' action. Displays the Choose Plugin dialog
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
    end
    
=begin rdoc
Slot connected with the 'Configure Project' action. It displays the Configure 
Project dialog
=end
    def configure_project
      prj = Ruber.current_project
      raise "No project is selected" unless prj
      prj.dialog.exec
    end
    
=begin rdoc
Slot connected with the 'New Project' action. It displays the New Project dialog.
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
    end
    
=begin rdoc
Switches to the next document
=end
    def next_document
      idx = @views.current_index
      new_idx = idx + 1 < @views.count ? idx + 1 : 0
      activate_editor new_idx
    end

=begin rdoc
Switches to the previous document
=end
    def previous_document
      idx = @views.current_index
      new_idx = idx > 0 ? idx - 1 : @views.count - 1
      activate_editor new_idx
    end
    
=begin rdoc
Opens the user's browser and points it to the user manual
=end
    def show_user_manual
      KDE::Run.run_url KDE::Url.new('http://stcrocco.github.com/ruber/user_manual'), 'text/html', self
    end
    slots :show_user_manual
    
=begin rdoc
Slot connected to the actions in the "about_plugins_list" action list.

Displays a dialog with the about data regarding a plugin. The plugin to use is
determined from the triggered action
=end
    def display_about_plugin_dlg
      name = sender.object_name.to_sym
      data = Ruber[name].about_data
      dlg = KDE::AboutApplicationDialog.new data, self
      dlg.exec
    end
    
=begin rdoc
Adds an action to the "about_plugins_list" action list which displays the AboutData
dialog for the plugin _comp_.

<b>Note:</b> if _comp_ is not a plugin (for example, it's a core component) this
method does nothing
<b>Note:</b> this method doesn't check whether such an action for the component
_comp_ already exists. Usually, this is called in response to the <tt>component_loaded</tt>
signal from the component manager, so things should work automatically.
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
    end
    
=begin rdoc
Removes from the "about_plugins_list" action list the action corresponding to the
plugin _comp_.

<b>Note:</b> if _comp_ is not a plugin (for example, it's a core component) this
method does nothing
<b>Note:</b> this method doesn't check whether such an action for the component
_comp_ actually exists. Usually, this is called in response to the <tt>unloading_component</tt>
signal from the component manager, so things should work automatically.
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
Displays the configuration dialog for the current project, if it exists
=end
    def configure_document
      current_document.own_project.dialog.exec
    end
    
    def toggle_tool_widget
      side = sender.object_name.match(/(left|right|bottom)/)[1].to_sym
      w = @workspace.current_widget(side)
      return unless w
      @workspace.toggle_tool w
    end
    
  end
  
  class MainWindowSettingsWidget < Qt::Widget
    
    def initialize parent = nil
      super
      @ui = Ui::MainWindowSettingsWidget.new
      @ui.setupUi self
      @ui._general__default_script_directory.mode = KDE::File::Directory
      @ui._general__default_project_directory.mode = KDE::File::Directory
    end
    
    def sizeHint
      Qt::Size.new(380,150)
    end
    
  end
  
  class NewProjectDialog < KDE::Dialog
    
    class NewProjectWidget < Qt::Widget
      
      signals 'complete_status_changed(bool)'
      
      slots 'data_changed()'
      
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
      
      def project_name
        @ui.project_name.text
      end
      
      def project_file
        @ui.final_location.text
      end
      
      private
      
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
      end
      
    end
    
    def initialize parent = Ruber[:main_window]
      super
      self.caption = 'New Project'
      self.main_widget = NewProjectWidget.new self
      enableButtonOk false
      self.main_widget.set_focus
      connect main_widget, SIGNAL('complete_status_changed(bool)'), self, SLOT('enableButtonOk(bool)')
    end
    
    def project_file
      main_widget.project_file
    end
    
    def project_name
      main_widget.project_name
    end
    
  end
  
end