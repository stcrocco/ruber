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

require 'tempfile'
require 'open3'

require 'facets/boolean'

module Ruber
  
=begin rdoc
Module for the *Syntax checker* plugin.

This plugin provides a framework to let the user know whether the file in the
current editor view is syntactically correct or not (according to the most appropriate
sytnax for that kind of file). The result of the syntax check is displayed in a
widget at the right end of the status bar (this will be referred to as the *syntax
result widget). This implementation of the @syntax_checker@ feature uses a @KDE::Led@
whose colour changes according to the result of the syntax check, but other plugins
may use other widgets. If the user right clikcs on the widget, a menu showing a
list of syntax errors is displayed. Clicking on it will jump to the corresponding
like, while clicking on the widget itself jumps to the line corresponding to the
first error.

The syntax check is run every time the file is activated or saved and the user can choose to
have it run automatically when one second has passed since he last edited the
file. The reasoning is that it makes little sense to check the syntax while the
user is writing text: it will most likely be wrong (because the user hasn't finished
writing what he wants), may quickly change from valid to invalid depending on the
point the user has reached in writing, and the user won't look at it because he's
busy writing.

The kind of syntax check to perform on a document is decided according to the mimetype
of the document (this means that only documents associated with a file can be
syntax-checked). Currently, this plugin contains syntax checkers for ruby files
and YAML files, but syntax checkers for other kind of files can be added by other
plugins (see the documentation for {SyntaxCheckerPlugin#register_syntax_checker register_syntax_checker}
for details)

@api feature syntax_checker
@plugin
@config_option syntax_checker automatic_check [Boolean] Whether to perform automatic
syntax checks after one second of inactivity
=end
  module SyntaxChecker

=begin rdoc
Plugin object for the @sytax_checker@ feature

@api class SyntaxChecker::SyntaxCheckerPlugin
@api_method #register_syntax_checker
@api_method #remove_syntax_checker
=end
    class SyntaxCheckerPlugin < Plugin
      
=begin rdoc
Class containing the information about a syntax error. It has four attributes:
line:= the line at which the syntax error occurred (note that this starts from
1, while Document and EditorView count lines from 0)
message:= a string describing the syntax error
code:= a string with the code around the point where the syntax error occurred
column:= the column at which the syntax error occurred

This class'constructor can take up to four parameters, corresponding (in
the same order) to the four attributes described above.
=end
      ErrorDescription = Struct.new(:line, :message, :code, :column)
      
=begin rdoc
Colors used to display the different states of the document
=end
      COLORS = {
        :correct => Qt::Color.new(Qt.green),
        :error => Qt::Color.new(Qt.red),
        :unknown => Qt::Color.new(Qt.gray)
        }
      
=begin rdoc
Signal emitted when it's time to perform an automatic syntax check
=end
      signals :timeout

=begin rdoc
Creates an instance of the plugin

It also registers the two built-in syntax checkers

@param [Ruber::PluginSpecification] the specification associated to the
plugin
=end
      def initialize psf
        super
        @availlable_syntax_checkers = {}
        register_syntax_checker RubySyntaxChecker, 'application/x-ruby',
            %w[*.rb rakefile Rakefile]
        register_syntax_checker YamlSyntaxChecker, [], %w[*.yml *.yaml]
        @led = SyntaxResultWidget.new
        Ruber[:main_window].status_bar.add_permanent_widget @led
        mark_document_as :unknown
      end
      
=begin rdoc
Instantiates an appropriate syntax checker for a document

@param [Document] doc the document to create the syntax checker for
@return [Object,nil] a syntax checker suitable for _doc_ or *nil* if _doc_ is not
associated with a file or no syntax checker has been registered for <i>doc</i>'s extension
or mimetype
=end
      def syntax_checker_for doc
        checker_cls = @availlable_syntax_checkers.find! do |cls, data|
          doc.file_type_match?(*data) ? cls : nil
        end
        checker_cls ? checker_cls.new(doc) : nil
      end
      
=begin rdoc
Tells the plugin to display the result of the syntax check for the current document

@param [Symbol] status the result of the syntax check. It can be one of @:correct@,
@:error@ or @:unknown@ (if no syntax checker was availlable for the document)
@param [Array<SyntaxCheckerPlugin::ErrorDescription>] errors an array containing
instances of class {SyntaxCheckerPlugin::ErrorDescription} describing each of the
syntax error which where found in the document. This argument is only used if
_status_ is @:error@
@return [SyntaxCheckerPlugin] *self*
=end
      def mark_document_as status, errors = []
        msg = case status
        when :correct then 'Syntax OK'
        when :unknown then 'Document type unknown'
        when :error then errors.map{|e| format_error_message e}.join "\n"
        end
        @led.tool_tip = msg
        @led.color = COLORS[status]
        self
      end
      
=begin rdoc
Registers a new syntax checker.

A syntax checker is an object which analyzes the contents of a document and tells
whether its syntax is correct or not. To register it with the plugin, you need
to pass the object's class, toghether with the mimetypes and file patterns it
should be used to check syntax for, to this method. When a new document with the
appropriate mimetype or file name is created, a new instances of the syntax checker
class will be created.

The syntax checker class must have the following characteristics:
* its constructor should take the document as only parameter
* it should have a @check@ method which takes a string (corresponding to the text
of the document) and performs the syntax check on it. It must return a string
with all the information needed to retrieve the information about the single
errors.
* it should have a @convert_check_result@ method, which takes the string
returned by the @check@ method and converts it to an array of {ErrorDescription}
objects, with each object containing the information about a single error. If
the document doesn't contain any syntax error, this method should return an
empty array.


@param [Class] cls the class to instantiate to create the syntax checker
@param [String, <String>] mimetypes the mimetypes to use the new syntax checker
for. It has the format described in {Document#file_type_match?}
@param [String, <String>] patterns the file patterns to use the new syntax checker
for. It has the format described in {Document#file_type_match?}
@return [SyntaxCheckerPlugin] *self*
@raise ArgumentError if _cls_ had already been registered as a syntax checker.
=end
      def register_syntax_checker cls, mimetypes, patterns = []
        if @availlable_syntax_checkers.include? cls
          raise ArgumentError, "class #{cls} has already been registered as syntax checker"
        else
          @availlable_syntax_checkers[cls] = [mimetypes, patterns]        end
      end
      
=begin rdoc
Removes a registered syntax checker.

Nothing is done if the syntax checker hadn't been registered.

@param [Class] cls the class of the syntax checker to remove
@return [Boolean] *true* if the syntax checker was removed and *false* if it wasn't
registered
=end
      def remove_syntax_checker cls
        res = @availlable_syntax_checkers.delete cls
        res.to_bool
      end  

=begin rdoc
Prepares the plugin for application shutdown
@return [SyntaxCheckerPlugin] *self*
=end
      def shutdown
        @timer.stop
        self
      end
      
=begin rdoc
Prepares the plugin to be unloaded

@return [SyntaxCheckerPlugin] *self*
=end
      def unload
        Ruber[:main_window].status_bar.remove_widget @led
        super
        self
      end
      
=begin rdoc
Generates an error message from an error object

The returned string contains the error message together with information about
the line and the column (if known) where the error happened

@param [ErrorDescription] error the object containing the error message
@return [String] a string containing the error message, including line and row
where the error happened, formatted in a standard way
=end
      def format_error_message error
        res = "Line #{error.line}"
        res += " Col #{error.column}" if error.column
        res += ": #{error.message}"
        res
      end
      
=begin
Starts the timer for the automatic check

@return [SyntaxCheckerPlugin] *self*
=end
      def start_timer
        if @timer
          @timer.stop
          @timer.start
        end
        self
      end
      
=begin
Stops the timer for the automatic check

@return [SyntaxCheckerPlugin] *self*
=end
      def stop_timer
        @timer.stop if @timer
        self
      end
      
=begin rdoc
Loads the settings

If automatic checking has been enabled, a timer is created; if it has been disabled,
the timer is destroyed

@return [nil]
=end
      def load_settings
        auto_check = Ruber[:config][:syntax_checker, :automatic_check]
        if auto_check and !@timer
          @timer = Qt::Timer.new self
          @timer.interval = 1000
          connect @timer, SIGNAL(:timeout), self, SIGNAL(:timeout)
          @timer.start if Ruber[:main_window].current_document
        elsif !auto_check
          @timer.disconnect self
          @timer.dispose
          @timer = nil
        end
        nil
      end
      
    end

=begin rdoc
Document extension which checks the syntax for a document. The syntax check happens:
* when the document becomes active
* when the document is saved
* one second after the last modification (if the user has enabled automatic checks)

The check can only be done if a syntax checker for the document's mimetype
or file extension exists. New syntax checkers must be added to the syntax checker
plugin using the {SyntaxCheckerPlugin#register_syntax_checker} method,
and can be removed using {SyntaxCheckerPlugin#remove_syntax_checker}.

The appropriate syntax checker for the document is chosen when the extension is
added to the document, and is changed (if needed) whenever the @document_name@
of the document changes.

*Note:* in the documentation of this class, the term _document_ will refer
to the Document passed as argument to the constructor.
=end
    class SyntaxCheckerExtension < Qt::Object
      
      include Extension

=begin rdoc
Signal emitted after a syntax check has been completed

@param [String] result a string containing the results of the syntax check
=end
      signals 'check_done(QString)'
      
      slots 'update_ui(QString)', :check, :document_activated,
          :document_deactivated, :document_name_changed, :create_syntax_checker

=begin rdoc
A list of the syntax errors found in the document
      
The list is empty if the document doesn't contain syntax errors or if it hasn't
been checked yet

@return [<SyntaxCheckerPlugin::ErrorDescription>] the syntax errors found in the
document
=end
      attr_reader :errors
      
=begin rdoc
Creates a new instance

@param [DocumentProject] prj the project associated with the document
=end
      def initialize prj
        super
        @plugin = Ruber[:syntax_checker]
        @doc = prj.document
        @errors = []
        @checker = nil
        connect @doc, SIGNAL(:activated), self, SLOT(:document_activated)
        connect @doc, SIGNAL(:deactivated), self, SLOT(:document_deactivated)
        @doc.connect(SIGNAL('modified_changed(bool, QObject*)')) do |mod, _|
          check if !mod
        end
        connect @doc, SIGNAL('document_name_changed(QString, QObject*)'), self, SLOT(:create_syntax_checker)
        @doc.connect SIGNAL('text_changed(QObject*)') do
          if @doc.active?
            @plugin.stop_timer
            @plugin.start_timer
          end
        end
        @thread = nil
        create_syntax_checker
      end
      
=begin rdoc
Sets the syntax status according to the results of the last syntax check

It marks the current document as having correct or incorrect syntax depending on
the contents of _str_.

@param [String] str the string containing the results of the syntax check (such as
the one that a syntax checker's @check@ method). It is passed to the syntax checker's
@convert_check_result@ method
@return [nil]
=end
      def update_ui str
        @errors = @checker.convert_check_result str
        if @errors.empty? then @plugin.mark_document_as :correct
        else @plugin.mark_document_as :error, @errors
        end
        nil
      end
      
=begin rdoc
Starts a syntax check for the document

The syntax check can be synchronous or asynchronous, according to the value of
the argument. In the first case, this method won't return until the syntax check
has finished and the UI has been updated. In the second case, the method will
start the syntax check in a new thread and return immediately. The {#check_done}
signal will be emitted when the syntax check has been finished.

Nothing will be done if no checker exists for the document.

*Note:* while an asynchronous syntax check avoids freezing the UI if it takes
a long time, it seems that it takes much longer than a synchronous check.

@param [Boolean] async whether the syntax check should or not be asynchronous
@todo the decision on whether the check should be synchronous or asynchronous 
should be delegated to the checker
@return [nil]
=end
      def check async = false
        return unless @checker
        @plugin.stop_timer
        if async
          @threak.kill if @thread
          @thread = Thread.new(@doc.text) do |str|
            res = @checker.check @doc.text
            emit check_done res
          end
        else
          res = @checker.check @doc.text
          update_ui res
        end
        nil
      end
      
      private
      
=begin rdoc
Creates a syntax checker for the document

If needed, it also removes the old one and immediately performs a syntax check

@return [nil]
=end
      def create_syntax_checker
        new_checker = Ruber[:syntax_checker].syntax_checker_for @doc
        if @checker.class != new_checker.class
          @checker.disconnect if @checker
          @checker = nil
          if new_checker
            @checker = new_checker
            connect self, SIGNAL('check_done(QString)'), self, SLOT('update_ui(QString)')
          end
          check if @doc.active?
        end
        nil
      end
      
=begin rdoc
Informs the extension that the document is not active anymore

@return [nil]
=end
      def document_deactivated
        @thread.kill if @thread
        @plugin.stop_timer
        @plugin.disconnect SIGNAL(:timeout), self, SLOT(:check)
        Ruber[:syntax_checker].mark_document_as :unknown
        nil
      end
      
=begin rdoc
Informs the extension that the document became active

@return [nil]
=end
      def document_activated
        connect @plugin, SIGNAL(:timeout), self, SLOT(:check)
        check
        nil
      end
      
    end
    
=begin rdoc
Class which checks the syntax of a ruby file.

To do so, it runs a separate ruby process (using the ruby interpreter set by the
Ruby Runner plugin) passing it the @-c@ and the @-e@ options with the document's
content as argument.

The process is executed using @Open3.popen3@
=end
    class RubySyntaxChecker
    
=begin rdoc
Creates a new instance.

@param [Document] doc the document to check
=end
      def initialize doc
        @doc = doc
      end
      
=begin rdoc
Checks the syntax of the given string.

@param [String] str the string to check (usually, it'll be the document's text)
@return [String] a string containing the lines of output produced by ruby concerning
syntax errors or an empty string if there were no syntax error
=end
      def check str
        ruby = Ruber[:ruby_development].interpreter_for @doc
        Open3.popen3(ruby, '-c', '-e', str) do |in_s, out_s, err_s|
          error = err_s.read
          error.gsub! %r{^-e(?=:\d+:\s+syntax error,)}, @doc.path
          out_s.read.strip != 'Syntax OK' ? error : ''
        end
      end
      
=begin rdoc
Parses the output of {#check}

@param [String] str the string to parse.
@return [<SyntaxCheckerPlugin::ErrorDescription>] a list of {SyntaxCheckerPlugin::ErrorDescription ErrorDescription}s
corresponding to the syntax errors mentioned in _str_
=end
      def convert_check_result str
        groups = [[]]
        lines = str.split "\n"
        lines.each do |l|
          if l.match(/^#{Regexp.quote(@doc.path||'')}:\d+:\s+syntax error,\s+/) then groups << [l]
          else groups[-1] << l
          end
        end
        groups.delete_if{|g| g.empty?}
        groups.map do |a|
          a.shift.match(/^#{Regexp.quote(@doc.path||'')}:(\d+):\s+syntax error,\s+(.*)/)
          msgs = [$2]
          error = SyntaxCheckerPlugin::ErrorDescription.new $1.to_i
          if a[-1] and a[-1].match(/^\s*\^\s*$/)
            error.code = a[-2]
# Sometimes, ruby doesn't report the whole line where the error occurs, but only
# the part nearest it. In this case, the beginning of the line is replaced with ... . 
# In this case, to obtain the correct column number, we try a regexp match
# between the part of code reported by ruby and the whole line. If it works, we
# add that position to the one returned by ruby. If it doesn't (for example because
# the user changed the document in the meantime), we'll just report what ruby reports
            col = a[-1].index('^') 
            if a[-2].match(/^\.\.\./)
              lines = @doc.text.split("\n")
              # error.line is 1-based
              l = lines[error.line-1] || ''
              pos = (l =~ /#{Regexp.quote(a[-2][3..-1])}/)
              error.column = pos ? col + pos - 1 : col
            else error.column = col
            end
            a.pop 2
          end
          a.each{|l| msgs << l}
          error.message = msgs.join ' '
          error
        end
      end
      
    end

=begin rdoc
Class which checks the syntax of a ruby file.

It calls the @YAML.load@ method on the document's content within a begin/rescue
block, rescuing any ArgumentError exception. The message of the exception is used
to find information about the error
=end
    class YamlSyntaxChecker
      
=begin rdoc
Creates a new instance

@param [Document] doc the document to check
=end
      def initialize doc
      end

=begin rdoc
Checks the syntax of the given string.

@param [String] str the string to check (usually, it'll be the document's text)
@return [String] a string containing the lines of output produced by @YAML.load@
concerning syntax errors or an empty string if there were no syntax error
=end
      def check str
        begin 
          YAML.load str
          ''
        rescue ArgumentError => e
          e.message
        end
      end
      
=begin rdoc
Parses the output of {#check}

@param [String] str the string to parse.
@return [<SyntaxCheckerPlugin::ErrorDescription>] a list of {SyntaxCheckerPlugin::ErrorDescription ErrorDescription}s
corresponding to the syntax errors mentioned in _str_
=end
      def convert_check_result str
        return [] if str.empty?
        str.match(/^syntax error on line (\d+), col (\d+): `(.*)'$/)
        error = SyntaxCheckerPlugin::ErrorDescription.new $1.to_i, 'Syntax error', $3.to_s, $2.to_i
        [error]
      end
      
    end    
    
=begin rdoc
  @KDE::Led@ with the ability to jump to the first syntax error on left or middle mouse
  click and to popup a menu with a list of all syntax errors in the current document
  on right click
=end
    class SyntaxResultWidget < KDE::Led
    
=begin rdoc
Override of @Qt::Widget#mouseReleaseEvent@

If the event refers to the left button and the current document contains syntax
errors, it moves the cursor in the editor view to the position of the first error

@return [nil]
=end
      def mouseReleaseEvent e
        return unless e.button == Qt::LeftButton or e.button == Qt::MidButton
        doc = Ruber[:main_window].current_document
        view = Ruber[:main_window].active_editor
        return unless view and doc and doc.extension(:syntax_checker)
        checker = doc.extension(:syntax_checker)
        err = checker.errors.first
        if err
          view.go_to err.line - 1, (err.column || 0)
          Ruber[:main_window].status_bar.show_message Ruber[:syntax_checker].format_error_message(err), 4000
        end
        nil
      end
        
=begin rdoc
Override of @Qt::Widget#contextMenuEvent@

If the current document contains syntax errors, it displays a menu listing them.
Each action in the menu moves the cursor in the editor view to display to the line
and column of the corresponding error.

If the current document doesn't contain syntax errors, the menu will only contain
an entry with text @Syntax OK@ which does nothing when activated.

@return [nil]
=end
      def contextMenuEvent event
        doc = Ruber[:main_window].current_document
        view = Ruber[:main_window].active_editor
        return unless doc and view and (checker = doc.extension :syntax_checker)
        errors = checker.errors
        actions = errors.map do |e|
          a = KDE::Action.new Ruber[:syntax_checker].format_error_message(e), self
        end
        actions << KDE::Action.new('Syntax OK', self) if actions.empty?
        res = Qt::Menu.exec(actions, event.global_pos)
        return if !res or errors.empty?
        idx = actions.index res
        return unless idx
        error = errors[idx]
        view.go_to error.line - 1, (error.column || 0)
        Ruber[:main_window].status_bar.show_message res.text, 4000
        nil
      end

    end
    
  end
  
end