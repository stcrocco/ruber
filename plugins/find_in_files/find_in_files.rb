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

require 'ruber/external_program_plugin'

require 'find_in_files/find_in_files_widgets'
require 'find_in_files/find_in_files_dlg'

module Ruber
  
=begin rdoc
Plugin which allows the user to perform searches and replacements in a range of files

This plugin, which is mostly a frontend for the "rak":http://rak.rubyforge.org/ program,
consists in a dialog and two tool widgets.
  
The dialog is where the user chooses
the search criteria (the text to search, the directory where to look and filters
to limit the kind of files to look for) and, optionally, the replacement text. 
Depending on whether the user presses the Find or the Replace button in the dialog,
a find or a replacement operation is started.

The tool widgets display the results of the search and replacement operations. In
particular, in case of a replacement, nothing is actually replaced when the user
presses the Replace button in the dialog. Instead, when this happens, the Replace
tool widgets is filled with a list of potential replacements. The user can uncheck
the replacements he doesn't like. The replacements are only applied when he presses
the Replace button on the tool widget. If a file changes before the user presses
that button, replacements in it won't  be carried out.

@api feature find_in_files
@plugin
=end
  module FindInFiles
  
=begin rdoc
Plugin class for the find_in_files feature

The @output_widget instance variable contains the widget output should by displayed
by at the time. This varies according to whether a search or a replacement search
is being performed.
=end
    class FindInFilesPlugin < ExternalProgramPlugin
      
=begin rdoc
Encapsulates information about a replacement
=end
      ReplacementData = Struct.new :regexp, :replacement_text, :options
      
      slots :find_replace, 'show_replacements(QString)'
      
=begin rdoc
Signal emitted when a search is started
=end
      signals :search_started
      
=begin rdoc
Signal emitted when a search for replacements is started
=end
      signals :replace_search_started
      
=begin rdoc
Signal emitted when a search is finished
=end
      signals :search_finished
      
=begin rdoc
Signal emitted when a search for replacements is finished
=end
      signals :replace_search_finished
            
=begin rdoc
@param [PluginSpecification] psf the plugin specification object associated with the
plugin
=end
      def initialize psf
        super
        Ruber[:autosave].register_plugin self, true
        @rak_path = nil
        @dlg = FindReplaceInFilesDlg.new
        @replace_data = nil
        self.connect SIGNAL('process_finished(int, QString)') do
          Ruber[:main_window].change_state 'find_in_files_running', false
        end
        connect @replace_widget, SIGNAL('file_added(QString)'), self, SLOT('show_replacements(QString)')
        self.connect(SIGNAL(:process_started)) do
          emit @replace_data ? replace_search_started : search_started
        end
        self.connect SIGNAL('process_finished(int, QString)') do
          emit @replace_data ? replace_search_finished : search_finished
        end
        Ruber[:components].connect(SIGNAL('feature_loaded(QString, QObject*)')) do |f, o|
          o.register_plugin self, true if f == 'autosave'
        end
        Ruber[:main_window].change_state 'find_in_files_running', false
      end
      
=begin rdoc
Override of {ExternalProgramPlugin#process_standard_output}

It passes the text to the output widget's @display_output@ method
@param [<String>] the lines to display, as produced by rak
=end
      def process_standard_output lines
        @output_widget.display_output lines
      end

=begin rdoc
Override of {ExternalProgramPlugin#process_standard_error}

It does nothing, so errors are ignored
@param [<String>] the error lines, as produced by rak
=end
      def process_standard_error lines
      end
      
      private
      
=begin rdoc
Override of {ExternalProgramPlugin#display_exit_message}

It doesn' display any message if rak exited succesfully
@return [nil]
=end
      def display_exit_message code, reason
        super if code != 0
        nil
      end
      
=begin rdoc
Starts a search or replcement search

This method is called when the user closes the dialog pressing the Search or
Replace button
@return [nil]
=end
      def find_replace
        @dlg.clear
        @dlg.allow_project = Ruber[:world].active_project
        @dlg.exec
        case @dlg.action
        when :find then find @dlg.find_text, options_from_dialog
        when :replace then replace @dlg.find_text, @dlg.replacement_text, options_from_dialog
        else return
        end
      end

=begin rdoc
Starts a search using the parameters the user entered in the dialog

After starting the search (which is an asynchronous process), it activates and
displays the Search tool widget.

@return [nil]
=end
      def find text, opts
        @replace_data = nil
        @output_widget = @find_widget
        cmd = cmd_line text, opts
        @find_widget.clear_output
        Ruber[:main_window].change_state 'find_in_files_running', true
        @find_widget.working_directory = '/'
        run_process 'rak', '/', cmd, nil
        Ruber[:main_window].activate_tool 'find_in_files_widget'
        nil
      end

=begin rdoc
Starts a replacement search using the parameters the user entered in the dialog

After starting the search (which is an asynchronous process), it activates and
displays the Replace tool widget.

@return [nil]
=end
      def replace find_text, replace_text, opts
        opts[:replace] = true
        regexp = create_regexp find_text, opts
        @replace_data = ReplacementData.new regexp, replace_text, opts
        @output_widget = @replace_widget
        cmd = cmd_line find_text, opts
        do_autosave opts[:places]
        @replace_widget.clear_output
        Ruber[:main_window].change_state 'find_in_files_running', true
        @replace_widget.working_directory = '/'
        run_process 'rak', '/', cmd, nil
        Ruber[:main_window].activate_tool 'replace_in_files_widget'
      end
      
=begin rdoc
Loads the settings
=end
      def load_settings
        @rak_path = Ruber[:config][:find_in_files, :rak_path]
        nil
      end
      
      private
      
=begin rdoc
Autosaves documents in preparation for a search

@param [String,<String>] places the files to save. If it is a string, then
its understood as an absolute directory name and all open documents corresponding
to files in that directory are saved. If it is an array, each element of the array
is interpreted as an absolute file name. All documents corresponding to such files
are saved.
@return [Boolean] as {Autosave::AutosavePlugin#autosave AutosavePlugin#autosave}
=end
      def do_autosave places
        docs = Ruber[:world].documents.documents_with_file
        if places.is_a? String then docs = docs.select{|d| d.path.start_with? places}
        else docs = docs.select{|d| places.include? d.path}
        end
        Ruber[:autosave].autosave self, docs, :on_failure => :ask, :message => 'Do you want to go on with replacing?'
      end

=begin rdoc
Creates a regexp to search for the given string with the given options

This method is used after the user starts a search from the dialog to create the
regexp to pass to rak.

@param [String] find_text the string to make the regexp for
@param [Hash] opts the options to use for the search
@option opts [Boolean] plain (false) whether the _find_text_ parameter should be
interpreted as a string rather than as a regexp. If *true*, characters which have
special meaning in a regexp will be escaped)
@option opts [Boolean] whole_words (false) whether the regexp must match whole words rather
than be allowed to match in the middle of a word. If *true*, the regexp will be
enclosed in a pair of \b sequences
@option opts [Boolean] case_insensitive (false) whether or not the regexp should
ignore case. If *true*, the regexp will be given the @Regexp::IGNORECASE@ flag
@return [Regexp] a regexp matching the given text and options
=end
      def create_regexp find_text, opts
        str = find_text.dup
        str = Regexp.quote str if opts[:plain]
        str = "\\b#{str}\\b" if opts[:whole_words]
        reg_opts = opts[:case_insensitive] ? Regexp::IGNORECASE : 0
        Regexp.new str, reg_opts
      end
      
=begin rdoc
Gathers the options entered in the find dialog an puts them in a hash

@return [Hash] a hash containing the options chosen by the user. It can contain
the following entries:
 * @:case_insensitive@: whether the search should be case insensitive or not
 * @:plain@: whether the contents of the find widget in the dialog should be interpreted
 as a regexp or a plain string
 * @:whole_words@: whether the search should match full words or not
 * @:places@: an array of files and directory to search
 * @:all_files@: whether all files or only those matching some filter must be searched
 * @:filter@: an array of the standard filters to use
 * @:custom_filter@: a custom filter to use
=end
      def options_from_dialog
        opts = {}
        opts[:case_insensitive] = !@dlg.case_sensitive?
        opts[:plain] = @dlg.mode == :plain
        opts[:whole_words] = @dlg.whole_words?
        places = case @dlg.places
        when :custom_dir then @dlg.directory
        when :project_dir then Ruber[:world].active_project.project_directory
        when :project_files then Ruber[:world].active_project.project_files.to_a
        when :open_files then Ruber[:world].documents.documents_with_file.map{|d| d.path}
        end
        opts[:places] = Array(places)
        opts[:all_files] = @dlg.all_files?
        opts[:filters] = @dlg.filters
        opts[:custom_filter] = @dlg.custom_filter
        opts
      end
      
=begin rdoc
Creates the command line to pass to rak
@param [String] text the string to look for
@param [Hash] opts an hash containing the options to use, as that returned by
{#options_from_dialog}
@return [<String>] an array with the arguments and options to pass to rak
=end
      def cmd_line text, opts
        cmd = []
        cmd << '-i' if opts[:case_insensitive]
        cmd << '-w' if opts[:whole_words]
        cmd << '-Q' if opts[:plain]
        if opts[:filters] then opts[:filters].each{|f| cmd << "--#{f}"}
        else cmd << '-a'
        end
        cmd << '-g' << opts[:custom_filter] if opts[:custom_filter]
        cmd << '-l' if opts[:replace]
        cmd << text
        cmd << opts[:places]
        #opts[:places] may be an array, so with flatten it will be reduced to strings
        cmd.flatten
      end
      
=begin rdoc
Inserts matches for the given file in the Replace tool widget

@param [String] file the name of the file
@return [nil]
=end
      def show_replacements file
        lines = File.readlines file
        lines.each_with_index do |l, i|
          l.chomp!
          new = l.dup
          changed = new.gsub! @replace_data.regexp, @replace_data.replacement_text
          @replace_widget.add_line file, i, l, new if changed
        end
        nil
      end

    end
    
  end
  
end