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
  
  module AutoEnd
    
    class Extension < Qt::Object
      
      include Ruber::Extension
      
      Insertion = Struct.new :line_number, :lines, :final_position
      
      IDENTIFIER_PATTERN = RUBY_VERSION >= '1.9.2' ? '\p{Word}+' : '\w+'
      
      MULTI_ID_PATTERN = "#{IDENTIFIER_PATTERN}(?:::#{IDENTIFIER_PATTERN})*"
      
      PATTERNS = [
        [/^\s*if\s/, "\nend", [0, -1]],
        [/=\s*if\s/, "\nend", [0, -1]],
        [/\bdo\s*$/, "\nend", [0, -1]],
        [/\bdo\s+\|/, "\nend", [0, -1]],
        [/^\s*def\s/, "\nend", [0, -1]],
        [/^class\s+#{IDENTIFIER_PATTERN}\s*$/, "\nend", [0, -1]],
        [/^class\s+#{MULTI_ID_PATTERN}\s*<{1,2}\s*#{MULTI_ID_PATTERN}\s*$/, "\nend", [0, -1]],
        [/^\s*module\s+#{MULTI_ID_PATTERN}\s*$/, "\nend", [0,-1]],
        [/^=begin(\s|$)/, "\n=end", [0, -1]],
        [/^\s*begin\s/, "\nend", [0, -1]],
        [/=\s*begin\s/, "\nend", [0, -1]],
      ]
      
      def initialize prj
        super
        @doc = prj.document
        @insertion = nil
        connect_slots
      end
      
      def text_inserted range
        text = @doc.text range
        return unless text.end_with? "\n"
        @insertion = nil
        line = @doc.line( range.end.line - 1)
        pattern = PATTERNS.find{|pat| pat[0].match line}
        if pattern and !line.start_with? '#'
          indentation = line.match(/^\s*/)[0].size
          next_indentation = @doc.line(range.end.line + 1).match(/^\s*/)[0].size
          unless next_indentation > indentation
            @insertion = Insertion.new range.end.line, pattern[1], pattern[2]
          end
        end
      end
      slots 'text_inserted(KTextEditor::Range)'
      
      def text_changed
        if @insertion
          insert_text KTextEditor::Cursor.new(@insertion.line_number, 0), 
              @insertion.lines, @insertion.final_position
          @insertion = nil
        end
      end
      slots :text_changed
      
      def remove_from_project
        disconnect_slots
      end
      
      private
      
      def connect_slots
        connect @doc, SIGNAL('text_inserted(KTextEditor::Range, QObject*)'), self, SLOT('text_inserted(KTextEditor::Range)')
        connect @doc, SIGNAL('text_changed(QObject*)'), self, SLOT(:text_changed)
      end
      
      def disconnect_slots
        disconnect @doc, SIGNAL('text_inserted(KTextEditor::Range, QObject*)'), self, SLOT('text_inserted(KTextEditor::Range)')
        disconnect @doc, SIGNAL('text_changed(QObject*)'), self, SLOT(:text_changed)
      end
      
      def insert_text insert_pos, lines, dest
        view = @doc.active_view
        return unless view
        disconnect_slots
        replace_pos = KTextEditor::Cursor.new insert_pos.line, @doc.line_length(insert_pos.line)
        insert_pos.column = @doc.line_length insert_pos.line
        @doc.insert_text insert_pos, lines 
        final_pos = KTextEditor::Cursor.new insert_pos.line + lines.size - 1,
            lines[-1].size
        do_indentation view
        dest_line = insert_pos.line+dest[0]
        dest_col = dest[1]
        dest_col += @doc.line_length(dest_line) + 1 if dest_col < 0
        view.go_to dest_line, dest_col
        connect_slots
      end
      
      def do_indentation view
        view.execute_action 'tools_align'
      end
      
    end
    
  end
  
end