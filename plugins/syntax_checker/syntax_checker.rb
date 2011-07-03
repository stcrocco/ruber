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
require_relative 'ui/config_widget'

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

    SyntaxError = Struct.new :line, :column, :message, :formatted_message
    
    class SyntaxError
      
      def format
        res = ""
        res << KDE.i18n("Line %d") % (line + 1) if line
        res << KDE.i18n(", column %d") % (column + 1) if line and column
        msg = formatted_message || message
        res << ": " if msg and !res.empty?
        res << msg
        res
      end
      
    end
    
=begin rdoc
Plugin object for the @syntax_checker@ feature

@api class SyntaxChecker::SyntaxCheckerPlugin
@api_method #register_syntax_checker
@api_method #remove_syntax_checker
=end
    class Plugin < Ruber::Plugin
      
      attr_reader :current_status
      
      attr_reader :current_errors
      
      COLORS = {
        :correct => Qt::Color.new(Qt.green),
        :unknown => Qt::Color.new(Qt.gray),
        :incorrect => Qt::Color.new(Qt.red)
      }
      
      MESSAGES = {
        :correct => 'No syntax errors',
        :unknown => 'Unknown document type',
        :incorrect => 'There are syntax errors'
      }

      class Led < KDE::Led
        
        signals 'context_menu_requested(QPoint)'
        
        signals :left_clicked
        
        def contextMenuEvent e
          emit context_menu_requested(e.global_pos)
        end
        
        def mouseReleaseEvent e
          emit left_clicked if e.button == Qt::LeftButton
        end
        
      end
      
      signals :settings_changed
      
      def initialize psf
        super
        self.connect(SIGNAL('extension_added(QString, QObject*)')) do |name, prj|
          connect prj.extension(name.to_sym), SIGNAL('syntax_checked(QObject*)'), self, SLOT('document_checked(QObject*)')
        end
        @syntax_checkers = {}
        @led = Led.new
        connect @led, SIGNAL('context_menu_requested(QPoint)'), self, SLOT('display_context_menu(QPoint)')
        connect @led, SIGNAL(:left_clicked), self, SLOT(:jump_to_first_error)
        Ruber[:main_window].status_bar.add_permanent_widget @led
        set_current_status :unknown
      end
      
      def unload
        Ruber[:main_window].status_bar.remove_widget @led
        super
        self
      end
      
      def set_current_status status, errors = []
        @led.color = COLORS[status]
        if status == :incorrect and !errors.empty?
          tool_tip = errors.map do |e|
            e.format
          end.join "\n"
          @led.tool_tip = tool_tip
        else @led.tool_tip = i18n(MESSAGES[status])
        end
        @current_status = status
        if @current_status == :incorrect
          @current_errors = errors.dup
        else @current_errors = nil
        end
      end
      
      def register_syntax_checker cls, mimetypes, patterns = []
        if @syntax_checkers.include? cls
          raise ArgumentError, "#{cls} has already been registered as syntax checker"
        end
        @syntax_checkers[cls] = [mimetypes, patterns]
      end
      
      def remove_syntax_checker cls
        @syntax_checkers.delete cls
      end
      
      def syntax_checker_for doc
        cls = @syntax_checkers.find do |_, rules| 
          doc.file_type_match?(rules[0], rules[1])
        end
        return unless cls
        cls[0]
      end
      
      def load_settings
        emit settings_changed
      end
      
      private
      
      def display_context_menu pt
        return if @current_status == :unknown
        if !@current_errors || @current_errors.empty?
          actions = [KDE::Action.new(i18n(MESSAGES[@current_status]), @led)]
        else actions = @current_errors.map{|e| KDE::Action.new e.format, @led}
        end
        choice = Qt::Menu.exec actions, pt
        return if !choice or !@current_errors or @current_errors.empty?
        error = @current_errors[actions.index(choice)]
        line = error.line
        col = error.column || 0
        Ruber[:world].active_environment.active_editor.go_to line, col if line
      end
      slots 'display_context_menu(QPoint)'
      
      def jump_to_first_error
        return unless @current_errors and !@current_errors.empty?
        e = @current_errors[0]
        col = e.column || 0
        if e.line
          Ruber[:world].active_environment.active_editor.go_to e.line, col
        end
      end
      slots :jump_to_first_error
      
      def document_checked doc
        return unless doc.active?
        ext = doc.extension(:syntax_checker)
        set_current_status ext.status, ext.errors
      end
      slots 'document_checked(QObject*)'
      
    end
    
    class Extension < Qt::Object
      
      include Ruber::Extension
      
      SyntaxErrorMark = KTextEditor::MarkInterface.markType09
      
      DEFAULT_CHECK_OPTIONS = {:format => true, :update => true}
      
      attr_reader :errors
      
      attr_reader :status
      
      signals 'syntax_checked(QObject*)'
      
      def initialize prj
        super
        @status = :unknown
        @errors = nil
        @doc = prj.document
        connect @doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT('create_syntax_checker(QObject*)')
        connect @doc, SIGNAL('document_saved_or_uploaded(QObject*, bool)'), self,
            SLOT(:auto_check)
        connect @doc, SIGNAL('text_changed(QObject*)'), self, SLOT(:start_waiting)
        create_syntax_checker @doc
        connect @doc, SIGNAL(:activated), self, SLOT(:document_activated)
        connect @doc, SIGNAL(:deactivated), self, SLOT(:delete_timer)
        connect Ruber[:syntax_checker], SIGNAL(:settings_changed), self, SLOT(:load_settings)
        load_settings
      end
      
      def check_syntax options = DEFAULT_CHECK_OPTIONS
        options = DEFAULT_CHECK_OPTIONS.merge options
        if @checker
          errors = @checker.check_syntax @doc.text, options[:format]
          res = {:errors => errors, :result => errors ? :incorrect : :correct}
        else res = {:result => :unknown, :errors => nil}
        end
        if options[:format] and options[:update]
          @errors = errors
          @status = res[:result]
          if errors
  #Uncomment the following lines when KTextEditor::MarkInterface#marks works
  #           iface = @doc.interface('mark_interface')
  #           errors.each do |e|
  #             iface.add_mark e.line, SyntaxErrorMark if e.line
  #           end
          end
          emit syntax_checked(@doc) if options[:format]
        end
        res
      end
      slots :check_syntax
      
      def remove_from_project
        super
        @timer.stop if @timer
      end
      
      private
      
      def create_syntax_checker doc
        checker_cls = Ruber[:syntax_checker].syntax_checker_for doc
        @checker = checker_cls ? checker_cls.new : nil
      end
      slots 'create_syntax_checker(QObject*)'
      
      def auto_check
        check_syntax if @doc.own_project[:syntax_checker, :auto_check]
      end
      slots :auto_check
      
      def document_activated
        @timer = Qt::Timer.new self
        @timer.singleShot = true
        connect @timer, SIGNAL(:timeout), self, SLOT(:auto_check)
        auto_check
      end
      slots :document_activated
      
      def delete_timer
        @timer.stop
        @timer.delete_later
        @timer = nil
      end
      slots :delete_timer
      
      def load_settings
        @time_interval = Ruber[:config][:syntax_checker, :time_interval]
      end
      slots :load_settings
      
      def start_waiting
        @timer.start 1_000 * @time_interval if @time_interval > 0 and @doc.active?
      end
      slots :start_waiting
      
    end
    
    class ConfigWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::SyntaxCheckerConfigWidget.new
        @ui.setup_ui self
      end
      
    end
    
  end
  
end