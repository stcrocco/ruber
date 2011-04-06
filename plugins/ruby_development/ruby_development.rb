require 'ruber/filtered_output_widget'

require 'ruby_runner/ruby_runner'

require_relative 'ui/project_widget'
require_relative 'ui/config_widget'

module Ruber
  
=begin rdoc
Plugin which allows the user to run the current project or file he's wokring on
in ruby

This plugin allows to run in ruby the main file specified by the current project,
the file corresponding to the current document or another file specified by the
user. The output of the program (both standard output and standard error) are
displayied in a tool widget.

To allow ruby to run a remote file (or a document associated with a remote file),
a temporary file is created and the contents of the remote file are copied in it.

The interpreter to use can be set document- or project-wise using the Ruby runner
plugin.

An action and an option are provided to decide whether the program should or
not be run in a terminal. The action, if checked, has precedence over the option,
so the user can force a program to be run in a terminal.

For a program to be run in terminal, the @Konsole@ program must be installed.

@todo Allow for other programs to be used as terminals
@todo Allow to run unsaved documents in ruby by saving them to temporary files

@api feature ruby_development
@plugin Plugin
=end
  module FilesRunner
    
=begin rdoc
Plugin object for the Files runner plugn
@api_method #run_document
@api_method #run_project
@api_method #run_file
@api_method #run_ruby
@api_method #run_in_terminal?
=end
    class Plugin < RubyRunner::RubyRunnerPlugin
      
      FakeFileInfo = Struct.new :file, :url
      
      slots :load_settings
      
=begin rdoc
@param [PluginSpecification] the {PluginSpecification} describing the plugin
=end
      def initialize psf
        super psf, :ruby, :scope => [:document, :global], :file_extension => %w[*.rb Rakefile rakefile], 
            :mimetype => ['application/x-ruby'], :place => [:local, :remote]
        process.next_open_mode = Qt::IODevice::ReadOnly | Qt::IODevice::Unbuffered
        Ruber[:autosave].register_plugin self, true
        connect self, SIGNAL('process_finished(int, QString)'), self, SLOT('ruby_exited(int, QString)')
        self.connect(SIGNAL(:process_failed_to_start)){@gui.action_collection.action('ruby_runner-stop').enabled = false}
        Ruber[:main_window].change_state 'ruby_running', false
        register_action_handler('ruby_runner-run') do |states| 
          (states['current_document'] or states['active_project_exists']) and
              !states['ruby_running']
        end
        register_action_handler('ruby_runner-run_current_file') do |states|
          states['current_document'] and ! states['ruby_running']
        end
        Ruber[:components].connect(SIGNAL('feature_loaded(QString, QObject*)')) do |f, o|
          o.register_plugin self, true if f == 'autosave'
        end
        @output_widget = @widget
        @fake_file = nil
      end

=begin rdoc
Runs ruby the given script in ruby

The output of ruby is displayed in the associated output widget. If desired, 
files are autosaved before running it.

If ruby is already running, or if autosaving fails, noting is done.

@param [String] script the ruby script to execute (either absolute path or relative
      to the @:dir@ entry of _opts_)
@param [Hash] opts options to fine-tune the behaviour of ruby
@param [Hash] autosave_opts options telling whether and how autosave files
@param [Proc] blk a block to pass to autosave. If not given, no block will be
passed to autosave

@option opts [String] :ruby (Ruber[:config][:ruby, :ruby]) the ruby interpreter
to use
@option opts [Array<String>] :ruby_options (Ruber[:config][:ruby, :ruby_options])
an array with the options to pass to the ruby interpreter
@option opts [Array<String>] :options ([]) an array with the options to pass
to the script
@option opts [String] :dir (Dir.pwd) the directory to run ruby from

@option autosave_opts [Array<Document>,Symbol] :files (nil) the documents to autosave.
It can be anything which can be passed as second parameter to {Autosave::AutosavePlugin#autosave}.
If it's *nil*, autosave won't be used
@option autosave_opts [Symbol, Plugin] :plugin (Ruber[:ruby_development]) the value to pass
as first argument to {Autosave::AutosavePlugin#autosave}
@option autosave_opts [Boolean] :stop_on_failure (nil) as in {Autosave::AutosavePlugin#autosave}
@option autosave_opts [Symbol] :on_failure (nil) as in {Autosave::AutosavePlugin#autosave}
@option autosave_opts [String] :message (nil) as in {Autosave::AutosavePlugin#autosave}

@return [Boolean] *true* if the process is started and *false* otherwise
(including the case when the process was already running or autosaving failed)

@see Autosave::AutosavePlugin#autosave
=end
      def run_ruby script, opts, autosave_opts = {}, &blk
        default = {
          :ruby => Ruber[:config][:ruby, :ruby],
          :ruby_options => Ruber[:config][:ruby, :ruby_options],
          :dir => Dir.pwd,
          :options => []
          }
        opts = default.merge opts
        return false unless process.state == Qt::Process::NotRunning
        if autosave_opts[:files]
          plug = autosave_opts[:plugin] || self
          what = autosave_opts[:files]
          return false unless Ruber[:autosave].autosave plug, 
              what, autosave_opts, &blk
        end
        @widget.working_directory = opts[:dir]
        @widget.clear_output
        cmd = opts[:ruby_options] + [script] + opts[:options]
        Ruber[:main_window].show_tool @widget
        Ruber[:main_window].change_state 'ruby_running', true
        if opts[:run_in_terminal]
          terminal, *term_opts = terminal_command opts[:dir], ([opts[:ruby]] + cmd)
          run_process terminal, opts[:dir], term_opts
        else run_process opts[:ruby], opts[:dir], cmd
        end
        true
      end
      
=begin rdoc
Runs either the project main program or the file in the current view in ruby,
displaying the output in the output tool widget

This method calls {#run_project} or {#run_document} (with the current document)
if theere's a global project or an active document. If there isn't either a global
project nor a document, then {#run_file} is used.

@return [Boolean] *true* or *false* depending on whether the ruby process was
started correctly or not.

@see #run_project
@see #run_document
@see #run_file  
=end
      def run
        if Ruber[:world].active_project then run_project
        elsif (doc = Ruber[:main_window].current_document) then run_document doc
        else run_file
        end
      end
      slots :run

=begin rdoc
Runs the main program of the project.
      
It uses the project settings for options, working directory and so on.
      
If the appropriate option is set, it will attempt to save all the documents
corresponding to files in the project before executing. If it fails, then ruby
won't be run.

This method calls {#run_ruby_for} internally.
@return [Booelan] *true* or *false* depending on whether the ruby process was
started successfully.
@see #run_ruby_for
=end
      def run_project
        prj = Ruber.current_project
        data = prj[:ruby]
        prog = Pathname.new(data[:main_program, :abs])
        wdir = Pathname.new(data[:working_dir, :abs]||prj.project_dir)
        prog = (prog.relative_path_from(wdir)).to_s
        run_ruby_for prj, prog, wdir.to_s, data[:options], run_in_terminal?(prj),
            :files => :project_files, :on_failure => :ask
      end
      
=begin rdoc
Runs the file associated with the given document in ruby
      
If the user has enabled autosave for this plugin, the document will be saved before
ruby is run.
      
Ruby will be executed from the directory where the file is, while the interpreter
to use, the options to pass to ruby and those to pass to the program are read
from the {DocumentProject} associated with the document itself.

The {#run_in_terminal?} method is used to decide whether the program should be
run in a terminal window or not.

This method uses {#run_ruby_for}.

@param [Ruber::Document] doc the document to run in ruby
@return [Boolean] *true* or *false* depending on whether the ruby process was started
successfully or not

@see #run_ruby_for
=end
      def run_document doc
        return unless doc.save if !doc.has_file?
        prj = doc.project
        file = File.basename(doc.path)
        dir = File.dirname(doc.path)
        url = doc.url
        if url.remote_file?
          @fake_file = FakeFileInfo.new Tempfile.new('ruby_development'), url
          @fake_file.file.write doc.text
          @fake_file.file.flush
          file = @fake_file.file.path
          dir = ENV['HOME']
        end
        unless prj.has_setting?(:ruby, :options)
          KDE::MessageBox.sorry nil, "The document #{url.pretty_url} doesn't seem to be a ruby file, so it can't be run"
          return
        end
        run_ruby_for prj, file, dir, prj[:ruby, :options], run_in_terminal?(doc.project),
            :files => [doc], :on_failure => :ask
      end
      
=begin rdoc
Runs a file in ruby.
      
If the file is associated with a document, this method will work like {#run_document}.

The file can be local or remote.

Ruby will be executed from the directory where the file is or from the user's
home directory if the file is remote.

The program will be run in a terminal if the corresponding action is checked.

This method uses {#run_ruby_for}

*Note:* it is not possible to specify command line options to be passed to _file_.
@param [String, nil] file the path or url of the file to run. If *nil*, an "Open file"
dialog is shown to the user
@return [Boolean, nil] *true* or *false* depending on whether the ruby process
was started. If the user pressed the Cancel button of the dialog, *nil* is returned.
@see #run_ruby_for
=end
      def run_file file = nil
        if file then url = KDE::Url.new file
        else
          url = KDE::FileDialog.get_open_url KDE::Url.new(Ruber[:config][:general, :default_script_directory]),
              "*.rb|Ruby files (*.rb)", nil, "Choose file to run"
          return unless url
          file = url.to_encoded.to_s
        end
        
        if doc = Ruber[:world].documents.document_for_url(url)
         return run_document doc 
        end
        
        if url.local_file?
          dir = File.dirname(file)
          file = File.basename(file)
        else
          @fake_file = FakeFileInfo.new Tempfile.new('ruby_development'), url
          downloaded = KIO::NetAccess.download url, @fake_file.file.path, Ruber[:main_window]
          unless downloaded
            KDE::MessageBox.sorry Ruber[:main_window], KIO::NetAccess.last_error_string
            return
          end
          file = @fake_file.file.path
          dir = ENV['HOME']
        end
        run_ruby_for nil, file, dir, [], run_in_terminal?
      end
      slots :run_file
      
=begin rdoc
Override of {Ruber::PluginLike#register_with_project Ruber::Plugin#register_with_project}
      
This mehtods sets the @ruby/main_program@ project option to bin/project_name if
it's empty and sets up a connection with the {AbstractProject#option_changed option_changed}
signal of the project to do the same whenever this option changes.

It works as {Ruber::PluginLike#register_with_project Ruber::Plugin#register_with_project}
if the project has document scope

@param [Ruber::AbstractProject] prj the project to registeer with
@return [nil]
=end
      def register_with_project prj
        super
        return unless prj.scope == :global
        if prj[:ruby, :main_program].empty?
          prj[:ruby, :main_program] = File.join('bin',prj.project_name.gsub(/\W/,'_').downcase)
        end
        prj.connect(SIGNAL('option_changed(QString, QString)')) do |g, n|
          if g == 'ruby' and n == 'main_program' && prj[:ruby, :main_program].empty?
            prj[:ruby, :main_program] = File.join 'bin',prj.project_name.gsub(/\W/,'_').downcase
          end
        end
        nil
      end
      
      private
      
=begin rdoc
The command line to use to run the given ruby command in a terminal

This method replaces every instance of @%d@ in the @ruby/run_in_terminal_cmd@
setting with the working directory and every instance of @%r@ with the ruby command.
If @%r@ is sourrounded by spaces, it'll be replaced by _ruby_command_ as it is;
it @%r@ is part of a string, it'll be replaced by the elements of _ruby_command_
joined with spaces.

@param [String] dir the working directory
@param [Array<String>] ruby_command the ruby command to execute in the terminal
@return [Array<String>] the command to run the terminal, in a form suitable to be
  passed to {#run_process}
=end
      def terminal_command dir, ruby_command
        cmd = Ruber[:config][:ruby, :run_in_terminal_cmd].split(/\s+/)
        cmd.each do |c|
          c.gsub!('%d', dir)
          c.gsub!('%r', ruby_command.join(' ')) unless c == '%r'
        end
        cmd.each_with_index.find{|e, i| e == '%r'}.each_index{|i| cmd[i] = ruby_command}
        cmd.flatten
      end
      
=begin rdoc
Starts executing a given ruby program and displays the tool widget

This method uses {RubyRunner::RubyRunnerPluginInternal#ruby_command_for RubyRunner::RubyRunnerPlugin#ruby_command_for} to retrieve the first part
of the command line to use and {#run_ruby} to actually start the ruby process.

@param [Ruber::AbstractProject, Ruber::Document, String, nil] what has the same
meaning as in {RubyRunner::RubyRunnerPluginInternal#ruby_command_for RubyRunner::RubyRunnerPlugin#ruby_command_for}
@param [String] file the filename of the script to run
@param [String] dir has the same meaning as in {RubyRunner::RubyRunnerPluginInternal#ruby_command_for RubyRunner::RubyRunnerPlugin#ruby_command_for}
@param [<String>] prog_options a list of the command line options to pass to the
program (not to ruby itself)
@param [Boolean] run_in_terminal whether to run the program in a terminal window
or not
@param [Hash] autosave_opts has the same meaning as in {#run_ruby}
@param [Proc] blk has the same meaning as in {#run_ruby}
@return [Boolean] *true* or *false* depending on whether the ruby process was
started correctly
@see #run_ruby
@see RubyRunner::RubyRunnerPluginInternal#ruby_command_for
=end
      def run_ruby_for what, file, dir, prog_options, run_in_terminal, autosave_opts={}, &blk
        ruby, *ruby_opts = ruby_command_for what, dir
        opts = {
          :dir => dir,
          :options => prog_options,
          :run_in_terminal => run_in_terminal,
          :ruby => ruby,
          :ruby_options => ruby_opts
          }
        run_ruby file, opts, autosave_opts, &blk
      end

=begin rdoc
Runs the current document in ruby

If there's an open document, it works like {#run_document}, otherwise it does
nothing
@return [Boolean, nil] *true* or *false* depending on whether the ruby process
was started correctly and *nil* if no document exists
@see {#run_document}
=end
      def run_current_document
        doc =  Ruber[:main_window].current_document
        return unless doc        
        run_document doc
      end
      slots :run_current_document

=begin rdoc
Whether a given ruby program should be run in terminal or not

This method takes into account the @ruby/run_in_terminal@ option stored in the
given project (if any) and the state of the @ruby_runner-run_in_terminal@ action
(which, if checked, overrides the option).

*Note:* while the user can, by checking the action, force a program to be run in terminal
even if the project doesn't say so, there's no way in which he can force a program
to be run without a terminal if the project says it should be run in a terminal
(because if the action is unchecked, only the project option is taken into account).

@param [Ruber::AbstractProject,nil] prj the project from which to retrieve the
settings. If *nil*, only the action will be taken into account
@return [Boolean] *true* if the program should be run in terminal and *false*
otherwise.
=end
      def run_in_terminal? prj = nil
        action_collection.action('ruby_runner-run_in_terminal').checked? ||
            (prj and prj[:ruby, :run_in_terminal])
      end

=begin rdoc
Slot called when the ruby process exited

Resets the UI, scrolls the tool widget at the end and gives focus to the editor
@return [nil]
=end
      def ruby_exited code, reason
        Ruber[:main_window].change_state 'ruby_running', false
        @widget.scroll_to -1
        Ruber[:main_window].focus_on_editor
        if @fake_file
          @fake_file.file.close true
          @fake_file = nil
        end
        nil
      end
      slots 'ruby_exited(int, QString)'
      
=begin rdoc
Replaces the path of the fake file used for running remote documents with the URL
of the document

It does nothing if there's no fake file (that is, if we're not executing the document
associated with a remote file).

*Note:* for efficency reasons the replacement is performed in place, so create a
duplicate of the array before calling this method if you need to preserve it.

@param [Array<String>] the lines of text to perform the replacement into
@return [Array<String>] the lines with all occurrences of the fake file path replaced
with the url of the remote file. If no fake file is in use, _lines_ will be returned
unchanged
=end
      def replace_fake_file lines
        if @fake_file
          lines.map!{|l| l.gsub(@fake_file.file.path, @fake_file.url.pretty_url)}
        end
        lines
      end
      
=begin rdoc
Override of {ExternalProgramPlugin#process_standard_output}

It processes the lines using {#replace_fake_file} before passing it to the base
class's method
@param (see Ruber::ExternalProgramPlugin#process_standard_output)
@return (see Ruber::ExternalProgramPlugin#process_standard_output)
=end
      def process_standard_output lines
        super replace_fake_file(lines)
      end

=begin rdoc
Override of {ExternalProgramPlugin#process_standard_error}

It processes the lines using {#replace_fake_file} before passing it to the base
class's method
@param (see Ruber::ExternalProgramPlugin#process_standard_error)
@return (see Ruber::ExternalProgramPlugin#process_standard_error)
=end
      def process_standard_error lines
        super replace_fake_file(lines)
      end
      

    end
    
=begin rdoc
The class used by the Files runner tool widget

It's a normal {Ruber::FilteredOutputWidget} which overrides the {#find_filename_in_index}
method
=end
    class OutputWidget < FilteredOutputWidget
      
      private

=begin rdoc
Override of {OutputWidget#find_filename_in_index}
      
It differs from the
original implementation in that it attempts to work around the situation where
there's a syntax error in a file loaded using require. In this case, the error message takes the form:

  @requiring_file:line: in `require': file_with_syntax_error:line: syntax error...@
  
Most often, the user will want to open the file with the syntax error, not the
one requiring it, so this method attempts to remove the first part of the string
before passing it to *super*. It also works with rubygems in ruby 1.8, when
require is replaced by @gem_original_require@
@param [Qt::ModelIndex] idx the index to search for a filename
@return [<String,Integer>,String,nil] see {Ruber::OutputWidget#find_filename_in_index}
=end
      def find_filename_in_index idx
        str = idx.data.to_string
        if idx.row == 0 then super
        else 
          super str.sub( %r<^[^\s:]+:\d+:in\s+`(?:gem_original_require|require):\s+'>, '')
        end
      end
      
    end
    
=begin rdoc
Project configuration widget for the Files runner plugin
=end
    class ProjectWidget < Ruber::ProjectConfigWidget
      
=begin rdoc
@param [Ruber::AbstractProject] prj the project the configuration widget refers to
=end
      def initialize prj
        super
        @ui = Ui::FilesRunnerProjectWidget.new
        @ui.setupUi self
        hide_global_only_widgets if prj.scope == :document
      end
      
=begin rdoc
Sets the contents of the program options widget
@param [<String>] value a list of the command line options to be passed to the
script to execute
=end
      def program_options= value
        @ui._ruby__options.text = value.join " "
      end
      
=begin rdoc
Splits the content of the program options widget into an array

@return [<String>] an array containing the options to pass to the ruby script to
execute. Quotes are preserved.
=end
      def program_options
        Shellwords.split_with_quotes @ui._ruby__options.text
      end
      
      private
      
=begin rdoc
Hides the widgets corresponding to global options

This method is called by the constructor when the widget is associated with a
project with document scope.
@return [nil]
=end
      def hide_global_only_widgets
        @ui.main_program_label.hide
        @ui._ruby__main_program.hide
        @ui.working_dir_label.hide
        @ui._ruby__working_dir.hide
      end
      
    end
		
    class ConfigWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::RubyDevelopmentConfigWidget.new
        @ui.setupUi self
      end
      
    end
    
  end  
  
end