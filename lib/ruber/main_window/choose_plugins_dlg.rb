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

require 'facets/kernel/require_relative'
require_relative 'ui/choose_plugins_widget'

module Ruber

=begin rdoc
Dialog where the user can choose the plugins to load and the directories where
to look for plugins.

The main functionality is provided by the main widget, of class ChoosePluginsWidget.
=end
  class ChoosePluginsDlg < KDE::Dialog
    
    slots :write_settings

=begin rdoc
Creates a new +ChoosePluginsDlg+ and initializes it using both the settings
in the configuration file and the loaded plugins.
=end
    def initialize parent = nil
      super
      self.caption = "Choose plugins"
      self.buttons = Ok | Cancel | Apply | Default | Reset
      self.main_widget = ChoosePluginsWidget.new
      enable_button_apply false
      main_widget.connect(SIGNAL('plugins_changed()')){enable_button_apply true}
      main_widget.connect(SIGNAL('directories_changed()')){enable_button_apply true}
      connect self, SIGNAL(:applyClicked), self, SLOT(:write_settings)
      connect self, SIGNAL(:okClicked), self, SLOT(:write_settings)
      connect self, SIGNAL(:defaultClicked), main_widget, SLOT(:apply_defaults)
    end
    
# See ChoosePluginsWidget#plugins
    def plugins
      main_widget.plugins
    end

    private
    
=begin rdoc
  Writes the settings to the configuration file and disables the Apply button
=end
    def write_settings
      main_widget.write_settings
      enable_button_apply false
    end

=begin rdoc
Override the default behaviour when the user presses the Ok or Apply buttons and
there are problems with dependencies (unresolved dependencies or circular dependencies).
In this case, it displays a message box where the user can choose whether he
truly wants to save the settings or not. If he chooses to write the settings,
the usual behaviour is followed. Otherwise, the method does nothing.
=end
    def slotButtonClicked btn
      if btn == Ok || btn == Apply and !main_widget.deps_satisfied?
        msg = "There are dependencies problems among plugins. Are you sure you want to accept these settings?"
        if KDE::MessageBox.question_yes_no(nil, msg) == KDE::MessageBox::Yes
          super
        else return
        end
      else super
      end
    end

  end
  
=begin rdoc
Widget which implements most of the functionality of the ChoosePluginsDlg class.

It contains a list of plugins in the current search path, where the user can choose
the plugins to load (using checkboxes), and a list of directories where the user
can choose where to look for plugins.

In the plugin list, chosen plugins are shown with a selected mark, while plugins
which will be loaded to satisfy the dependencies of chosen plugins will be shown
with a partial mark.

Whenever the user changes the chosen plugins, the dependencies are re-computed.
If there's a problem, the user is warned with a message box.
=end
  class ChoosePluginsWidget < Qt::Widget
    
    signals :directories_changed, :plugins_changed
    
    slots :add_directory, :remove_directory, :write_settings, :apply_defaults, 
        'plugin_toggled(QStandardItem*)'

=begin rdoc
Creates a new ChoosePluginsWidget.

The list of directories where to look for plugins is read from the configuration
file. The chosen plugins are read from the configuration file, but excluding all
those which aren't currently loaded (the reason to do so is that a chosen plugin
might have failed to load and thus it should not appear in the chosen list). Also,
any plugin which is included in the chosen list but whose PDF can't be found is
excluded.

Dependencies are then computed, and dependencies of the chosen plugins are marked
as such. If a dependency problem occurs, the user is warned and all plugins are
deselected.
=end
    def initialize parent = nil
      super
      @ui = Ui::ChoosePluginsWidget.new
      @ui.setupUi self
      
      dirs = Ruber[:app].plugin_dirs
      
      @chosen_plugins = Ruber[:config][:general, :plugins].map(&:to_sym)
      loaded = Ruber[:components].plugins.map(&:plugin_name)
      @chosen_plugins.delete_if{|i| !loaded.include? i}
      
      read_plugins dirs
      res = find_deps(:sorry) do |e| 
        "There were problems making dependencies. #{create_failure_message e}\nAll plugins will be deselected"
      end
      if res
        @chosen_plugins.clear
        @needed_plugins = []
      end
      m = Qt::StandardItemModel.new @ui.plugins
      @ui.plugins.model = m
      
      connect m, SIGNAL('itemChanged(QStandardItem*)'), self, SLOT('plugin_toggled(QStandardItem*)')
      
#       def m.flags idx
#         Qt::ItemIsSelectable|Qt::ItemIsEnabled| Qt::ItemIsUserCheckable
#       end
      
      @url = KDE::UrlRequester.new self
      @ui.directories.custom_editor = @url.custom_editor
      @url.mode = KDE::File::Directory | KDE::File::LocalOnly
      connect @ui.directories, SIGNAL(:changed), self, SLOT(:slot_directories_changed)      
      @ui.directories.items = dirs
      
      fill_plugin_list
    end


    def sizeHint #:nodoc:
      Qt::Size.new 600, 550
    end
    
=begin rdoc
  Writes the settings to the configuration file. The directories listed in the
  directory widget are stored in the <i>general/plugin_dirs</i> entry, while
  the chosen plugins are stored in the <i>general/plugins</i> entry. Plugins
  which haven't been chosen but are dependencies of the chosen ones aren't stored.
=end
    def write_settings
      dirs = @ui.directories.items
      Ruber[:app].plugin_dirs = dirs
      plugins = []
      @ui.plugins.model.each_row do |r|
        plugins << r[0].data.to_string if  r[0].fully_checked?
      end
      Ruber[:config][:general, :plugins] = plugins
      Ruber[:config].write
    end
    
=begin rdoc
Sets both the chosen plugins and the plugin directories to their default values
(see Appplication::DEFAULT_PLUGIN_PATHS and Application::DEFAULT_PLUGINS). If a
dependency problem occurs, the user is warned and all plugins are deselected
=end
    def apply_defaults
      dirs = Ruber[:config].default :general, :plugin_dirs
      @chosen_plugins = Ruber[:config].default( :general, :plugins).split(',').map{|i| i.to_sym}
      read_plugins dirs
      res = find_deps(:sorry) do |e| 
        "There were problems making dependencies. #{create_failure_message e}\nAll plugins will be deselected"
      end
      if res
        @chosen_plugins.clear
        @needed_plugins = []
      end
      @ui.directories.clear
      @ui.directories.items = dirs
      
      fill_plugin_list
    end

=begin rdoc
Returns *false* if there's a dependency problem among the chosen plugins and
*true* otherwise.
=end
    def deps_satisfied?
      begin 
        find_deps
        true
      rescue ComponentManager::UnresolvedDep, ComponentManager::CircularDep
        false
      end
    end

=begin rdoc
Returns a hash containing both the chosen plugins and their dependencies. The
keys are the plugin names, while the values are the directories of the plugins.
=end
    def plugins
      @ui.plugins.model.enum_for(:each_row).map do |name, _, dir|
        [name.data.to_string.to_sym, dir.text] if name.checked?
      end.compact.to_h
    end
    
    private
    
=begin rdoc
Finds all the plugins in subdirectories of directories in the _dir_ array,
reads their PDFs and stores the data in the <tt>@plugins_files</tt> and 
<tt>@plugin_data</tt> instance variables. Also removes from the <tt>@chosen</tt>
instance variable the plugins whose PDF wasn't found.
=end
    def read_plugins dirs
      @plugins_files = ComponentManager.find_plugins dirs, true
      @plugin_data = @plugins_files.map{|_, v| [v.name, v]}.to_h
      @chosen_plugins.delete_if{|i| !@plugin_data[i]}
    end

=begin rdoc
Finds the dependencies of the chosen plugins and stores them in the
<tt>@needed_plugins</tt> instance variable. If a dependency error occurs, if a
block was passed, a message box of type _type_ is displayed. The text of the
message box is obtained by calling the block with the exception as argument. If
an error occurs and no block is passed, the exception is passed on.

This method returns *nil* if no error occurs and the value returned by the
message box otherwise.
=end
    def find_deps msg_type = :sorry
      chosen_data = @chosen_plugins.map{|i| @plugin_data[i]}
      begin @needed_plugins = ComponentManager.fill_dependencies chosen_data, @plugin_data.values
      rescue ComponentManager::UnresolvedDep, ComponentManager::CircularDep => e
        if block_given? then KDE::MessageBox.send msg_type, nil, yield(e)
        else raise
        end
      end
      nil
    end

=begin rdoc
Fills the list of plugins with the names, descriptions and paths of all plugins
found and marks each one according to whether it is among the chosen plugins,
the needed plugins or neither.

It also resizes the columns of the plugin list widget so that they match the
size of the contents.
=end
    def fill_plugin_list
      m = @ui.plugins.model
      m.clear
      m.horizontal_header_labels = %w[Name Description Directory]
      @plugins_files.each do |k, v|
        name = Qt::StandardItem.new v.about.human_name
        name.data = Qt::Variant.new(k.to_s)
        desc = Qt::StandardItem.new v.about.description
        dir = Qt::StandardItem.new v.directory
        row = [name, desc, dir]
        row.each{|i| i.flags = Qt::ItemIsSelectable|Qt::ItemIsEnabled}
        name.flags |= Qt::ItemIsUserCheckable
        m.append_row row
      end
      update_plugin_status
      3.times{|i| @ui.plugins.resize_column_to_contents i}
    end

=begin rdoc
Changes the contents of the <tt>@chosen_plugins</tt> and <tt>@needed_plugins</tt>
instance variable to reflect the checked status of the plugins in the plugin list
widget. Emits the <tt>plugins_changed</tt> signal.
=end
    def update_plugin_status
      @ui.plugins.model.each_row do |name, desc, dir|
        plug_name = name.data.to_string.to_sym
        state = if @chosen_plugins.include? plug_name then Qt::Checked
        elsif @needed_plugins.include? plug_name then Qt::PartiallyChecked
        else Qt::Unchecked
        end
        name.check_state = state
      end
      emit plugins_changed
    end

=begin rdoc
Updates the plugin status to reflect the changes made to the plugin corresponding
to the item _it_.
=end
    def plugin_toggled it
      name = it.data.to_string
      if it.check_state == Qt::Checked then @chosen_plugins << name.to_sym
      else @chosen_plugins.delete name.to_sym
      end
      find_deps{|e| create_failure_message( e) + "\nPlease, be sure to correct the problem before pressing the OK or Apply button" }
      update_plugin_status
    end
    
=begin rdoc
Updates the plugin widgets and emits the {#directories_changed signal}

If the dependencies aren't respected, the user is warned with a message box.
@return [nil]
=end
    def slot_directories_changed
      new_dirs = @ui.directories.items
      find_deps{|e| create_failure_message( e) + "\nPlease, be sure to correct the problem before pressing the OK or Apply button" }
      fill_plugin_list
      emit directories_changed
      nil
    end
    slots :slot_directories_changed

=begin rdoc
Creates an appropriate failure message for the exception _e_, which should be
an instance of ComponentManager::DependencyError. It is meant to generate consistent
error messages for all the places in the widget where a dependency error can
happen.
=end
    def create_failure_message e
      case e
      when ComponentManager::UnresolvedDep
        deps = e.missing.map do |p1, p2|
          "#{p1}, needed by #{p2.join ', '}"
        end
        "Some dependencies couldn't be satisifed:\n#{deps.join "\n"}"
      when ComponentManager::CircularDep
        deps = e.missing.map do |p1, p2|
          "#{p1} and #{p2}"
        end
        "There were circular dependencies between the following plugins:\n#{deps.join "\n"}"
      end
    end

  end

end
