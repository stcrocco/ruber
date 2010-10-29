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

require 'timeout'

require 'ruby_runner/ruby_runner'

require 'rake/rake_widgets'

module Ruber
  
=begin rdoc
Plugin which allows to run rake tasks from within Ruber, displaying the output
in a tool widget.

It provides a dialog which lists all the tasks defined in the rakefile (which can
be either chosen by the user or left to rake to find), a menu containing the tasks
defined in the current rakefile and a menu containing globally defined tasks. To
both project tasks and globally defined tasks can be assigned a shortcut.

*Note:* the list of project tasks, both in the menu and in the dialog, is computed
automatically only once, the first time it's needed. If the rakefile is later changed,
the user must manually ask to refresh the list using either the appropriate entry
in the menu, the button in the dialog or in the project configuration widget.

*Note:* this plugin only works for projects, not for single documents (the reason
being that if you have more than one file working together, you should create a
project).

@api feature rake
@plugin
=end
  module Rake
    
=begin rdoc
Plugin object for the Rake plugin.

This plugin relies in a project extension to keep a list of project tasks.

@api_method #tasks
@api_method #run_rake
=end
    class Plugin < RubyRunner::RubyRunnerPlugin
      
=begin rdoc
Base class for all the exception used by this plugin
=end
      class Error < StandardError
      end
      
=begin rdoc
Exception raised when the rake program exits with an error
=end
      class RakeError < Error
        
=begin rdoc
@return [String] the error message produced by rake
=end
        attr_reader :rake_error
      
=begin rdoc
@return [<String>] the backtrace produced by rake
=end
        attr_reader :rake_backtrace
        
=begin rdoc
@param [String] error the error message produced by rake
@param <String> backtrace an array containing the rake backtrace
=end
        def initialize error, backtrace
          super "Rake aborted saying: #{error}"
          @rake_error = error
          @rake_backtrace = backtrace
        end
      end
      
=begin rdoc
Exception raised if rake exits because it can't find a rakefile
=end
      class RakefileNotFound < Error
      end
      
=begin rdoc
Exception raised if rake doesn't exit after a given amount of time
=end
      class Timeout < Error
        
=begin rdoc
@return [Integer] the number of seconds waited before raising the exception
=end
        attr_reader :time
        
=begin rdoc
@param [Integer] seconds the the number of seconds waited before raising the exception
=end
        def initialize seconds
          super "Rake failed to finish within the allowed time (#{seconds} seconds)"
          @time = seconds
        end
        
      end
      
      
      slots :choose_and_run_task, :run_default_task, :refresh_tasks, :run_quick_task,
          :set_current_target, :fill_project_menu, :run_project_task
      
=begin rdoc
Signal emitted when the rake program started with {#run_rake} has exited
=end
      signals :rake_finished
      
=begin rdoc
@param [Ruber::PluginSpecification] psf
=end
      def initialize psf
        @quick_tasks_actions = []
        @project_tasks_actions = []
        @current_target = nil
        super psf, :rake, :scope => [:global, :document]
        setup_handlers
        Ruber[:main_window].change_state 'rake_running', false
        Ruber[:autosave].register_plugin self, true
        @output_widget = @widget
        self.connect(SIGNAL(:rake_finished)) do
          Ruber[:main_window].change_state 'rake_running', false
        end
        self.connect(SIGNAL(:process_failed_to_start)){Ruber[:main_window].change_state 'rake_running', false}
        connect Ruber[:projects], SIGNAL('current_project_changed(QObject*)'), self, SLOT(:set_current_target)
        connect Ruber[:main_window], SIGNAL('current_document_changed(QObject*)'), self, SLOT(:set_current_target)
        connect self, SIGNAL('process_finished(int, QString)'), self, SIGNAL(:rake_finished)
        connect self, SIGNAL('extension_added(QString, QObject*)'), self, SLOT(:set_current_target)
        connect self, SIGNAL('extension_removed(QString, QObject*)'), self, SLOT(:set_current_target)
        Ruber[:components].connect(SIGNAL('feature_loaded(QString, QObject*)')) do |f, o|
          o.register_plugin self, true if f == 'autosave'
        end
        fill_quick_tasks_menu
        set_current_target
      end
      
=begin rdoc
Loads the settings

While loading the settings, it also builds the Quick Tasks menu

@return [nil]
=end
      def load_settings
        cfg = Ruber[:config][:rake]
        #This method is called from Plugin#initialize before the gui is created
        fill_quick_tasks_menu if @gui
        nil
      end
      slots :load_settings
      
=begin rdoc
The rake tasks availlable, according to the given options.

To obtain the task list, this method calls <tt>rake -T</tt> synchronously (this
means that the method won't return until rake has finished). To avoid freezing
Ruber should rake go into an endless loop, this method will give up after a given
time (default: 30 seconds).

For this method to work, the output from <tt>rake -T</tt> should be a series of lines
of the form 

<tt>rake task_name    # Description</tt>

However, rake accepts a number of options which may (at least potentially) change
this output. If any of these is included in the @:options@ entry of _opts_, it'll
be removed (see {#filter_options_to_find_tasks} for a list of the problematic options)

@param [String] ruby the path of the ruby interpreter to use
@param [String] dir the directory rake should be run from
@param [Hash] opts a hash containing options to pass to rake and ruby

@option opts [String] :rake (Ruber[:config][:rake, :rake]) the path to
rake.
@option opts [<String>] :options ([]) the options to pass to rake
@option opts [<String>] :env ([]) the environment to pass to rake. Each entry
must be of the form <tt>VARIABLE=VALUE</tt>
@option opts [<String>] :ruby_options ([]) the arguments to pass to ruby
@option opts [String] :rakefile (nil) the rakefile to use. If *nil*, the -f option
won't be passed to rake, which will choose the rakefile by itself
@option opts [Integer] :timeout (30) the number of seconds before giving up if
rake hasn't finished
@raise {RakeError} if rake reports an error while executing the rakefile
@raise {RakefileNotFound} if rake can't find the rakefile
@raise {Timeout} if <tt>rake -T</tt> doesn't exit after a suitable time

@return [Hash] a hash with task names as keys and task descriptions as values
=end
      def tasks ruby, dir, opts
        rake = opts[:rake]
        default_opts = {:options => [], :env => [], :ruby_options => []}
        options = default_opts.merge opts
        options = filter_options_to_find_tasks options[:options]
        args = [rake, '-T'] + options
        args << '-f' << opts[:rakefile] if opts[:rakefile]
        env = opts[:env].join ' '
        cmd = [ruby] + opts[:ruby_options] + args
        timeout = opts[:timeout] || 30
        begin
          out, err = ::Timeout.timeout(timeout) do
            _in, out, err = Open3.popen3 env + cmd.join(' ')
            [out.read, err.read]
          end
        rescue ::Timeout::Error
          ['', 'timeout']
        end
        if err.sub!(/^\s*rake aborted!\s*\n/i, '')
          if err=~ /no rakefile found/i then raise RakefileNotFound, err
          elsif err == 'timeout'
            raise Timeout.new(timeout)
          else
            lines = err.split_lines
            err = lines.shift
            lines.delete_at(-1) if lines[-1] =~ /^\s*\(See full trace/
            raise RakeError.new err, lines
          end
        end
        out = out.split_lines.map do |l|
          if l.match(/^\s*rake\s*(.*)\s#\s+(.*)/) then [$1.strip, $2]
          else nil
          end
        end
        out.compact!
        out.to_h
      end
      
=begin rdoc
Runs rake, displaying the output in the associated output widget, according to
the given options.

@param [String] ruby the path of the ruby interpreter to use to run rake
@param [String] dir the directory rake should be run from
@param [Hash] data a hash containing the options to pass to rake or ruby
@option data [Array<String>] :ruby_options ([]) The arguments to pass to ruby itself
@option data [String] :rake (Ruber[:config][:rake, :rake]) The path to the rake program to use
@option data [Array<String>] :options ([]) The options to pass to rake
@option data [String] :rakefile (nil) The rakefile to use (use the default rakefile
      if *nil*)
@option data [Array<String>] :env ([]) The environment variables to set before calling
rake. The system environment will be used if this is empty
@option data [String] :task (nil) The task to execute. The default task will be 
executed if this is missing

@return [nil]
=end
      def run_rake ruby, dir, data
        rake = data[:rake]
        args = Array(data[:ruby_options]) + [rake] + Array(data[:options])
        args += ['-f', data[:rakefile]] if data[:rakefile]
        args << data[:task] if data[:task]
        env = Array(data[:env])
        process.environment = process.system_environment + env
        cmd = env + [ruby] + args 
        @widget.clear_output
        @widget.working_directory = dir
        Ruber[:main_window].activate_tool @widget
        Ruber[:main_window].change_state 'rake_running', true
        run_process ruby, dir, args
        nil
      end
      
=begin rdoc
Displays a message box telling why rake failed to retrieve tasks

This method is meant to be called in a @rescue@ clause for {RakeError} 
exceptions from methods which call {#tasks}. According to the type of exception
raised, the appropriate text will be displayed in the message box.

@param [RakeError] ex the exception describing the error

@return [self]
=end
      def display_task_retrival_error_dialog ex
        msg = case ex
        when RakeError
          # The <i></i> tag is needed because (according to the QMessageBox documentation),
          # for the text to be interpreted as rich text, an html tag must be present
          # before the first newline.
          "Rake aborted with the following error message:<i></i>\n<pre>#{e.rake_error}\n#{e.rake_backtrace.join "\n"}</pre>"
        when RakefileNotFound then "No rakefile was found"
        when Timeout then e.message
        end
        KDE::MessageBox.sorry Ruber[:main_window], msg
        self
      end
      
      private
      
=begin rdoc
Creates and registers the gui state handlers for the actions provided by the plugin.

@return [nil]
=end
      def setup_handlers
        @quick_tasks_handler_prc = Proc.new do |sts|
          !sts['rake_running'] and sts['rake_has_target']
        end
        register_action_handler 'rake-run', &@quick_tasks_handler_prc
        register_action_handler 'rake-run_default', &@quick_tasks_handler_prc
        nil
      end
      
=begin rdoc
Fills the Quick Tasks menu

It removes the @rake-quick_tasks_list@ action list from the menu, then
creates the actions according to the current content of the rake/quick_tasks
option and fills the menu again.

If the rake/quick_tasks option is empty, a single, disabled action with text 
@(Empty)@ is inserted.

@return nil
=end
      def fill_quick_tasks_menu
        mw = Ruber[:main_window]
        @quick_tasks_actions.each do |a| 
          mw.remove_action_handler_for a if a.object_name != 'rake-quick_task_empty_action'
          a.dispose
        end
        @gui.unplug_action_list "rake-quick_tasks_list"
        coll = @gui.action_collection
        @quick_tasks_actions = Ruber[:config][:rake, :quick_tasks].sort.map do |k, v|
          a = coll.add_action "rake-quick_task-#{k}", self, SLOT(:run_quick_task)
          a.text = k
          a.shortcut = KDE::Shortcut.new(v)
          mw.register_action_handler a, %w[rake_running active_project_exists current_document],  :extra_id => self, &@quick_tasks_handler_prc
          a
        end
        if @quick_tasks_actions.empty?
          a = coll.add_action 'rake-quick_task_empty_action'
          a.text = '(Empty)'
          a.enabled = false
          a.object_name = 'rake-quick_task_empty_action'
          @quick_tasks_actions << a
        end
        @gui.plug_action_list "rake-quick_tasks_list", @quick_tasks_actions
        nil
      end
      
=begin rdoc
Slot associated with the @rake-run@ action

It displays a dialog where the user can choose a taks for the current target,
then executes it. If the user cancels the dialog, nothing else happens

@return [nil]
=end
      def choose_and_run_task
        task = choose_task_for @current_target
        return unless task
        @current_target.extension(:rake).run_rake task
      end

=begin rdoc
Displays a dialog where the user can choose the task to run according to the settings
of the given project.

@param [AbstractProject] prj the project to read the settings from

@return [String, nil] the name of the chosen task or *nil* if the user closed the
dialog with the Cancel button
=end
      def choose_task_for prj
        dlg = ChooseTaskDlg.new prj
        return if dlg.exec == Qt::Dialog::Rejected
        dlg.task
      end
      
=begin rdoc
Slot associated with the @rake-run_default@ action.

Runs the default task for the current target
@return [nil]
=end
      def run_default_task
        @current_target.extension(:rake).run_rake nil
        nil
      end
      
=begin rdoc
Slot associated with the various quick tasks actions defined by the user

Runs the rake task whose name is equal to the name of the action which called
this slot

@return [nil]
=end
      def run_quick_task
        task = sender.text.gsub('&', '')
        @current_target.extension(:rake).run_rake task
      end
      
=begin rdoc
Slot associated with the various project tasks actions defined by the user for the
current target

Runs the rake task whose name is equal to the name of the action which called
this slot

@return [nil]
=end
      def run_project_task
        task = sender.text.gsub('&', '')
        @current_target.extension(:rake).run_rake task
      end
      
      
=begin rdoc
The project to run rake for when one of the rake menu entries is chosen

@return [DocumentProject] the {DocumentProject} associated with the current
document if the latter is a rakefile and doesn't belong to the current project
@return [Project] the current project, if the current file belongs to it or if
it isn't a rakefile
@return [nil] if there's no open document or if the current document isn't a rakefile
and there's no open project
=end
      def find_current_target
        target = Ruber[:main_window].current_document.project rescue nil
        if target.nil? or !target.has_extension? :rake
          prj = Ruber[:projects].current
          target = if prj and prj.has_extension? :rake then prj
          else nil
          end
        end
        target
      end
      
      
=begin rdoc
Given a list of rake options, creates a list containing only those which are safe
to use from {tasks}.

The options which will be removed are: -D, -n, -P, -q, --rules, -s,
-t, v, -V, -h, -e, -p and -E, because in a way or another have the capability
to change the rake output from what <tt>tasks_for</tt> expects.

<b>Note:</b> this method creates a new array; it doesn't modify _opts_.

@param [Array <String>] opts a list of options to be passed to rake

@return [Array<String>] an array containing only the safe options from _opts_
=end
      def filter_options_to_find_tasks opts
        flags_to_delete = %w[-D --describe -n --dry-run -P --prereqs -q --quiet  --rules -s --silent -t --trace -v --verbose -V --version -h -H --help]
        opts = opts.dup
        opts.delete '-D'
        opts.delete '--describe'
        opts.delete '-n'
        %w[-e --execute -p --execute-print -E --execute-continue].each do |o|
          idxs = opts.each_index.find_all{|i| opts[i] == o}
          idxs.reverse_each do |i| 
            opts.delete_at i + 1
            opts.delete_at i
          end
        end
        opts
      end
      
=begin rdoc
Changes the current target.

It uses {#find_current_target} to find out the new current target, then, if it
is different from the old one, makes the necessary connections and disconnections
and refills the project menu

@return [nil]
=end
      def set_current_target
        target = find_current_target
        return if target == @current_target
        # If the project is being closed, the extension may have been removed
        if @current_target and @current_target.extension(:rake)
          @current_target.extension(:rake).disconnect SIGNAL(:tasks_updated)
        end
        @current_target = target
        fill_project_menu
        if @current_target
          connect @current_target.extension(:rake), SIGNAL(:tasks_updated), self, SLOT(:fill_project_menu)
        end
        Ruber[:main_window].set_state 'rake_has_target', !@current_target.nil?
        nil
      end
      
=begin rdoc
Fills the Project Tasks menu, according to the current target

It clears the menu, then inserts in the menu one action for each entry in the
current target's rake/tasks option. If that option is empty, or if there's no
current target, then a single, disabled entry with text '(Empty)' is inserted in
the menu

@return [nil]
=end
      def fill_project_menu
        @gui.unplug_action_list 'rake-project_tasks_list'
        mw = Ruber[:main_window]
        @project_tasks_actions.each do |a| 
          mw.remove_action_handler_for a
          a.dispose
        end
        @project_tasks_actions.clear
        coll = @gui.action_collection
        if @current_target
          tasks = @current_target[:rake, :tasks]
          tasks.each_pair do |t, x|
            desc, short = *x
            a = coll.add_action "rake-project_task-#{t}", self, SLOT(:run_project_task)
            a.text = t
            a.shortcut = KDE::Shortcut.new short if short
            a.help_text = desc
            Ruber[:main_window].register_action_handler a, 
                %w[rake_running active_project_exists], :extra_id => self, 
                &@quick_tasks_handler_prc
            @project_tasks_actions << a
          end
        end
        if @project_tasks_actions.empty?
          a = coll.add_action 'rake-project_tasks_empty'
          a.text = "(Empty)"
          a.enabled = false
          @project_tasks_actions << a
        end
        @gui.plug_action_list 'rake-project_tasks_list', @project_tasks_actions
        nil
      end
      
=begin rdoc
Updates the tasks

@return [nil]
=end
      def refresh_tasks
        Ruber[:app].with_override_cursor do
          begin @current_target.extension(:rake).update_tasks
          rescue Error => ex
            display_task_retrival_error_dialog ex
          end
        end
      end

    end
    
  end
  
end