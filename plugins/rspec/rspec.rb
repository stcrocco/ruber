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
      
      signals :settings_changed
      
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
Whether or not a file is a spec file for a given project

It uses the @rspec/spec_directory@ and @rspec/spec_pattern@ options from the project
to find out whether the file is a spec file or not.

@param [String] file the file to test
@param [Project,nil] prj the project _file_ could be a spec for. If *nil*, the
  current project, if any, will be used
@return [Boolean,nil] wheter or not _file_ is a spec file for the given project
  or *nil* if no project was specified and there's no open project
=end
      def spec_file? file, prj = Ruber[:world].active_project
        return nil unless prj
        prj.extension(:rspec).spec_file? file
      end

=begin rdoc
Whether or not file is a code file for a given project

It uses the @rspec/spec_directory@ and @rspec/spec_pattern@ options from the project
to find out whether the file is a spec file or not.

@param [String] file the file to test
@param [Project,nil] prj the project _file_ could be a spec for. If *nil*, the
  current project, if any, will be used
@return [Boolean,nil] wheter or not _file_ is a spec file for the given project
  or *nil* if no project was specified and there's no open project
=end
      def code_file? file, prj = Ruber[:world].active_project
        return nil unless prj
        prj.extension(:rspec).code_file? file
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
      
      def load_settings
        super
        emit settings_changed
      end
      
      def spec_for_pattern pattern, file
        spec = pattern[:spec].gsub(/%f/, File.basename(file, '.rb'))
        dir = File.dirname(file)
        dir_parts = dir.split '/'
        spec.gsub! %r{%d\d+} do |str|
          dir_parts[str[2..-1].to_i-1] || ''
        end
        spec.gsub! %r{%d}, dir
        spec
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
        prj = Ruber[:world].active_project
        unless prj
          KDE::MessageBox.error nil, "You must have an open project to choose this entry.\nYOU SHOULD NEVER SEE THIS MESSAGE"
          return
        end
        opts = options prj
        opts[:files] = Dir.glob File.join(opts[:specs_dir], '**', opts[:filter])
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
      def run_current_document
        doc = Ruber[:world].active_document
        unless doc
          raise "It shouldn't be possible to call #{self.class}#run_current_document when there's no active document"
        end
        prj = Ruber[:world].active_project
        unless doc
          raise "It shouldn't be possible to call #{self.class}#run_current_document when there's no active project"
        end
        opts = options prj
        ext = prj.extension(:rspec)
        if doc.path.empty?
          KDE::MessageBox.sorry nil, KDE.i18n("You must save the document to a file before running rspec on it")
          return
        elsif ext.spec_file? doc.path
          opts[:files] = [doc.path]
        elsif ext.code_file?(doc.path) 
          files = ext.specs_for_code doc.path
        end
        run_rspec_for prj, opts, :files => :documents_with_file, :on_failure => :ask,
            :message => 'Do you want to run the tests all the same?'
      end
      slots :run_current_document
      
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
        doc = Ruber[:world].active_document
        unless doc
          raise "It shouldn't be possible to call #{self.class}#run_current_document when there's no active document"
        end
        prj = Ruber[:world].active_project
        unless doc
          raise "It shouldn't be possible to call #{self.class}#run_current_document when there's no active project"
        end
        opts = options prj
        ext = prj.extension(:rspec)
        if doc.path.empty?
          KDE::MessageBox.sorry nil, KDE.i18n("You must save the document to a file before running rspec on it")
          return
        elsif ext.spec_file? doc.path
          view = Ruber[:main_window].active_editor
        elsif ext.code_file?(doc.path) 
          specs = ext.specs_for_code doc.path
          view = Ruber[:world].active_environment.views.find do |v| 
            specs.include? v.document.path
          end
          unless view
            KDE::MessageBox.sorry nil, KDE.i18n('You don\'t have any spec file for %s opened. Without it it\'s impossible to find out what the current line is', doc.path)
            return
          end
          doc = view.document
        end
        opts[:files] = [view.document.path]
        line = view.cursor_position.line + 1
        opts[:spec_options] += ["-l", line.to_s]
        run_rspec_for prj, opts, :files => :documents_with_file, :on_failure => :ask,
            :message => 'Do you want to run the tests all the same?'
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
        prj = Ruber[:world].active_project
        ext = prj.extension(:rspec)
        if ext.spec_file? file then ;switch_to = ext.code_for_spec file
        else switch_to = ext.specs_for_code(file)[0]
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
        prj = Ruber[:world].active_project
        return unless doc and prj
        if prj.extension(:rspec).spec_file? doc.path then text = 'Switch to &Code'
        else text = 'Switch to &Spec'
        end
        action_collection.action('rspec-switch').text = i18n(text)
        nil
      end
      slots 'change_switch_name(QObject*)'
      
    end
    
    
    class ProjectExtension < Qt::Object
      
      include Ruber::Extension
      
      def initialize prj
        super
        @project = prj
        @categories = {}
        connect Ruber[:rspec], SIGNAL(:settings_changed), self, SLOT(:clear)
      end
      
      def specs_for_code file
        return [] unless @project.file_in_project? file
        return [] unless code_file? file
        file.sub(@project.project_directory + '/', '')
        res = []
        @project[:rspec, :patterns].each do |pn|
          if File.fnmatch pn[:code], file
            basename = Ruber[:rspec].spec_for_pattern pn, file
            spec = File.join(@project.project_directory, @project[:rspec, :spec_directory], basename)
            res << spec
          end
        end
        res.select{|f| File.exist? f}
      end
      
      def code_for_spec file
        return nil unless @project.file_in_project? file
        return nil unless spec_file? file
        @project.project_files.find do |f|
          specs_for_code(f).include? file
        end
      end
      
      def code_file? file
        category(file) == :code
      end
      
      def spec_file? file
        category(file) == :spec
      end

      def category file
        cat = @categories[file]
        return cat if cat
        spec_dir = @project[:rspec, :spec_directory, :abs]
        code_dir = @project[:rspec, :code_directory, :abs]
        if @project.file_in_project? file
          if file.start_with? spec_dir
            if File.fnmatch @project[:rspec, :spec_files], file.sub(spec_dir + '/', '')
              @categories[file] = :spec
            else @categories[file] = :unknown
            end
          elsif file.start_with?(code_dir) and @project.file_in_project?(file)
            @categories[file] = :code
          else @categories[file] = :unknown
          end
        else @categories[file] = :unknown
        end
      end
      
      def clear
        @categories.clear
      end
      slots :clear
      
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
        view = @ui._rspec__patterns
        mod = Qt::StandardItemModel.new 
        view.model = mod
        mod.horizontal_header_labels = ['Code file', 'Spec file']
        @ui.add_pattern.connect(SIGNAL(:clicked)) do
          row = [Qt::StandardItem.new, Qt::StandardItem.new]
          mod.append_row row
          view.current_index = row[0].index
          view.edit row[0].index
        end
        @ui.remove_pattern.connect(SIGNAL(:clicked)) do
          sel = view.selection_model.selected_indexes
          mod.remove_row sel[0].row
        end
        view.selection_model.connect(SIGNAL('selectionChanged(QItemSelection,QItemSelection)')) do
          @ui.remove_pattern.enabled = view.selection_model.has_selection
        end
      end
      
      
      private
      
=begin rdoc
Sets the text of the pattern widget
@param [Array<String>] the pattern to use. They'll be joined with commas to create
the text to put in the widget
=end
      def patterns= value
        view = @ui._rspec__patterns
        value.each do |h|
          row = [Qt::StandardItem.new(h[:code]), 
                 Qt::StandardItem.new(h[:spec])]
          view.model.append_row row
        end
        2.times{|i| view.resize_column_to_contents i}
      end
      
=begin rdoc
Parses the content of the pattern widget
@return [Array<Hash>] an array containing the patterns
=end
      def patterns
        mod = @ui._rspec__patterns.model
        mod.each_row.map do |cols|
          code = cols[0].text
          {:code => code, :spec => cols[1].text, :glob => text_glob?(code)}
        end
      end
      
      def text_glob? text
        text=~ /[*?{}\[\]]/
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
      
=begin rdoc
The symbols associated with the entries in the @_rake__auto_expand@ widget
=end
      AUTO_EXPAND = [:expand_none, :expand_first, :expand_all]
      
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::RSpecConfigWidget.new
        @ui.setup_ui self
      end
      
=begin rdoc
Writer method for the @rspec/auto_expand@ option
@param [Symbol] value the value of the option. It may be any value contained in
  the {AUTO_EXPAND} constant
@return [Symbol] _value_
=end
      def auto_expand= value
        @ui._rspec__auto_expand.current_index = AUTO_EXPAND.index value
      end
      
=begin rdoc
Store method for the @rspec/auto_expand@ option
@return [Symbol] the symbol associated with the current entry in the @_rake__auto_expand@ 
  widget
=end
      def auto_expand
        AUTO_EXPAND[@ui._rspec__auto_expand.current_index]
      end
      
    end
    
  end
  
end