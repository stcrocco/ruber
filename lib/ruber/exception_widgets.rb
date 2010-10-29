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
Subclass of <tt>KDE::TextEdit</tt> specialized in displaying the backtrace of an
exception. The differences with a standard <tt>KDE::TextEdit</tt> are:
* automatically uses a fixed width font
* doesn't use word wrapping
* is always read-only
* its <tt>size_hint</tt> method computes (or at least tries to compute) width
  and height so that each line of the backtrace fits on a single line.
* automatically extracts the message and the backtrace from the exception
=end
    class ExceptionBacktraceWidget < KDE::TextEdit
            
=begin rdoc
Creates a new widget. _ex_ is the exception whose backtrace should be shown, while
_parent_ is the widget's parent widget. The message and backtrace of _ex_ are displayed
=end
      def initialize ex, parent = nil
        super parent
        self.line_wrap_mode = NoWrap
        self.read_only = true
        msg = ex.message.gsub(/[<>]/){|s| s == '<' ? '&lt;' : '&gt;'}
        backtrace = ex.backtrace.map{|l| l.gsub(/[<>]/){|s| s == '<' ? '&lt;' : '&gt;'}}
        text = "<tt>#{msg}<br/>#{backtrace.join '<br/>'}"
        self.html = text
      end
      
=begin rdoc
Override of <tt>KDE::TextEdit</tt> which computes the width as the width required
to display, using the fixed width font, the longest line. The height is the height
of a single line multiplied by the number of lines. Both width and height are
computed using <tt>Qt::FontMetrics</tt>.
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
Creates a new dialog. _ex_ is the exception whose contents will be shown. _parent_
is the dialog's parent widget. _out_ tells whether to also print the exception's
contents on standard error or not, when the widget is executed. _msg_ is a text
to display in the dialog above the exception's message.

<b>Note:</b> _msg_ will always be treated as rich text. A line break will always
be inserted between _msg_ and the beginning of the exception's message (unless _msg_
is empty).
=end
    def initialize ex, parent = nil, out = true, msg = 'Ruber raised the following exception:'
      super parent
      self.caption = KDE::Dialog.make_standard_caption "Exception"
      self.buttons = Ok | Details
      set_button_text Ok, 'Quit Ruber'
      set_button_text Details, 'Backtrace'
      error = ex.message.gsub(/\n/, '<br>')
      error.gsub!(/[<>]/){|s| s == '<' ? '&lt;' : '&gt;'}
      text = (!msg.empty? ? msg + '<br>' : '') + '<tt>' + error + '</tt>'
      self.main_widget = Qt::Label.new text, self
      @backtrace_widget = ExceptionBacktraceWidget.new ex, self
      self.details_widget = @backtrace_widget
      @out = out
    end
    
=begin rdoc
Override of <tt>KDE::Dialog#sizeHint</tt> which also takes into account the size
of the Details widget, if shown.
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
Override of <tt>KDE::Dialog#exec</tt> which also prints the exception's contents
on standard error it the _out_ parameter passed to the constructor was *true*
=end
    def exec
      if @out
        $stderr.puts @backtrace_widget.to_plain_text
      end
      super
    end
    
=begin rdoc
Override of <tt>KDE::Dialog#show</tt> which also prints the exception's contents
on standard error it the _out_ parameter passed to the constructor was *true*
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
It differs from ExceptionDialog in the following aspects:
* it provides different buttons
* it provides a check box to decide whether or not to warn of other errors while
  loading plugins
* its exec method provides values suitable to be returned from a block passed to
  <tt>ComponentManager#load_plugins</tt>
* it provides an appropriate text

The provided buttons are: 'Go on', 'Quit' and 'Skip remaining', which respectively
mean: ignore the failure and attempt to load the remaining plugins, quit Ruber
and go on without attempting to load other plugins.

If the exception was raised while loading a core plugin, the dialog will behave
exactly as an ExceptionDialog (since you can't start Ruber without one of the core
components, the other buttons and the checkbox would be useless)
=end
  class ComponentLoadingErrorDialog < ExceptionDialog
        
=begin rdoc
Creates a new dialog. _plugin_ is the name of the plugin loading which the error
occurred. _ex_ is the exception describing the error. _parent_ is the dialog's
parent widget and _core_ tells whether the failure occurred while loading a core
component or a plugin (this affects which widgets will be shown in the dialog)
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
Tells whether the user decided to ignore other errors while loading plugins. If
the dialog is shown for a core component (and so the check box isn't displayed),
this method always returns *nil*
=end
    def silently?
      @silent.checked? rescue nil
    end
    
=begin rdoc
Override of <tt>ExceptionDialog#exec</tt> which, depending on the choices made by
the user, returns a value suitable to be returned by the block passed to
<tt>ComponentManager#load_plugins</tt>. In particular, it returns:
*true*:: if the user pressed the "Go on" button and left the checkbox empty
<tt>:silent</tt>:: if the user pressed the "Go on" button and checked the check box
*false*:: if the user pressed the "Quit" button
+:skip+:: if the user pressed the "Skip" button
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