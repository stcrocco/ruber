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

require 'yaml'
require 'ostruct'
require 'find'
require 'pathname'
require 'enumerator'
require 'facets/kernel/__dir__'
require 'fileutils'

require 'ruber/plugin_like'
require 'ruber/exception_widgets'

module Ruber
  
=begin rdoc
  Returns the component providing the feature _feature_
  
  <b>Note:</b> this method can only be used _after_ the application has been
  created, otherwise +NoMethodError+ will be raised.
=end
  def self.[](feature)
# This instance variable is initialized by the application's constructor
    @components[feature]
  end

  
  class Application < KDE::Application
    
=begin rdoc
The default path where to look for plugins. It only includes the _plugins_ directory
in the Ruber installation path
=end
    DEFAULT_PLUGIN_PATHS = [
      File.join(KDE::Global.dirs.find_dirs( 'data', 'ruber')[0], 'plugins'),
      File.expand_path(File.join(RUBER_LIB_DIR, '..', '..', 'plugins'))
    ]
=begin rdoc
The default plugins to load. They are: ruby_development, find_in_files, syntax_checker,
command and state
=end
    DEFAULT_PLUGINS = %w[ruby_development find_in_files rake command syntax_checker state]
    
    include PluginLike
    
    slots 'load_settings()', :setup
    
# A hash containing the command line options
    attr_reader :cmd_line_options
    
=begin rdoc
The status of the application. It can be: +:starting+, +:running+ or +:quitting+
=end
    attr_reader :status

=begin rdoc
  Creates a new application object.
    
  Besides creating the application, this method also loads the core components
  and sets up a timer which will cause the application's _setup_ method to be
  called as soon as <tt>Application#exec</tt> is called. 
=end
    def initialize manager, pdf
      super()
      @components = manager
      @components.parent = self
      Ruber.instance_variable_set :@components, @components
      initialize_plugin pdf
      KDE::Global.dirs.addPrefix File.expand_path(File.join( RUBER_DATA_DIR, '..', '..', 'data'))
      icon_path = KDE::Global.dirs.find_resource('icon', 'ruber')
      self.window_icon = Qt::Icon.new icon_path
      KDE::Global.main_component.about_data.program_icon_name = icon_path
      @cmd_line_options = KDE::CmdLineArgs.parsed_args
      @plugin_dirs = []
      load_core_components
      @status = :starting
      Qt::Timer.single_shot(0, self, SLOT(:setup))
    end
    
    def quit_ruber
      @status = :quitting
      @components.shutdown
    end
    
=begin rdoc
  Returns *true* if the application is starting and *false* if it has already
  started otherwise. The application is considered to have started after the 
  application's +setup+ method has been called and has returned. Before that,
  it is considered to be starting.
    
  This method is mostly useful for plugins which need to perform different actions
  depending on whether they're loaded at application startup (in which case
  <tt>starting?</tt> returns *true*) or later (when <tt>starting?</tt> returns
  *false*)
=end
    def starting?
      @status == :starting
    end
    
    def running?
      @status == :running
    end
    
    def quitting?
      @status == :quitting
    end

=begin rdoc
It is a wrapper around ComponentManager#load_plugins which allows an easier handling
of exceptions raised by the loaded plugins.

If a block is given, it is passed to ComponentManager#load_plugins, to determine
what to do if an exception is raised while loading a plugin. If no block is given
and _silent_ is *false*, then a dialog displaying the error message is shown to
the user, who has the following options: ignore the plugin which gave the error,
skip all the remaining plugins, go on ignoring other errors or aborting. If no
block is given and _silent_ is a true value, then all errors will be ignored.

_plugins_ should be an array containing the names of the plugins to load
(dependencies) will be computed automatically. _dirs_ is an array containing the
directories where to look for plugins. If *nil*, the values stored in the
"Plugin directories" entry in the configuration file will be used.

<b>Note:</b> this method doesn't attempt to handle exceptions raised while computing
or sorting dependencies.
=end
    def safe_load_plugins plugins, silent = false, dirs = nil, &blk
      if blk.nil? and silent then blk = proc{|_pl, _e| :silent}
      elsif blk.nil?
        blk = Proc.new{|pl, e| ComponentLoadingErrorDialog.new(pl.name, e, nil).exec}
      end
      @components.load_plugins plugins, dirs || @plugin_dirs, &blk
    end

    private

=begin rdoc
  Applies the application's configuration settings. It also adds any plugin directory
  to the load path, unless it's already there.
=end
    def load_settings
      @plugin_dirs = Ruber[:config][:general].plugin_dirs
      new_dirs = @plugin_dirs - $:
      new_dirs.each{|d| $:.unshift d}
    end

=begin rdoc
  Loads the plugins in the configuration file and opens the files and/or
  projects listed in the command line. At the end, marks the application
  as _running_.
=end
    def setup
      # Create $KDEHOME/share/apps/ruber/plugins if it's missing
      begin FileUtils.mkdir DEFAULT_PLUGIN_PATHS[0]
      rescue Errno::EEXIST
      end
      chosen_plugins = Ruber[:config][:general, :plugins].map(&:to_sym)
      needed_plugins = []
      deps_problem_msg = Proc.new do |e|
        <<-EOS
        The following errors have occurred while attempting to resolve the dependencies among plugins you chose:
        #{e.message}
        
        Ruber will start with no plugin loaded. Please, use the Choose Plugins menu entry in the Settings menu to solve the issue.
        EOS
      end
      begin 
        availlable_plugins = ComponentManager.find_plugins @plugin_dirs, true
        chosen_data = chosen_plugins.map{|i| availlable_plugins[i]}.compact
        found = chosen_data.map{|i| i.name}
        if found.size != chosen_plugins.size
          missing = chosen_plugins - found
          question = <<-EOS
Ruber couldn't find some plugins it has been configured to automatically load at startup. They are:
#{missing.join("\n")}
Do you want to start the application without them or to quit Ruber?
          EOS
          ans = KDE::MessageBox.question_yes_no nil, question, 'Missing plugins',
              KDE::GuiItem.new('Start Ruber'), KDE::GuiItem.new('Quit')
          exit if ans == KDE::MessageBox::No
          chosen_plugins = found
        end
        needed_plugins = ComponentManager.fill_dependencies chosen_data, availlable_plugins.values
      rescue ComponentManager::DependencyError => e
        KDE::MessageBox.sorry nil, deps_problem_msg.call(e)
      end
      plugins = chosen_plugins + needed_plugins
      begin 
        res = safe_load_plugins(plugins) 
        unless res
          Qt::Internal.application_terminated = true
          exit 1
        end
      rescue ComponentManager::DependencyError => e
        KDE::MessageBox.error nil, deps_problem_msg.call(e)
      end
      if sessionRestored?
        Ruber[:components].restore_session Ruber[:main_window].last_session_data
      end
      @status = :running
      Ruber[:main_window].show
    end


=begin rdoc
  Loads the core components. In order, they are:
  * the configuration manager
  * the document keeper
  * the main window
  
  After creating the configuration manager, the <tt>register_with_config</tt>
  method is called
=end
    def load_core_components
      begin
        current = 'config'
        @components.load_component 'config'
        register_with_config
        %w[documents projects main_window].each do |i|
          current = i
          @components.load_component i
        end
      rescue Exception => e
        ComponentLoadingErrorDialog.new(current, e, nil, true).exec
        Qt::Internal.application_terminated = true
        exit 1
      end
      if sessionRestored? then Ruber[:main_window].restore 1, false
      else
        open_command_line_files
        if Ruber[:projects].projects.empty? and Ruber[:documents].documents.empty?
          Ruber[:main_window].display_doc Ruber[:documents].new_document
        end
      end
    end

=begin rdoc
  Registers the configuration options with the configuration manager, calls the
  <tt>load_settings</tt> method and connects to the configuration manager's
  <tt>settings_changed</tt> signal.
    
  This tasks are performed by the <tt>PluginLike#initialize_plugin</tt> method,
  but as the config manager didn't exist when that method was called,  it is
  necessary to to them here
=end
    def register_with_config
      config = Ruber[:config]
      @plugin_description.config_options.each_value{|o| config.add_option o}
      load_settings
      connect config, SIGNAL(:settings_changed), self, SLOT(:load_settings)
    end

=begin rdoc
  Opens the files and/or project listed on the command line, or creates a single
  empty document if neither files nor projects have been specified.
=end
    def open_command_line_files
      args = @cmd_line_options.files
      win = Ruber[:main_window]
      projects, files = args.partition{|f| File.extname(f) == '.ruprj'}
      prj = win.safe_open_project projects.last unless projects.empty?
      files += @cmd_line_options.getOptionList('file')
      files.each do |f| 
        win.display_document f
      end
    end

  end
  
end
