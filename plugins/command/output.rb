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
    
    class Output
      
      def initialize widget, color
        @widget = widget
        @close_on_exec = false
        @closed = false
        @sync = true
        @brush = Qt::Brush.new color
      end
      
      attr_accessor :sync
      
      def binmode
      end
      
      def binmode?
        true
      end
      
      def bytes
        each_byte
      end
      
      def chars
        each_char
      end
      
      def close
      end
      
      def close_on_exec= val
        @close_on_exec = val.to_bool
      end
      
      def close_on_exec?
        @close_on_exec
      end
      
      def close_read
        raise IOError, 'closing non-duplex IO for reading'
      end
      
      def close_write
      end
      
      def closed?
        @closed
      end
      
      def each
        raise IOError, "not opened for reading" if block_given?
        to_enum
      end
      
      def each_byte
        raise IOError, "not opened for reading" if block_given?
        to_enum :each_byte
      end
      
      def each_char
        raise IOError, "not opened for reading" if block_given?
        to_enum :each_char
      end
      
      def each_line sep
        raise IOError, "not opened for reading" if block_given?
        to_enum :each_line
      end
      
      def eof
        raise IOError, "not opened for reading"
      end
      
      def eof?
        raise IOError, "not opened for reading"
      end
      
      def external_encoding
        nil
      end
      
      def fileno
        1
      end
      
      def flush
        self
      end
      
      def getbyte
        raise IOError, "not opened for reading"
      end
      
      def getc
        raise IOError, "not opened for reading"
      end
      
      def gets
        raise IOError, "not opened for reading"
      end
      
      def internal_encoding
        nil
      end
      
      def isatty
        false
      end
      alias_method :tty?, :isatty
      
      def lineno
        raise IOError, "not opened for reading"
      end
      
      def lineno= val
        raise IOError, "not opened for reading"
      end
      
      def lines
        each_line
      end
      
      def pid
        nil
      end
      
      def print *args
        args = [$_] if args.empty?
        args.each{|a| write a}
        STDOUT.write $\
          write $\ if $\
          nil
      end
      
      def printf format_string, *args
        str = sprintf format_string, *args
        write str
      end
      
      def putc obj
        if obj.is_a? Numeric then write obj.floor.chr
        else obj.to_s.each_char.to_a[0]
        end
      end
      
      def puts *args
        args << '' if args.empty?
        args.each do |a|
          a = a.to_s
          write a
          write "\n" unless a.end_with? "\n"
        end
      end
      
      def read length, buffer
        raise IOError, "not opened for reading"
      end
      
      def read_nonblock max, outbuf = nil
        raise IOError, "not opened for reading"
      end
      
      def readbyte
        raise IOError, "not opened for reading"
      end
      
      def readchar
        raise IOError, "not opened for reading"
      end
      
      def readline sep, limit
        raise IOError, "not opened for reading"
      end
      
      def readlines sep, limit
        raise IOError, "not opened for reading"
      end
      
      def readpartial maxlen, outbuf = nil
        raise IOError, "not opened for reading"
      end
      
      def reopen arg1, arg2
      end
      
      def set_encoding *args
      end
      
      def stat
        nil
      end
      
      def sysread *arg
        raise IOError, "not opened for reading"
      end
      
      def << text
        write text
        self
      end
      
      def to_io
        self
      end
      
      def ungetbyte arg
        raise IOError, "not opened for reading"
      end
      
      def ungetc str
        raise IOError, "not opened for reading"
      end
      
      def write obj
        if !@closed
          cur = @widget.text_cursor
          cur.at_end
          text = obj.to_s
          format = cur.char_format
          format.foreground = @brush
          cur.insert_text text, format
          text.bytes.count
        else 0
        end
      end
      alias_method :syswrite, :write
      alias_method :write_nonblock, :write
      
    end

  end
  
end