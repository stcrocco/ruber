=begin 
    Copyright (C) 2010, 2011 by Stefano Crocco   
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
  
  module RubySyntaxChecker
    
    class Plugin < Ruber::Plugin
      
      def initialize psf
        super
        Ruber[:syntax_checker].register_syntax_checker RubySyntaxChecker::Checker, ['application/x-ruby'],
            %w[*.rb rakefile Rakefile]
      end
      
    end
    
    class Checker
      
      def initialize doc
        @doc = doc
      end
      
      def check_syntax text, formatted
        ruby = Ruber[:ruby_development].interpreter_for @doc
        msg = Open3.popen3(ruby, '-c', '-e', text) do |in_s, out_s, err_s|
          error = err_s.read
          error.gsub! %r{^-e(?=:\d+:\s+syntax error,)}, @doc.path
          out_s.read.strip != 'Syntax OK' ? error : ''
        end
        parse_output msg, formatted
      end
      
      private
      
      def parse_output str, formatted
        error_lines = []
        lines = str.split_lines
        return if lines.empty?
        lines.each do |l|
          if l.match(/^#{Regexp.quote(@doc.path||'-e')}:(\d+):\s+syntax error,\s+(.*)/)
            error_lines << [$1.to_i - 1, [$2]]
          else error_lines[-1][1] << l
          end
        end
        errors = error_lines.map do |number, a|
          error = Ruber::SyntaxChecker::SyntaxError.new number, nil, a.shift
          a.each_with_index do |l, i|
            if l.match %r{^\s*^\s*$} 
              error.column = l.index '^'
              previous_line = a[i-1]
              if previous_line and previous_line.match /^\.{3}/
                offset = ( @doc.line(error.line) =~ /#{Regexp.quote(previous_line[3..-1])}/)
                error.column += offset if offset
              end
            else error.message << "\n" << l
            end
          end
          if formatted
            msg = error.message.dup
            msg.gsub! '$end', 'end of file'
            msg.gsub! 'kend', '`end` keyword'
            msg.gsub! 'keyword_end', '`end` keyword'
            error.formatted_message = msg
          end
          error
        end
        errors
      end
      
    end
      
  end
  
end