=begin 
    Copyright (C) 2010,2011 by Stefano Crocco   
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

require 'ruby_runner/ruby_runner'
require_relative 'ui/rspec_project_widget'
require_relative 'ui/config_widget'

require 'strscan'
require 'yaml'
require 'open3'

module Ruber
  
=begin rdoc
Frontend plugin to RSpec

This plugin provides commands to run examples for all the files in the current
project or on the current document (only if it's part of a project). In the latter
case, the command can be issued while viewing either the spec or the code file.
Besides, an action to switch from spec file to code file and one to do the reverse
switch are provided.

The pattern to extract the name of the spec file from that of the code file can
be customized in the project configuration dialog (by default the plugin assumes
that the spec file for for a file called @code.rb@ is @code_spec.rb@). The directory
where the spec files are can also be customized (by default it's the @spec@ subdirectory
under the project directory)

@api feature rspec
@plugin
@config_option rspec ruby_options [<String>] the options to pass to ruby when executing
the spec command
@project_option rspec executable [String] the path to the spec executable
@project_option rspec options [<String>] the options to pass to the _spec_ command
@project_option rspec spec_directory [String] the directory where the example files
are
@project_option rspec spec_pattern [<String>] patterns to generate the spec files
from the code files. The name of the code file is obtained by using the special
sequence @%f@ in the strings. Only the file name of the code file is taken into
account (not the directory). All the spec file names are relative to the directory
specified in the @rspec/spec_directory@ option. If more than one entry is specified,
all of them will be tried
=end
  module RSpec
    
=begin rdoc
Plugin object for the RSpec plugin
@api_method #specs_for_file
@api_method #file_for_spec
@api_method #run_rspec
@api_method #run_rspec_for
=end
    class Plugin < RubyRunner::RubyRunnerPlugin
      
=begin rdoc
The starting delimiter of the data written by the formatter
=end
      STARTING_DELIMITER = /^####%%%%####KRUBY_BEGIN$/
      
=begin rdoc
The ending delimiter of the data written by the formatter
=end
      ENDING_DELIMITER = /^####%%%%####KRUBY_END$/
      
=begin rdoc
Symbolic values associated with the @rspec/switch_behaviour@ settings 
=end
      SWITCH_BEHAVIOUR = [:new_tab, :horizontal, :vertical]
      
=begin rdoc
Finds the rspec program to use by default

It looks for an executable called @rspec@ or @spec@ (this is to support both RSpec
1 and 2) in @PATH@ (using the @which@ command).
@return [String] a string with the path to the rspec program or an empty string
if no rspec program was found
=end
      def self.find_default_executable
        path = Open3.popen3('which rspec'){|stdin, stdout, stderr| stdout.read}.strip
        if path.empty?
          path = Open3.popen3('which spec'){|stdin, stdout, stderr| stdout.read}.strip
        end
        path
      end

      
      slots :run_all, :run_current, :run_current_line
      
=begin rdoc
@param [Ruber::PluginSpecification] the plugin specification object associated with
the plugin
=end
      def initialize psf
        super psf, :rspec, {:scope => [:global]}, nil, false
        Ruber[:autosave].register_plugin self, true
        @formatter = File.join File.dirname(__FILE__), 'ruber_rspec_formatter'
        self.connect(SIGNAL('process_finished(int, QString)')){Ruber[:main_window].set_state 'rspec_running', false}
        Ruber[:main_window].set_state 'rspec_running', false
        
        switch_prc = Proc.new{|states| states['active_project_exists'] and states['current_document']}
        register_action_handler 'rspec-switch', &switch_prc
        register_action_handler 'rspec-run_all' do |states|
          states['active_project_exists'] and !states['rspec_running']
        end
        current_prc = Proc.new do |states|
          states['active_project_exists'] and states['current_document'] and
              !states['rspec_running']
        end
        register_action_handler 'rspec-run_current', &current_prc
        register_action_handler 'rspec-run_current_line', &current_prc
        connect Ruber[:main_window], SIGNAL('current_document_changed(QObject*)'), self, SLOT('change_switch_name(QObject*)')
        Ruber[:components].connect(SIGNAL('feature_loaded(QString, QObject*)')) do |f, o|
          o.register_plugin self, true if f == 'autosave'
        end
        @output_widget = @widget
      end

=begin rdoc
Whether a file is a spec file or a code file for a given project

It uses the @rspec/spec_directory@ and @rspec/spec_pattern@ options from the project
to find out whether the file is a spec file or not.

@param [String] file the file to test
@param [Project,nil] prj the project _file_ could be a spec for. If *nil*, the
  current project, if any, will be used
@return [Boolean,nil] wheter or not _file_ is a spec file for the given project
  or *nil* if no project was specified and there's no open project
=end
      def spec_file? file, prj = Ruber[:projects].current
        return nil unless prj
        dir = prj[:rspec, :spec_directory, :absolute]
        return false unless file.start_with? dir
        File.fnmatch File.join(dir, prj[:rspec, :spec_files]), file
      end
      
=begin rdoc
Runs rspec for the given files

The output of spec is displayed in the associated output widget.

Files are autosaved before running rspec.

If spec is already running, or if autosaving fails, noting is done.

@param [Array<String>] files the spec files to run. Nonexisting files are ignored
@param [Hash] opts options to fine-tune the behaviour of spec
@param [Hash] autosave_opts options telling whether and how autosave files
@param [Proc] blk a block to pass to autosave. If not given, no block will be
passed to autosave

@option opts [String] :ruby (Ruber[:config][:ruby, :ruby]) the ruby interpreter
to use
@option opts [Array<String>] :ruby_options (Ruber[:config][:ruby, :ruby_options])
the options to pass to the ruby interpreter
@option opts [String] :spec ('spec') the path of the spec command to use
@option opts [Array<String>] :spec_options ([]) the options to pass to the spec
program
@option opts [String] :dir ('.') the directory to run spec from
@option opts [Boolean] :full_backtraces (nil) whether or not to pass the @-b@ option
to the spec program

@option autosave_opts [Array<Document>,Symbol] :files (nil) the documents to autosave.
It has the same meaning as second parameter to {Autosave::AutosavePlugin#autosave}.
If it's *nil*, autosave won't be used
@option autosave_opts [Symbol, Plugin] :plugin (Ruber[:rspec]) the value to pass
as first argument to {Autosave::AutosavePlugin#autosave}
@option autosave_opts [Boolean] :stop_on_failure (nil) as in {Autosave::AutosavePlugin#autosave}
@option autosave_opts [Symbol] :on_failure (nil) as in {Autosave::AutosavePlugin#autosave}
@option autosave_opts [String] :message (nil) as in {Autosave::AutosavePlugin#autosave}

@return [Boolean] *true* if the process is started and *false* otherwise
(including the case when the process was already running or autosaving failed)
=end
      def run_rspec files, opts, autosave_opts = {}, &blk
        default_opts = {
          :ruby => Ruber[:config][:ruby, :ruby],
          :ruby_options => Ruber[:config][:ruby, :ruby_options],
          :spec => 'spec',
          :spec_options => [],
          :dir => '.'
        }
        opts = default_opts.merge opts
        return false if @process.state != Qt::Process::NotRunning
        @widget.clear_output
        files = files.select{|f| File.exist? f}
        if autosave_opts[:files]
          plug = autosave_opts[:plugin] || self
          what = autosave_opts[:files]
          return false unless Ruber[:autosave].autosave plug, 
              what, autosave_opts, &blk
        end
        full_backtraces = opts[:full_backtraces] ? %w[-b] : []
        args = [opts[:spec]] + %W[-r #{@formatter} -f Ruber::RSpec::Formatter] + 
            opts[:spec_options] + full_backtraces + files
        @widget.working_directory = opts[:dir]
        @display_standard_error = opts[:stderr]
        Ruber[:main_window].activate_tool(@widget)
        Ruber[:main_window].change_state 'rspec_running', true
        title = ([opts[:spec].split('/')[-1]] + opts[:spec_options]+ full_backtraces + files).join ' '
        run_process opts[:ruby], opts[:dir], opts[:ruby_options] + args, title
        @widget.model.item(0,0).tool_tip = ([opts[:ruby]] + opts[:ruby_options] + args).join " "
        true
      end
      
      private

=begin rdoc
Override of {PluginLike#delayed_initialize}

It sets the text of the @Switch@ action depending on whether the current document
(if any) is or not a spec file.

This can't be done from the {#initialize} method because project options haven't
already been added when that method is called.

@return [nil]
=end
      def delayed_initialize
        doc = Ruber[:main_window].current_document
        change_switch_name doc if doc
        nil
      end
      

=begin rdoc
Override of {ExternalProgramPlugin#process_standard_output}

It parses the output from the _spec_ program (generated with the
{Ruber::RSpec::Formatter Ruber rspec formatter}) and displays the data it contains
appropriately.
@param [Array] lines the output, split in lines
@return [nil]
=end
      def process_standard_output lines
        items = parse_spec_output lines.join "\n"
        items.each do |it|
          if it.is_a? String then @widget.model.insert_lines it, :output, nil
          else @widget.display_example it
          end
        end
        nil
      end
      
=begin rdoc
Override of {ExternalProgramPlugin#process_standard_error}
@param [Array] lines the standard error output, split in lines
@return [nil]
=end
      def process_standard_error lines
        @widget.model.insert_lines lines, :output1, nil
        nil
      end

=begin rdoc
Parses the output of the _spec_ command

This method only works if the {Ruber::RSpec::Formatter Ruber rspec formatter}
is used.

The output is split according in regions between {STARTING_DELIMITER} and
{ENDING_DELIMITER}. All text inside these regions is considered the YAML dump of
a hash and converted back to a hash. All text which is not between a pair of
delimiters, as well as the text which can't be converted by YAML is left as is
@param [String] str the output to parse
@return [<Hash, String>] the result of the parse. The text which was successfully
parsed by YAML is stored as a hash, while the rest is stored as strings. Order is
preserved.
=end
      def parse_spec_output str
        sc = StringScanner.new str
        res = []
        until sc.eos?
          match = sc.scan_until(STARTING_DELIMITER) || sc.rest
          found = match.sub!(STARTING_DELIMITER, '')
          res << match
          if found
            yaml = sc.scan_until(ENDING_DELIMITER) || sc.rest
            yaml.sub! ENDING_DELIMITER, ''
            res << (YAML.load(yaml) rescue yaml)
          else sc.terminate
          end
        end
        res
      end
      
=begin rdoc
Runs all the specs for the project.
@return [nil]
=end
      def run_all
        prj = Ruber[:projects].current_project
        unless prj
          KDE::MessageBox.error nil, "You must have an open project to choose this entry.\nYOU SHOULD NEVER SEE THIS MESSAGE"
          return
        end
        opts = options prj
        opts[:files] = Dir.glob File.join(opts[:specs_dir], opts[:filter])
        run_rspec_for prj, opts, :files => :project_files, :on_failure => :ask, :message => 'Do you want to run the tests all the same?'
        nil
      end
      
=begin rdoc
Runs the specs corresponding to the current file

If the current file is a code file, the corresponding spec file will be run. If
it is a spec file, the file itself will be run.

To decide whether the current file is a spec or a code file, this method uses
the patters stored in the @rspec/spec_pattern@ project setting to build the names
of the spec files associated with the current file, which is assumed to be a code
file. If none of these files exist, then the current file is treated as a spec file,
otherwise one of the spec files thus generated is run.

*Note:* the way this method works implies that if it is called on a code
file which doesn't have an associated spec file, rspec will be run on that file,
which, most likely, will cause it to fail.

@return [Boolean] *true* if the spec program is started and *false* otherwise
(including the case when the process was already running or autosaving failed)
=end
      def run_current what = :all
        prj = Ruber[:projects].current_project
        unless prj
          KDE::MessageBox.error nil, "You must have an open project to choose this entry.\nYOU SHOULD NEVER SEE THIS MESSAGE"
          return
        end
        opts = options prj
        view = Ruber[:main_window].active_editor
        doc = view.document
        unless doc.url.local_file?
          KDE::MessageBox.sorry nil, 'You can\'t run rspec for remote files'
          return
        end
        unless doc
          KDE::MessageBox.error nil, "You must have an open editor to choose this entry.\nYOU SHOULD NEVER SEE THIS MESSAGE"
          return
        end
        files = specs_for_file opts, doc.path
        files.reject!{|f| !File.exist? f}
        opts[:files] = files.empty? ? [doc.path] : files
        if what == :current_line
          line = view.cursor_position.line + 1
          opts[:spec_options] += ["-l", line.to_s]
        end
        run_rspec_for prj, opts, :files => :documents_with_file, :on_failure => :ask,
            :message => 'Do you want to run the tests all the same?'
      end
      
=begin rdoc
Runs the example(s) in the current line

Similar to {#run_current}, but tells spec to run only the example or example
group corresponding to the line where the cursor is (using spec's -l option).
Besides, unlike {#run_current}, this method can only be called when the
current file is the example file, not the source.

@return [Boolean] *true* if the spec program is started and *false* otherwise
(including the case when the process was already running or autosaving failed)
=end
      def run_current_line
        run_current :current_line
      end
      
=begin rdoc
Runs the spec command for the given object

It works like {RubyRunner::RubyRunnerPluginInternal#ruby_command_for RubyRunner::RubyRunnerPlugin#ruby_command_for}
but already takes care of the user's settings regarding the path of the spec program.

@param [AbstractProject, Document, String, nil] origin see the _target_ argument
of {RubyRunner::RubyRunnerPluginInternal#option_for RubyRunner::RubyRunnerPlugin#option_for}
@param [Hash] opts the options to pass to the _spec_ program. It has the same
meaning as the _opts_ argument to {#run_rspec}, but can also contain an additional
entry (see below)
@param [Hash] autosave_opts see the _autosave_opts_ argument of {#run_rspec}
@param [Proc] blk see the _blk_ argument of {#run_rspec}

@option opts [Array<String>] :files the files to pass to the spec program

@return [Boolean] *true* if the process is started and *false* otherwise
(including the case when the process was already running or autosaving failed)
=end
      def run_rspec_for origin, opts, autosave_opts = {}, &blk
        process.kill
        ruby, *cmd = ruby_command_for origin, opts[:dir]
        opts = {:ruby => ruby, :ruby_options => cmd}.merge opts
        run_rspec opts[:files], opts, autosave_opts, &blk
      end

=begin rdoc
Collects all the options relative to this plugin from a project

*Note:* *never* use destructive methods on the values contained in this hash. Doing so will
change the options stored in the project, which most likely isn't what you want.
If you need to change the options, make duplicates of the values

@param [AbstractProject] prj the project to retrieve options from
@return [Hash] an hash containing the options stored in the project. The correspondence
between options and entries in this hash is the following:
* @:rspec/executable@ &rarr; @:spec@
* @:rspec/options@ &rarr; @:spec_options@
* @:rspec/spec_directory@ &rarr; @:specs_dir@
* @:rspec/spec_files@ &rarr; @:filter@
* @:rspec/spec_pattern@ &rarr; @:pattern@
* @:rspec/full_backtraces@ &rarr; @:full_backtraces@

Besides, the above entries, the hash also contains a @:dir@ entry which contains
the project directory.
=end
      def options prj
        res = {}
        res[:spec] = prj[:rspec, :executable]
        res[:spec_options] = prj[:rspec, :options]
        res[:specs_dir] = prj[:rspec, :spec_directory, :absolute]
        res[:filter] = prj[:rspec, :spec_files]
        res[:pattern] = prj[:rspec, :spec_pattern]
        res[:dir] = prj.project_directory
        res[:full_backtraces] = prj[:rspec, :full_backtraces]
        res
      end
      
=begin rdoc
Slot associated with the @Switch@ action

Displays the spec or code file associated with the current document, according
to whether the current document is a code or spec file respectively.

It does nothing if the file corresponding to the current document isn't found
@note this method assumes that both the current project and a current document
  exist
@return [EditorView,nil] an editor associated with the spec or code file associated
  with the current document or *nil* if no such file is found
=end
      def switch
        file = Ruber[:main_window].current_document.path
        prj = Ruber[:projects].current_project
        if spec_file? file, prj then switch_to = file_for_spec prj, file
        else switch_to = specs_for_file(options(prj), file)[0]
        end
        if switch_to and File.exist? switch_to
          behaviour = Ruber[:config][:rspec, :switch_behaviour]
          if behaviour != :new_tab
            hints = {:strategy => :current_tab, :existing => :current_tab, :split => SWITCH_BEHAVIOUR[behaviour], :new => :current_tab}
          else hints = {}
          end
          Ruber[:main_window].display_document switch_to, hints
        end
      end
      slots :switch

=begin rdoc
Determines all possible specs files associated with a code file

The names of the possible spec files are obtained replacing the @%f@ tag in each
entry of the @rspec/pattern@ setting with the name of the file (without checking
whether the files actually exist).

@param [String] file the name of the code file
@return [<String>] the names of the possible spec file associated with _file_
=end
      def specs_for_file opts, file
        file = File.basename file, '.rb'
        res = opts[:pattern].map{|i| File.join opts[:specs_dir], i.gsub('%f', file)}
        res
      end

=begin rdoc
The name of the code file associated with a given spec file

To find out which code file is associated with the given spec file, this method
takes all the project files and constructs the file names of all the specs associated
to them according to the @rspec/spec_pattern@ project option. As soon as one of
the generated file names matches the given spec file, the generating file is returned.

@param [Ruber::AbstractProject] prj the project containing the settings to use
@param [String] file the name of the spec file to find the code file for
@return [String] the absolute path of a file _file_ is a spec of, according
to the settings contained in _prj_.
=end
      def file_for_spec prj, file
        pattern = prj[:spec_pattern]
        opts = options prj
        prj.project_files.abs.find{|f| specs_for_file( opts, f).include? file}
      end
      
=begin rdoc
Override of {ExternalProgramPlugin#display_exit_message}

It works as the base class's method except when the program exits successfully,
in which case it does nothing.

See {ExternalProgramPlugin#display_exit_message} for the meaning of the parameters

@return nil
=end
      def display_exit_message code, reason
        super unless reason.empty?
      end
      
=begin rdoc
Changes the text of the @Switch to spec@ action depending on whether the given
document is a spec or code file

This method is usually called in response to the {MainWindow#current_document_changed}
signal.

@param [Document,nil] doc the document according to with to change the text of
  the action
@return [nil]
=end
      def change_switch_name doc
        return unless doc
        if spec_file? doc.path then text = 'Switch to &Code'
        else text = 'Switch to &Spec'
        end
        action_collection.action('rspec-switch').text = i18n(text)
        nil
      end
      slots 'change_switch_name(QObject*)'
      
    end
    
=begin rdoc
Filter model used by the RSpec output widget

It allows to choose whether to accept items corresponding to output to standard error or to reject
it. To find out if a given item corresponds to the output of standard error or 
standard output, this model uses the data contained in a custom role in the output.
The index of this role is {RSpec::OutputWidget::OutputTypeRole}.
=end
    class FilterModel < FilteredOutputWidget::FilterModel
      
      slots 'toggle_display_stderr(bool)'
      
=begin rdoc
Whether output from standard error should be displayed or not
@return [Boolean]
=end
      attr_reader :display_stderr
      
=begin rdoc
Create a new instance

The new instance is set not to show the output from standard error

@param [Qt::Object, nil] parent the parent object
=end
      def initialize parent = nil
        super
        @display_stderr = false
      end
      
=begin rdoc
Sets whether to display or ignore items corresponding to output to standard error

If this choice has changed, the model is invalidated.

@param [Boolean] val whether to display or ignore the output to standard error
@return [Boolean] _val_
=end
      def display_stderr= val
        old, @display_stderr = @display_stderr, val
        invalidate if old != @display_stderr
        @display_standard_error
      end
      alias_method :toggle_display_stderr, :display_stderr=
      
=begin rdoc
Override of {FilteredOutputWidget::FilterModel#filterAcceptsRow}

According to the value of {#display_stderr}, it can filter out items corresponding
to standard error. In all other respects, it behaves as the base class method.
@param [Integer] r the row number
@param [Qt::ModelIndex] parent the parent index
@return [Boolean] *true* if the row should be displayed and *false* otherwise
=end
      def filterAcceptsRow r, parent
        if !@display_stderr
          idx = source_model.index(r,0,parent)
          return false if idx.data(OutputWidget::OutputTypeRole).to_string == 'output1'
        end
        super
      end
      
    end
    
=begin rdoc
Tool widget used by the rspec plugin.

It displays the output from the spec program in a multi column tree. The name of
failing or pending examples are displayed in a full line; all other information,
such as the location of the example, the error message and so on are displayed
in child items.

While the examples are being run, a progress bar is shown.
=end
    class ToolWidget < FilteredOutputWidget
      
      slots :spec_started, 'spec_finished(int, QString)'
      
=begin rdoc
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize parent = nil
        super parent, :view => :tree, :filter => FilterModel.new
        @ignore_word_wrap_option = true
        view.text_elide_mode = Qt::ElideNone
        model.append_column [] if model.column_count < 2
        @progress_bar = Qt::ProgressBar.new(self){|w| w.hide}
        layout.add_widget @progress_bar, 2,0
        view.header_hidden = true
        view.header.resize_mode = Qt::HeaderView::ResizeToContents
        connect Ruber[:rspec], SIGNAL(:process_started), self, SLOT(:spec_started)
        connect Ruber[:rspec], SIGNAL('process_finished(int, QString)'), self, SLOT('spec_finished(int, QString)')
        filter.connect(SIGNAL('rowsInserted(QModelIndex, int, int)')) do |par, st, en|
          if !par.valid?
            st.upto(en) do |i|
              view.set_first_column_spanned i, par, true
            end
          end
        end
        #without this, the horizontal scrollbars won't be shown
        view.connect(SIGNAL('expanded(QModelIndex)')) do |_|
          view.resize_column_to_contents 1
        end
        view.connect(SIGNAL('collapsed(QModelIndex)')) do |_|
          view.resize_column_to_contents 1
        end
        setup_actions
      end
      
=begin rdoc
Displays the data relative to an example in the widget

Actually, this method simply passes its argument to a more specific method, depending
on the data it contains.

@param [Hash] data a hash containing the data describing the results of running
the example. This hash must contain the @:type@ key, which tells which kind of
event the hash describes. The other entries change depending on the method which
will be called, which is determined according to the @:type@ entry:
 * @:success@: {#display_successful_example}
 * @:failure@: {#display_failed_example}
 * @:pending@: {#display_pending_example}
 * @:new_example@: {#change_current_example}
 * @:start@: {#set_example_count}
 * @:summary@: {#display_summary}
If the @:type@ entry doesn't have one of the previous values, the hash will be
converted to a string and displayed in the widget
=end
      def display_example data
        unless data.is_a?(Hash)
          model.insert_lines data.to_s, :output, nil
          return
        end
        case data[:type]
        when :success then display_successful_example data
        when :failure then display_failed_example data
        when :pending then display_pending_example data
        when :new_example then change_current_example data
        when :start then set_example_count data
        when :summary then display_summary data
        else model.insert_lines data.to_s, :output, nil
        end
      end
      
=begin rdoc
Changes the current example

Currently, this only affects the tool tip displayed by the progress bar.

@param [Hash] data the data to use. It must contain the @:description@ entry,
which contains the text of the tool tip to use.
@return [nil]
=end
      def change_current_example data
        @progress_bar.tool_tip = data[:description]
        nil
      end
      
=begin rdoc
Sets the number of examples found by the spec program.

This is used to set the maximum value of the progress bar.

@param [Hash] data the data to use. It must contain the @:count@ entry,
which contains the number of examples
@return [nil]
=end
      def set_example_count data
        @progress_bar.maximum = data[:count]
        nil
      end
      
      
=begin rdoc
Updates the progress bar by incrementing its value by one

@param [Hash] data the data to use. Currently it's unused
@return [nil]
=end
      def display_successful_example data
        @progress_bar.value += 1
        nil
      end
      
=begin rdoc
Displays information about a failed example in the tool widget.

@param [Hash] data the data about the example.

@option data [String] :location the line number where the error occurred
@option data [String] :description the name of the failed example
@option data [String] :message the explaination of why the example failed
@option data [String] :exception the content of the exception
@option data [String] :backtrace the backtrace of the exception (a single new-line separated string)
@return [nil]
=end
      def display_failed_example data
        @progress_bar.value += 1
        top = model.insert("[FAILURE] #{data[:description]}", :error, nil).first
        model.insert ['From:', data[:location]], :message, nil, :parent => top
        ex_label = model.insert('Exception:', :message, nil, :parent => top).first
        exception_body = "#{data[:message]} (#{data[:exception]})".split_lines.delete_if{|l| l.strip.empty?}
        #exception_body may contain more than one line and some of them may be empty
        model.set exception_body.shift, :message, ex_label.row, :col => 1, :parent => top
        exception_body.each do |l|
          unless l.strip.empty?
            model.set l, :message, top.row_count, :col => 1, :parent => top
          end
        end
        backtrace = data[:backtrace].split_lines
        back_label, back = model.insert(['Backtrace:', backtrace.shift], :message, nil, :parent => top)
        backtrace.each do |l|
          model.insert [nil, l], :message, nil, :parent => back_label
        end
        top_index = filter.map_from_source(top.index)
        view.collapse top_index
        view.set_first_column_spanned top_index.row, Qt::ModelIndex.new, true
        view.expand filter.map_from_source(back_label.index)
        nil
      end
      
=begin rdoc
Displays information about a pending example in the tool widget

@param [Hash] data
@option data [String] :location the line number where the error occurred
@option data [String] :description the name of the failed example
@option data [String] :message the explaination of why the example failed
@return [nil]
=end
      def display_pending_example data
        @progress_bar.value += 1
        top = model.insert("[PENDING] #{data[:description]}", :warning, nil)[0]
        model.insert ['From:', data[:location]], :message, nil, :parent => top
        model.insert ['Message: ', "#{data[:message]} (#{data[:exception]})"], :message, nil, :parent => top
        nil
      end
      
=begin rdoc
Displays a summary of the spec run in the tool widget

The summary is a single title line which contains the number or successful, pending
and failed example.

@param [Hash] data
@option data [Integer] :total the number of run examples
@option data [Integer] :passed the number of passed examples
@option data [Integer] :failed the number of failed examples
@option data [Integer] :pending the number of pending examples
@return [nil]
=end
      def display_summary data
        @progress_bar.hide
        if data[:passed] == data[:total]
          self.title = "[SUMMARY] All #{data[:total]} examples passed"
          set_output_type model.index(0,0), :message_good
        else
          text = "[SUMMARY]      Examples: #{data[:total]}"
          text << "      Failed: #{data[:failure]}" if data[:failure] > 0
          text << "      Pending: #{data[:pending]}" if data[:pending] > 0
          text << "      Passed: #{data[:passed]}"
          self.title = text
          type = data[:failure] > 0 ? :message_bad : :message
          set_output_type model.index(0,0), type
        end
        nil
      end
      
=begin rdoc
Override of {OutputWidget#title=}

It's needed to have the title element span all columns

@param [String] val the new title
=end
      def title= val
        super
        model.item(0,0).tool_tip = val
        view.set_first_column_spanned 0, Qt::ModelIndex.new, true
      end
      
      private
      
=begin rdoc
Resets the tool widget and sets the cursor to busy
@return [nil]
=end
      def spec_started
        @progress_bar.maximum = 0
        @progress_bar.value = 0
        @progress_bar.show
        @progress_bar.tool_tip = ''
        actions['show_stderr'].checked = false
        self.cursor = Qt::Cursor.new(Qt::BusyCursor)
        nil
      end
      
=begin rdoc
Does the necessary cleanup for when spec finishes running

It hides the progress widget and restores the default cursor.

@param [Integer] code the exit code
@param [String] reason why the program exited
@return [nil]
=end
      def spec_finished code, reason
        @progress_bar.hide
        @progress_bar.value = 0
        @progress_bar.maximum = 100
        self.set_focus
        unset_cursor
        unless reason == 'killed'
          non_stderr_types = %w[message message_good message_bad warning error]
          only_stderr = !model.item(0,0).text.match(/^\[SUMMARY\]/)
          if only_stderr
            1.upto(model.row_count - 1) do |i|
              if non_stderr_types.include? model.item(i,0).data(OutputWidget::OutputTypeRole).to_string
                only_stderr = false
                break
              end
            end
          end
          if only_stderr
            actions['show_stderr'].checked = true
            model.insert "spec wasn't able to run the examples", :message_bad, nil
          end
        end
        nil
      end
      
=begin rdoc
Creates the additional actions.

It adds a single action, which allows the user to chose whether messages from
standard error should be displayed or not.

@return [nil]
=end
      def setup_actions
        action_list << nil << 'show_stderr'
        a = KDE::ToggleAction.new 'S&how Standard Error', self
        actions['show_stderr'] = a
        a.checked = false
        connect a, SIGNAL('toggled(bool)'), filter, SLOT('toggle_display_stderr(bool)')
      end
      
=begin rdoc
Override of {OutputWidget#find_filename_in_index}

It works as the base class method, but, if it doesn't find a result in _idx_,
it looks for it in the parent indexes

@param [Qt::ModelIndex] idx the index where to look for a file name
@return [Array<String,Integer>,String,nil] see {OutputWidget#find_filename_in_index}
=end
      def find_filename_in_index idx
        res = super
        unless res
          idx = idx.parent while idx.parent.valid?
          idx = idx.child(0,1)
          res = super idx if idx.valid?
        end
        res
      end
      
=begin rdoc
Override of {OutputWidget#text_for_clipboard}

@param [<Qt::ModelIndex>] idxs the selected indexes
@return [QString] the text to copy to the clipboard
=end
      def text_for_clipboard idxs
        order = {}
        idxs.each do |i|
          val = []
          parent = i
          while parent.parent.valid?
            parent = parent.parent
            val.unshift parent.row
          end
          val << [i.row, i.column]
          order[val] = i
        end
        order = order.sort do |a, b|
          a, b = a[0], b[0]
          res = a[0..-2] <=>  b[0..-2]
          if res == 0 then a[-1] <=> b[-1]
          else res
          end
        end
        prev = order.shift[1]
        text = prev.data.valid? ? prev.data.to_string : ''
        order.each do |_, v|
          text << ( (prev.parent == v.parent and prev.row == v.row) ? "\t" : "\n") 
          text << (v.data.valid? ? v.data.to_string : '')
          prev = v
        end
        text
      end

    end
    
=begin rdoc
Project widget for the RSpec frontend plugin
=end
    class ProjectWidget < ProjectConfigWidget

=begin rdoc
@param [Qt::Widget,nil] prj the parent widget
=end
      def initialize prj
        super
        @ui = Ui::RSpecProjectWidget.new
        @ui.setupUi self
      end
      
      private
      
=begin rdoc
Sets the text of the pattern widget
@param [Array<String>] the pattern to use. They'll be joined with commas to create
the text to put in the widget
=end
      def pattern= value
        value.join ', '
      end
      
=begin rdoc
Parses the content of the pattern widget
@return [Array<String>] an array containing the patterns
=end
      def pattern
        @ui._rspec__spec_pattern.text.split(/;\s*/)
      end
      
=begin rdoc
Changes the text of the "RSpec options" widget
      
@param [Array<String>] value the options to pass to spec. They'll be joined with
spaces
=end
      def spec_options= value
        @ui._rspec__options.text = value.join ' '
      end

=begin rdoc
Parses the text of the "RSpec options" widget

@return [Array<String>] an array with the options to pass to spec (options with
quotes around them keep them, as described in {Shellwords.split_with_quotes})
=end
      def spec_options
        Shellwords.split_with_quotes @ui._rspec__options.text
      end
      
    end
    
    class ConfigWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::RSpecConfigWidget.new
        @ui.setup_ui self
      end
      
    end
    
  end
  
end