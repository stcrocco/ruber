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

module Ruber

=begin rdoc
Dialog which displays the content of an exception (that is, the message and the
backtrace) to the user.

The backtrace is shown as an extension widget, only if the user clicks the 'Backtrace'
button.
=end
  class ExceptionDialog < KDE::Dialog
 
=begin rdoc
Subclass of @KDE::TextEdit@ specialized in displaying the backtrace of an
exception.
    
The differences with a standard @KDE::TextEdit@ are:
* automatically uses a fixed width font
* doesn't use word wrapping
* is always read-only
* its {#size_hint} method computes (or at least tries to compute) width
  and height so that each line of the backtrace fits on a single line.
* automatically extracts the message and the backtrace from the exception
=end
    class ExceptionBacktraceWidget < KDE::TextEdit
            
=begin rdoc
@param [Exception] ex the exception whose backtrace should be displayed
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize ex, parent = nil
        super parent
        self.line_wrap_mode = NoWrap
        self.read_only = true
        #Replace < and > with the corresponding HTML entities in the message
        msg = ex.message.gsub(/[<>]/){|s| s == '<' ? '&lt;' : '&gt;'}
        #Replace < and > with the corresponding HTML entities in the backtrace
        backtrace = ex.backtrace.map{|l| l.gsub(/[<>]/){|s| s == '<' ? '&lt;' : '&gt;'}}
        text = "<tt>#{msg}<br/>#{backtrace.join '<br/>'}</tt>"
        self.html = text
      end
      
=begin rdoc
Override of @KDE::TextEdit#sizeHint@

The width is computed as the size (using the fixed width font) of the longest line,
while the height is computed as the height of a single line multiplied by the
number of lines.

Both width and height are computed using @Qt::FontMetrics@

@return [Qt::Size] the suggested size of the widget
=end
      def sizeHint
        font = Qt::TextCursor.new(document).char_format.font
        fm = Qt::FontMetrics.new font
        lines = to_plain_text.split_lines
        longest = lines.sort_by{|l| l.size}[-1]
        Qt::Size.new fm.width(longest), fm.height * lines.size
      end
      
    end
    
=begin rdoc
@param [Exception] ex the exception the dialog is for
@param [Qt::Widget,nil] the parent widget
@param [Boolean] out whether to display the exception to standard error when the
        dialog is executed
@param [String] msg the text to display in the dialog before the exception message.
        Note that this will always be treated as rich text. Unless empty,
        a line break will always be inserted after it
=end
    def initialize ex, parent = nil, out = true, msg = 'Ruber raised the following exception:'
      super parent
      self.caption = KDE::Dialog.make_standard_caption "Exception"
      self.buttons = Ok | Details
      set_button_text Ok, 'Quit Ruber'
      set_button_text Details, 'Backtrace'
      error = ex.message.gsub(/\n/, '<br/>')
      error.gsub!(/[<>]/){|s| s == '<' ? '&lt;' : '&gt;'}
      text = (!msg.empty? ? msg + '<br/>' : '') + '<tt>' + error + '</tt>'
      self.main_widget = Qt::Label.new text, self
      @backtrace_widget = ExceptionBacktraceWidget.new ex, self
      self.details_widget = @backtrace_widget
      @out = out
    end
    
=begin rdoc
Override of @KDE::Dialog#sizeHint@

It takes into account the size of the details widget, if shown.

@return [Qt::Size] the suggested size for the dialog
=end
    def sizeHint
      orig = super
      if defined?(@backtrace_widget) and @backtrace_widget.visible?
        main_width = main_widget.sizeHint.width
        diff = orig.width - main_width
        det_width = @backtrace_widget.sizeHint.width
        w = [det_width, main_width].max + diff
        Qt::Size.new(w, orig.height)
      else orig
      end
    end
    
=begin rdoc
Override of @KDE::Dialog#exec@ 

If the _out_ parameter passed to the constructor was *true*, displays the exception
message and backtrace on standard error before displaying the dialog
@return [Integer] the exit code of the dialog
=end
    def exec
      if @out
        $stderr.puts @backtrace_widget.to_plain_text
      end
      super
    end
    
=begin rdoc
Override of @KDE::Dialog#show@

If the _out_ parameter passed to the constructor was *true*, displays the exception
message and backtrace on standard error before displaying the dialog
@return [nil]
=end
    def show
      if @out
        $stderr.puts @backtrace_widget.to_plain_text
      end
      super
    end
    
  end
  
=begin rdoc
ExceptionDialog specialized to display failures when loading plugins and components.

It differs from {ExceptionDialog} in the following aspects:
* it provides different buttons
* it provides a check box to decide whether or not to warn of subsequent errors while
  loading plugins
* its #{exec} method provides values suitable to be returned from a block passed to
  {ComponentManager#load_plugins}
* it provides an appropriate text

The buttons on the dialog are: 

- Go on::= ignore the failure and attempt to load the remaining plugins, hoping
  everything goes well
- Quit::= immediately quit Ruber
- Skip remaining::= ignore the failure, but don't attempt to load any other plugin

If the exception was raised while loading a core component, the dialog will behave
exactly as an {ExceptionDialog} (since you can't start Ruber without one of the core
components, the other buttons and the checkbox would be useless).
=end
  class ComponentLoadingErrorDialog < ExceptionDialog
        
=begin rdoc

@param [Symbol,String] plugin the name of the component which caused the exception
@param [Exception] ex the exception which was raised
@param [Qt::Widget,nil] the parent widget
@param [Boolean] core whether the component which caused the failure is a core
        component or a plugin
=end
    def initialize plugin, ex, parent = nil, core = false
      msg = "An error occurred while loading the #{core ? 'component' : 'plugin' } #{plugin}. The error was:"
      super ex, parent, true, msg
      unless core
        label = main_widget
        w = Qt::Widget.new self
        self.main_widget = w
        w.layout = Qt::VBoxLayout.new w
        label.parent = w
        w.layout.add_widget label
        @silent = Qt::CheckBox.new "&Don't report other errors", w
        w.layout.add_widget @silent
        self.buttons = Yes|No|Cancel|Details
        self.set_button_text KDE::Dialog::Yes, "&Go on"
        self.set_button_text KDE::Dialog::No, "&Quit Ruber"
        self.set_button_text KDE::Dialog::Cancel, "&Skip remaining plugins"
        self.escape_button = KDE::Dialog::No
      end
    end

=begin rdoc
Whether or not the user checked to ignore subsequent errors

@return [Boolean,nil] *true* if the user checked the "Don't report other errors" check
                  box and *false* otherwise. If the dialog is shown for a core
                  component, this method always returns *nil*
=end
    def silently?
      @silent.checked? rescue nil
    end
    
=begin rdoc
Override of {ExceptionDialog#exec}
    
It returns a different value according to the button pressed by the user and to
whether he checked the "Don't report other errors" checkbox. The returned values
are suitable for use by a block passed to {ComponentManager#load_plugins}.

@return [Boolean,Symbol] 

- *true*:= if the user pressed the "Go on" button without checking the checkbox
- @:silent@:= if the user pressed the "Go on" button and checked the checkbox
- *false*:= if the user pressed the "Quit" button
- @:skip@:= if the user pressed the "Skip" button
=end
    def exec
      res = super
      case res
      when KDE::Dialog::Yes then dlg.silently? ? :silent : true
      when KDE::Dialog::No then false
      when KDE::Dialog::Cancel then :skip
      else res
      end
    end
    
  end
  
end