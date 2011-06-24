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
require 'ruber/project'
require 'ruber/exception_widgets'

module Ruber
  
=begin rdoc
The component providing a feature

@param [Symbol] feature the feature the component should provide
@return [PluginLike,nil] the component providing the given feature or *nil* if
  no components provide it
@raise [NoMethodError] if called before the application is created
=end
  def self.[](feature)
# This instance variable is initialized by the application's constructor
    @components[feature]
  end

  class Application < KDE::Application
    
=begin rdoc
The default paths where to look for plugins.

It includes @$KDEHOME/share/apps/ruber/plugins@ and the @plugins@ subdirectory
of the ruber installation directory
=end
    DEFAULT_PLUGIN_PATHS = [
      File.join(KDE::Global.dirs.find_dirs( 'data', '')[0], File.join('ruber','plugins')),
      RUBER_PLUGIN_DIR
    ]
=begin rdoc
The default plugins to load
    
Currently, they are: ruby_development, find_in_files, syntax_checker, command and state
=end
    DEFAULT_PLUGINS = %w[ruby_development find_in_files rake command syntax_checker state auto_end project_browser]
    
    include PluginLike
    
    slots 'load_settings()', :setup
    
=begin rdoc
@return [Hash] the command line options passed to ruber (after they've been processed)
=end
    attr_reader :cmd_line_options
    
=begin rdoc
<<<<<<< HEAD
=======
The state Ruber is in

Ruber can be in three states:

- *starting*:= from the time it's launched to when {#setup} returns
- *running*:= from after {#setup} has returend to when the user chooses to quit
  it (either with the @File/Quit@ menu entry or clicking on the button on the title
  bar)
- *quitting*:= from when the user chooses to quit Ruber onwards
- *asking_to_quit*:= while asking the user to confirm quitting Ruber

>>>>>>> master
@return [Symbol] the status of the application. It can be: @:starting@, @:running@
  or @:quitting@
=end
    attr_reader :status

=begin rdoc
Creates a new instance of {Application}

It loads the core components and sets up a single shot timer which calls {#setup}
and is fired as soon as the event loop starts.

@param [ComponentManager] manager the component manager
@param [PluginSpecification] psf the plugin specification object describing the
  application component
=end
    def initialize manager, psf
      super()
      @components = manager
      @components.parent = self
      Ruber.instance_variable_set :@components, @components
      initialize_plugin psf
      KDE::Global.dirs.addPrefix File.expand_path(File.join( RUBER_DATA_DIR, '..', 'data'))
      icon_path = KDE::Global.dirs.find_resource('icon', 'ruber')
      self.window_icon = Qt::Icon.new icon_path
      KDE::Global.main_component.about_data.program_icon_name = icon_path
      @cmd_line_options = KDE::CmdLineArgs.parsed_args
      @plugin_dirs = []
      load_core_components
      @status = :starting
      Qt::Timer.single_shot(0, self, SLOT(:setup))
    end
    
=begin rdoc
@return [Array<String>] a list of the directories where Ruber looks for plugins
=end
    def plugin_directories
      @plugin_dirs.dup
    end
    alias :plugin_dirs :plugin_directories

=begin rdoc
Sets the list of directories where Ruber looks for plugins

This also changes the setting in the global configuration object, but it *doesn't*
write the change to file. It's up to whoever called this method to do so.

@param [Array<String> dirs] the directories Ruber should search for plugins
=end
    def plugin_directories= dirs
      @plugin_directories = dirs
      Ruber[:config][:general, :plugin_dirs] = @plugin_directories
    end
    alias :plugin_dirs= :plugin_directories=
    
=begin rdoc
Asks the user to confirm quitting Ruber

This method is called whenever Ruber needs to be closed and, in turn, calls the
{PluginLike#query_close query_close} method of each plugin and component (using
{ComponentManager#query_close}).

During the execution of this method, {#status} returns @:asking_to_quit@. After
this method returns, the status returns what it was before.
@return [Boolean] *true* if the application can be closed and *false* otherwise
=end
    def ask_to_quit
      old_status = @status
      @status = :asking_to_quit
      res = @components.query_close
      @status = old_status
      res
    end
    
=begin rdoc
Quits ruber

Sets the application status to @:quitting@ and calls {ComponentManager#shutdown}
@return [nil]
=end
    def quit_ruber
      @status = :quitting
      @components.shutdown
      nil
    end
    
=begin rdoc
Whether the application is starting or has already started

You should seldom need this method. It's mostly useful for plugins which need to
erform different actions depending on whether they're loaded at application
startup (in which case it'll return *true*) or later (when it'll return *false*)

@return [Boolean] *true* if the application status is @starting@ and *false*
  otherwise
@see #status
=end
    def starting?
      @status == :starting
    end
    
=begin rdoc
Whether the application is running or not

@return [Boolean] *true* if the application status is @running@ and *false*
otherwise
@see #status
=end 
    def running?
      @status == :running
    end

=begin rdoc
Whether the application is quitting or not

@return [Boolean] *true* if the application status is @quitting@ and *false*
otherwise
@see #status
=end 
    def quitting?
      @status == :quitting
    end

=begin rdoc
Loads plugins handling the exceptions they may raise in the meanwhile

It is a wrapper around {ComponentManager#load_plugins}.
    
If it's given a block, it simply calls {ComponentManager#load_plugins} passing
it the block.

If no block is given, the behaviour in case of an exception depends on the _silent_
argument:
* if *true*, then the error will be silently ignored and the component manager will
  go on loading the remaining plugins. Errors caused by those will be ignored as
  well
* if *false*, the user will be shown a {ComponentLoadingErrorDialog}. According
  to what the user chooses in the dialog, the component manager will behave in
  a different way, as described in {ComponentManager#load_plugins}

*Note:* this method doesn't attempt to handle exceptions raised while computing
or sorting dependencies.
@param [Array<Symbol>] plugins the names of the plugins to load. It doesn't need
  to include dependencies, as they're computed automatically
@param [Boolean] silent whether errors while loading plugins should be silently
  ignored or not
@param [Array<String>,nil] dirs the directories where to look for plugins. If *nil*,
  then the value returned by {#plugin_directories} will be used
@yield [pso, ex] block called when loading a plugin raises an exception
@yieldparam [PluginSpecification] pso the plugin specification object associated
  with the plugin which raised the exception
@yieldparam [Exception] ex the exception raised while loading the plugin
@return [Boolen] *true* if the plugins were loaded successfully and *false* otherwise
@see ComponentManager#load_plugins
@see ComponentLoadingErrorDialog
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
Override of {PluginLike#load_settings}

It reads the list of plugin directories from the configuration object, replacing
all mentions of the installation paths for a different version of Ruber with the
installation path for the current version, and adds to the load path all missing
directories
@return [nil]
=end
    def load_settings
      @plugin_dirs = Ruber[:config][:general].plugin_dirs
      ruber_base_dir = File.dirname(RUBER_DIR)
      @plugin_dirs.map! do |d| 
        if d =~ /#{File.join Regexp.quote(ruber_base_dir), 'ruber-\d+\.\d+\.\d+'}/
          RUBER_PLUGIN_DIR
        else d
        end
      end
      new_dirs = @plugin_dirs - $:
      new_dirs.each{|d| $:.unshift d}
      nil
    end

=begin rdoc
Prepares the application for running

It loads the plugins chosen by the user according to the configuration file. If
an error occurs while finding plugin dependencies (either because of a missing
dependency or a circular dependency), the user is shown a dialog asking what to
do (quit ruber or load no plugin). If an exception is raised while loading a plugin,
it's handled according to the behaviour specified in {#safe_load_plugins} with no
block given.

It also takes care of the command line options, opening the files and projects
specified in it.

At the end, the main window is shown
@return [nil]
=end
    def setup
      # Create $KDEHOME/share/apps/ruber/plugins if it's missing
      FileUtils.mkdir_p DEFAULT_PLUGIN_PATHS[0]
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
      nil
    end


=begin rdoc
Loads the core components
  
In loading order, the core components are:
* the configuration manager
* the document list
* the project list
* the main window

In case loading one of the core components raises an exception, the user is
warned with a dialog and ruber is closed.

After creating the configuration manager, {#register_with_config} is called.

If a previous session is being restored, {MainWindow#restore} is called, otherwise
an empty document is created (unless the user specified some files or project
on the command line)
@return [nil]
=end
    def load_core_components
      begin
        current = 'config'
        @components.load_component 'config'
        register_with_config
        %w[world main_window].each do |i|
          current = i
          @components.load_component i
        end
      rescue Exception => e
        ComponentLoadingErrorDialog.new(current, e, nil, true).exec
        Qt::Internal.application_terminated = true
        exit 1
      end
      if sessionRestored? then Ruber[:main_window].restore 1, false
      else open_command_line_files
      end
    end

=begin rdoc
Registers the configuration options with the configuration manager
    
This means, calling {#load_settings} and connecting to the configuration manager's
{ConfigurationManager#settings_changed settings_changed}signal.
  
This tasks are usually performed by {PluginLike#initialize_plugin},
but as the config manager didn't exist when that method was called,  it is
necessary to to them later
@return [nil]
=end
    def register_with_config
      config = Ruber[:config]
      @plugin_description.config_options.each_value{|o| config.add_option o}
      load_settings
      connect config, SIGNAL(:settings_changed), self, SLOT(:load_settings)
      nil
    end

=begin rdoc
  Opens the files and/or project listed on the command line
    
  If neither files nor projects have been specified on the command line, 
  a single empty document is created.
  @return [nil]
=end
    def open_command_line_files
      urls = @cmd_line_options.urls
      win = Ruber[:main_window]
      projects, files = urls.partition{|u| File.extname(u.to_local_file || '') == '.ruprj'}
      prj = win.safe_open_project projects.last.to_local_file unless projects.empty?
      files += @cmd_line_options.getOptionList('file').map do |f|
        url = KDE::Url.new f
        url.path = File.expand_path(f) if url.protocol.empty?
        url
      end
      files.each do |f| 
        win.display_document f
      end
      nil
    end
    
  end
  
end
