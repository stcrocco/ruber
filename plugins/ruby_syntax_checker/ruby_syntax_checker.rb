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
    
    SyntaxError = Struct.new :line, :column, :message, :formatted_message, :error_type
    
    class Plugin < Ruber::Plugin
      
      def initialize psf
        super
        Ruber[:syntax_checker].register_syntax_checker RubySyntaxChecker::Checker, ['application/x-ruby'],
            %w[*.rb rakefile Rakefile]
      end

      def unload
        Ruber[:syntax_checker].remove_syntax_checker RubySyntaxChecker::Checker
      end

    end
    
    class Checker
      
      SPECIAL_ERROR_STRINGS = [
        'unmatched close parenthesis:',
        'end pattern with unmatched parenthesis:',
        'unknown regexp option -',
        'class|module definition in method body',
        'dynamic constant assignment',
        'unterminated string meets end of file',
        'premature end of char-class:'
      ]
      
      ERROR_TYPES=[
        [/\bexpecting (?:keyword_end|kEND)/, :missing_end],
        [/\bunexpected (?:keyword_end|kEND),\s+expecting \$end/, :extra_end],
        [/\bexpecting '\)/, :missing_close_paren],
        [/\bunexpected '\)/, :extra_close_paren],
        [/\bexpecting '\]'/, :missing_close_bracket],
        [/\bunexpected '\]/, :extra_close_bracket],
        [/\bexpecting '\}'/, :missing_close_brace],
        [/\bunexpected '\}/, :extra_close_brace],
        [/\bunexpected (?:keyword_else|kELSE)/, :extra_else],
        [/\bunexpected (?:keyword_when|kWHEN)/, :extra_when],
        [/\bunexpected (?:keyword_rescue|kRESCUE)/, :extra_rescue],
        [/\bunexpected (?:keyword_ensure|kENSURE)/, :extra_ensure],
        [/\bunterminated string/, :missing_quote],
        [/\bunexpected (?:keyword_end|kEND)/, :misplaced_end],
        [/end pattern with unmatched parenthesis/, :missing_regexp_close_paren],
        [/unmatched close parenthesis/, :extra_regexp_close_paren],
        [/premature end of char-class/, :missing_regexp_close_bracket],
        [/unknown regexp option/, :unknown_regexp_option],
        [/dynamic constant assignment/, :dynamic_constant_assignment],
      ]
      
      def initialize doc
        @doc = doc
        @regexp = %r{^-e:(\d+):\s+(?:syntax error,|(#{SPECIAL_ERROR_STRINGS.join '|'}))(?:\s+(.*)|$)}
      end
      
      def check_syntax text, formatted
        ruby = Ruber[:ruby_development].interpreter_for @doc
        begin
          msg = Open3.popen3(ruby, '-c', '-e', text) do |in_s, out_s, err_s|
            error = err_s.read
            out_s.read.strip != 'Syntax OK' ? error : ''
          end
        rescue SystemCallError
          raise Ruber::SyntaxChecker::SyntaxNotChecked
        end
        parse_output msg, formatted
      end
      
      private
      
      def parse_output str, formatted
        # The inner array is needed in case the first message doesn\'t use a
        # recognized format (for example, regexp syntax errors don\'t have a standard
        # format). Without this, in the lins cycle, the else clause would be
        # executed and would fail because the error_lines array is empty.
        error_lines = [ [ [] ] ]
        lines = str.split_lines
        return if lines.empty?
        lines.each do |l|
          if l.match @regexp
            error = [[$2 ? "#{$2} #{$3}" : $3], $1.to_i - 1]
            error_type = ERROR_TYPES.find{|a| a[0] =~ l}
            error << error_type[1] if error_type
            error_lines << error
          else error_lines[-1][0] << l
          end
        end
        error_lines.shift if error_lines.first.first.empty?
        errors = error_lines.map do |a, number, type|
          error = SyntaxError.new number, nil, a.shift, nil, type
          a.each_with_index do |l, i|
            if l.match %r{^\s*\^\s*$} 
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
            msg.gsub! /expect(ed|ing)\s+\$end/, 'expect\1 end of file'
            msg.gsub! /expect(ed|ing)\s+kEND/, 'expect\1 `end` keyword'
            msg.gsub! /expect(ed|ing)\s+keyword_end/, 'expect\1 `end` keyword'
            error.formatted_message = msg
          else error.formatted_message = error.message.dup
          end
          error
        end
        errors
      end
      
    end
      
  end
  
end
