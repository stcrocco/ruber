=begin 
    Copyright (C) 2011 by Stefano Crocco   
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
  
  module CommandPlugin

=begin rdoc
Fake IO object for use by the command plugin. Despite the name, it can be used
to display standard error as well as standard output.

It displays the text in a @Qt::PlainTextEdit@ using a given color.

All the methods in this class are implementations of the API provided by IO.

@example Typical usage

  old_stdout = $stdout #store the old standard output to restore it later
  $stdout = Output.new plain_text_edit, Qt::Color.new(Qt.blue)
  puts "hello" # => the string "hello" is displayed in the widget
  $stdout = old_stout # restore the old standard output
=end
    class Output
      
=begin rdoc
@param [Qt::PlainTextEdit] widget the widget to display the output into
@param [Qt::Color] color the color to use for the text
@param [Integer] fileno the number that the {#fileno} method should return
=end
      def initialize widget, color, fileno = 1
        @widget = widget
        @close_on_exec = false
        @closed = false
        @sync = true
        @brush = Qt::Brush.new color
        @fileno = fileno
      end
      
=begin rdoc
@return [Boolean] whether byffering is disabled or enabled. This class doesn't buffer
  output, so this makes no difference. It's only provided for compatibility with
  @IO@ API
=end
      attr_accessor :sync
      
=begin rdoc
As @IO#<<@

@return [Output] self
=end
      def << text
        write text
        self
      end
      
=begin rdoc
As @IO#binmode@

This method doesn't actually do anything. It's just for compatibility with the @IO@
API
@return [nil]
=end
      def binmode
      end

=begin rdoc
As @IO#binmode?@

This method always returns *true*. It's just for compatibility with the @IO@
API
@return [TrueClass] *true*
=end
      def binmode?
        true
      end
      
=begin rdoc
As @IO#bytes@

@return [Enumerator] an enumerator which calls {#each_byte}
=end
      def bytes
        each_byte
      end

=begin rdoc
As @IO#chars@

@return [Enumerator] an enumerator which calls {#each_char}
=end

      def chars
        each_char
      end
      
=begin rdoc
As @IO#close@

@return [nil]
=end
      def close
        @closed = true
        nil
      end

=begin rdoc
As @IO#close_on_exec@

This method does nothing. It's only for compatibility with @IO@ API
@param [Object] val the new value
@return [Object] _val_
=end

      def close_on_exec= val
        @close_on_exec = val.to_bool
      end
      
=begin rdoc
As @IO#close_on_exec?@

{#close_on_exec=} has no influence on this class, so the value returned here is
meaningless. It's only provided for compatibility with @IO@ API
@return [Boolean] whether close on exec is enabled or not. Nothing changes in either
  case
=end
      def close_on_exec?
        @close_on_exec
      end

=begin rdoc
As @IO#close_read@

@raise [IOError] always as this class isn't open for reading
@return [nil]
=end
      def close_read
        raise IOError, 'closing non-duplex IO for reading'
      end
      
=begin rdoc
As @IO#close_write@

@return [nil]
=end
      def close_write
        @closed = true
        nil
      end
      
=begin rdoc
As @IO#closed?@

@return [Boolean] whether the stream is closed or not
=end
      def closed?
        @closed
      end
      
=begin rdoc
As @IO#each@

@raise [IOError] when called with a block because the stream is not open for reading
@return [Enumerator] an enumerator which calls {#each} when called without a block
=end
      def each
        raise IOError, "not opened for reading" if block_given?
        to_enum
      end

=begin rdoc
As @IO#each_byte@

@raise [IOError] when called with a block because the stream is not open for reading
@return [Enumerator] an enumerator which calls {#each_byte} when called without a block
=end
      def each_byte
        raise IOError, "not opened for reading" if block_given?
        to_enum :each_byte
      end

=begin rdoc
As @IO#each_char@

@raise [IOError] when called with a block because the stream is not open for reading
@return [Enumerator] an enumerator which calls {#each_char} when called without a block
=end
      def each_char
        raise IOError, "not opened for reading" if block_given?
        to_enum :each_char
      end

=begin rdoc
As @IO#each@

@raise [IOError] when called with a block because the stream is not open for reading
@return [Enumerator] an enumerator which calls {#each_line} when called without a block
=end
      def each_line sep
        raise IOError, "not opened for reading" if block_given?
        to_enum :each_line
      end

=begin rdoc
As @IO#eof@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def eof
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#eof?@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def eof?
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#external_encoding@

@return [nil]
=end
      def external_encoding
        nil
      end

=begin rdoc
As @IO#fileno@

@return [Integer] the third argument passed to the constructor
=end
      def fileno
        @fileno
      end

=begin rdoc
As @IO#flush@

As this class doesn't do any buffering, this method does nothing and is only
provided for compatibility with @IO@ API

@return [Output] *self*
=end
      def flush
        self
      end

=begin rdoc
As @IO#getbyte@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def getbyte
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#getc@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def getc
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#gets@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def gets
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#internal_encoding@

@return [nil]
=end
      def internal_encoding
        nil
      end

=begin rdoc
As @IO#isatty@

@return [false]
=end
      def isatty
        false
      end
      alias_method :tty?, :isatty

=begin rdoc
As @IO#lineno@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def lineno
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#lineno=@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def lineno= val
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#lines@

@return [Enumerator] an enumerator which calls {#each_line}
=end
      def lines
        each_line
      end

=begin rdoc
As @IO#pid@

@return [nil]
=end
      def pid
        nil
      end
      
=begin rdoc
As @IO#print@

@param [Array<Object>] args the objects to print
@return [nil]
=end
      def print *args
        args = [$_] if args.empty?
        args.each{|a| write a}
        STDOUT.write $\
        write $\ if $\
        nil
      end
      
=begin rdoc
As @IO#printf@

@param [String] format_string the format string. See @Kernel.sprintf@
@param [Array<Object>] args the parameter to substitute in the format string
@return [nil]
=end
      def printf format_string, *args
        str = sprintf format_string, *args
        write str
        nil
      end
      
=begin rdoc
As @IO#putc@

@param [Object] obj the object
@return [Object] obj
=end
      def putc obj
        if obj.is_a? Numeric then write obj.floor.chr
        else obj.to_s.each_char.to_a[0]
        end
        obj
      end
      
=begin rdoc
As @IO#puts@

@param [Array<Object>] args the objects to write
@return [nil]
=end
      def puts *args
        args << '' if args.empty?
        args.each do |a|
          a = a.to_s
          write a
          write "\n" unless a.end_with? "\n"
        end
        nil
      end
      
=begin rdoc
As @IO#read@

@raise [IOError] always because the stream is not open for reading
@param [Integer] length unused
@param [String] buffer unused
@return [nil]
=end
      def read length, buffer = nil
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#read_nonblock@

@raise [IOError] always because the stream is not open for reading
@param [Integer] max unused
@param [String] outbuf unused
@return [nil]
=end
      def read_nonblock max, outbuf = nil
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#readbyte@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def readbyte
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#readchar@

@raise [IOError] always because the stream is not open for reading
@return [nil]
=end
      def readchar
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#readline@

@raise [IOError] always because the stream is not open for reading
@param [String] sep unused
@param [Integer] limit unused
@return [nil]
=end
      def readline sep, limit
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#readlines@

@raise [IOError] always because the stream is not open for reading
@param [String] sep unused
@param [Integer] limit unused
@return [nil]
=end
      def readlines sep, limit
        raise IOError, "not opened for reading"
      end

=begin rdoc
As @IO#readpartial@

@raise [IOError] always because the stream is not open for reading
@param [Integer] maxlen unused
@param [String] outbuf unused
@return [nil]
=end
      def readpartial maxlen, outbuf = nil
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#reopen@

@raise [RuntimeError] always
@param [String,IO] a path or another IO. Unused
@param [String] the mode. Unused
@return [nil]
=end
      def reopen arg1, arg2 = 'r'
        raise RuntimeError, "You can\'t reopen #{self.class}"
      end
      
=begin rdoc
As @IO#set_encoding@

This method does nothing. It's only provided for compatibility with @IO@ API
@param [Array<Object>] args the arguments. See @IO#set_encoding@
=end
      def set_encoding *args
      end
      
=begin rdoc
As @IO#stat@

@return [nil] as this class isn't associated with any file
=end
      def stat
        nil
      end

=begin rdoc
As @IO#sysread@

@raise [IOError] always because the stream is not open for reading
@param [Integer] num unused
@param [String] outbuf unused
@return [nil]
=end
      def sysread num, outbuf = nil
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#to_io@

@return [Output] self
=end
      def to_io
        self
      end
      
=begin rdoc
As @IO#ungetbyte@

@raise [IOError] always because the stream is not open for reading
@param [String,Integer] arg unused
@return [nil]
=end
      def ungetbyte arg
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#ungetc@

@raise [IOError] always because the stream is not open for reading
@param [String] str unused
@return [nil]
=end
      def ungetc str
        raise IOError, "not opened for reading"
      end
      
=begin rdoc
As @IO#write@

@param [Object] obj the object to write
@raise [IOError] if the stream has been closed
@return [Integer] the number of written bytes
=end
      def write obj
        if !@closed
          cur = @widget.text_cursor
          cur.move_position Qt::TextCursor::End
          text = obj.to_s
          format = cur.char_format
          format.foreground = @brush
          cur.insert_text text, format
          text.bytes.count
        else raise IOError, 'closed stream'
        end
      end
      alias_method :syswrite, :write
      alias_method :write_nonblock, :write
      
    end

  end
  
end