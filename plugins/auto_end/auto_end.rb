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
      
      IDENTIFIER_PATTERN = RUBY_VERSION >= '1.9.2' ? '\p{Word}+' : '\w+'
      
      MULTI_ID_PATTERN = "#{IDENTIFIER_PATTERN}(?:::#{IDENTIFIER_PATTERN})*"
      
      PATTERNS = [
        [/^\s*if\s/, ['', 'end'], [0, -1]],
        [/=\s*if\s/, ['', 'end'], [0, -1]],
        [/\bdo\s*$/, ['', 'end'], [0, -1]],
        [/\bdo\s+\|/, ['', 'end'], [0, -1]],
        [/^\s*def\s/, ['', 'end'], [0, -1]],
        [/^class\s+#{IDENTIFIER_PATTERN}\s*$/, ['', 'end'], [0, -1]],
        [/^class\s+#{MULTI_ID_PATTERN}\s*<{1,2}\s*#{MULTI_ID_PATTERN}\s*$/, ['', 'end'], [0, -1]],
        [/^\s*module\s+#{MULTI_ID_PATTERN}\s*$/, ['', 'end'], [0,-1]],
        [/^\s*begin\s/, ['', 'end'], [0, -1]],
        [/=\s*begin\s/, ['', 'end'], [0, -1]],
      ]
      
      def initialize prj
        super
        @doc = prj.document
        connect_slots
      end
      
      def insert_end_if_needed range
        text = @doc.text range
        return unless text.end_with? "\n"
        line = @doc.line( range.end.line - 1)
        pattern = PATTERNS.find{|pat| pat[0].match line}
        if pattern
          return if line.start_with? '#'
          insert_text KTextEditor::Cursor.new(range.end.line,0), pattern[1], 
            pattern[2]
        end
      end
      slots 'insert_end_if_needed(KTextEditor::Range)'
      
      def remove_from_project
        disconnect_slots
      end
      
      private
      
      def connect_slots
        connect @doc, SIGNAL('text_inserted(KTextEditor::Range, QObject*)'), self, SLOT('insert_end_if_needed(KTextEditor::Range)')
      end
      
      def disconnect_slots
        disconnect @doc, SIGNAL('text_inserted(KTextEditor::Range, QObject*)'), self, SLOT('insert_end_if_needed(KTextEditor::Range)')
      end
      
      def insert_text insert_pos, lines, dest
        view = @doc.active_view
        return unless view
        disconnect_slots
        @doc.insert_text insert_pos, lines 
        final_pos = KTextEditor::Cursor.new insert_pos.line + lines.size - 1,
            lines[-1].size
        end_pos = KTextEditor::Cursor.new(final_pos.line - 1, 0)
        end_pos.column = @doc.line_length(end_pos.line)
        new_sel = KTextEditor::Range.new insert_pos, end_pos
        do_indentation view, new_sel
        dest_line = insert_pos.line+dest[0]
        dest_col = dest[1]
        dest_col += @doc.line_length(dest_line) + 1 if dest_col < 0
        view.go_to dest_line, dest_col
        connect_slots
      end
      
      def do_indentation view, range
        old_sel = view.selection_range
        view.selection = range
        view.execute_action 'tools_align'
        view.selection = old_sel
      end
      
    end
    
  end
  
end