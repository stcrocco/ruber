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
  
=begin rdoc
Plugin which automatically inserts an @end@ keyword after the user presses Enter
after a line starting a construct which requires it.

The algorithm used to find out whether an end should be inserted after the current
line is very simple: the line is checked against several possible regexps. The @end@
is inserted if any of the regexps matches.

The above algorithm has the limitation of not being able to tell whether the line
is inside a multiline string or a block comment, and can thus lead to spurious @end@s
being added.

Another problem with the way the plugin works now is that it has no way to know
whether a given keyword already has its closing @end@. To try to lessen this issue,
before inserting an @end@, this plugin checks the indentation of the following line,
comparing it to the indentation of the line where Enter has been pressed. If the
former is greater than the latter, it assumes that the user is editing an already-existing
construct and doesn't insert the @end@.

@note This plugin does nothing unless the text is inserted in the document while
  one of the views associated with it has focus
=end
  module AutoEnd
    
=begin rdoc
Extension object for the Auto End plugin

The procedure of inserting an @end@ is split in two parts, performed in separate
moments:
# finding out whether the current line needs an end inserted after it. This is
  done in response to the {Document#text_inserted} signal
# inserting the text. This is done in response to the {Document#text_changed} signal

The reason for this two-step behaviour is that {Document#text_inserted} is emitted
multiple times in case of a Paste operation. Thus, inserting the @end@ keywords
in it would cause them to be added in the middle of the pasted text, which is
wrong. What we do instead is to analyze each line in response to {Document#text_inserted},
storing the line position and the text to insert if appropriate, overwriting any
other information so that only the last position is recorded. When all text has
been processed, the document emits the {Document#text_changed} signal and, in response
to this we insert the end keyword (if appropriate).
=end
    class Extension < Qt::Object
      
      include Ruber::Extension
      
=begin rdoc
Contains the information about the next insertion to do

@attr [Integer] line_number the number of the line where the insertion should be done
@attr [String] lines the text to insert
@attr [Array(Integer,Integer)] final_position the position to move after the insertion
  The first element is the line number, relative to the insertion line (for example,
  a value of 1 means to move the cursor to the line after the insertion line, while
  a value of -1 means to move it to the line before). The second element is the
  column number. If negative, it's counted from the end of the line
=end
      Insertion = Struct.new :line_number, :lines, :final_position
      
=begin rdoc
The regexp fragment which matches an identifier. In theory, this should
just be @\w+@. However, from ruby 1.9.2, @\w@ only matches ASCII characters, while
identifiers can also contain unicode characters. To allow for this, the @\p{Word}@
character class is used from ruby 1.9.2 onward, while @\w@ is used for previous
versions
=end
      IDENTIFIER_PATTERN = RUBY_VERSION >= '1.9.2' ? '\p{Word}+' : '\w+'
      
=begin rdoc
The regexp fragment which matches a multiple identifier (that is, an identifier
maybe followed by several other identifiers separated by @::@)
=end
      MULTI_ID_PATTERN = "#{IDENTIFIER_PATTERN}(?:::#{IDENTIFIER_PATTERN})*"
      
=begin rdoc
The patterns used to find out whether an @end@ keyword should be inserted after
a line.

Each entry is itself an array with three elements:
* the regexp to match agains the line
* the text to insert if the regexp match
* an array with two elements, representing the position where the cursor should be
  moved to after the insertion, as described in {Insertion#final_position}
=end
      PATTERNS = [
        [/^\s*if\s/, "\nend", [0, -1]],
        [/=\s*if\s/, "\nend", [0, -1]],
        [/^\s*unless\s/, "\nend", [0, -1]],
        [/=\s*unless\s/, "\nend", [0, -1]],
        [/\bdo\s*$/, "\nend", [0, -1]],
        [/\bdo\s+\|/, "\nend", [0, -1]],
        [/^\s*def\s/, "\nend", [0, -1]],
        [/^class\s+#{IDENTIFIER_PATTERN}\s*$/, "\nend", [0, -1]],
        [/^class\s+#{MULTI_ID_PATTERN}\s*<{1,2}\s*#{MULTI_ID_PATTERN}\s*$/, "\nend", [0, -1]],
        [/^\s*module\s+#{MULTI_ID_PATTERN}\s*$/, "\nend", [0,-1]],
        [/^\s*while\s/, "\nend", [0,-1]],
        [/^\s*until\s/, "\nend", [0,-1]],
#         [/^=begin(\s|$)/, "\n=end", [0, -1]],
        [/^\s*begin\s/, "\nend", [0, -1]],
        [/=\s*begin\s/, "\nend", [0, -1]],
        [/^\s*for\s+#{IDENTIFIER_PATTERN}\s+in.+$/, "\nend", [0,-1]],
        [/=\s*for\s+#{IDENTIFIER_PATTERN}\s+in.+$/, "\nend", [0,-1]]
      ]
      
=begin rdoc
@param [DocumentProject] prj the project associated with the document
=end
      def initialize prj
        super
        @doc = prj.document
        @insertion = nil
        connect_slots
      end
      
      private
=begin rdoc
Slot called when some text is inserted

If one of the recognized patterns match the current line, memorizes an {Insertion}
object pointing to the current line and using the parameters associated with the
matching pattern.

If the inserted text doesn't end in a newline, nothing is done.

If the current line doesn't match any pattern, the currently memorized insertion
position (if any) is forgotten
@param [KTextEditor::Range] the range corresponding to the inserted text
=end
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
        nil
      end
      slots 'text_inserted(KTextEditor::Range)'
      
=begin rdoc
Slot called in response to the {Document#text_changed} signal

If there's an insertion position memorized, inserts the corresponding text after
the current line, then moves the cursor to the position stored with the insertion
object.

The current insertion is forgotten.
@return [nil]
=end
      def text_changed
        if @insertion
          insert_text KTextEditor::Cursor.new(@insertion.line_number, 0), 
              @insertion.lines, @insertion.final_position
          @insertion = nil
        end
      end
      slots :text_changed
      
=begin rdoc
Override of {Extension#remove_from_project}
@return [nil]
=end
      def remove_from_project
        disconnect_slots
      end
      
=begin rdoc
Makes connections to the document's signals
@return [nil]
=end
      def connect_slots
        connect @doc, SIGNAL('text_inserted(KTextEditor::Range, QObject*)'), self, SLOT('text_inserted(KTextEditor::Range)')
        connect @doc, SIGNAL('text_changed(QObject*)'), self, SLOT(:text_changed)
        nil
      end
      
=begin rdoc
Disconnects connections to the document's signals
@return [nil]
=end
      def disconnect_slots
        disconnect @doc, SIGNAL('text_inserted(KTextEditor::Range, QObject*)'), self, SLOT('text_inserted(KTextEditor::Range)')
        disconnect @doc, SIGNAL('text_changed(QObject*)'), self, SLOT(:text_changed)
      end
      
=begin rdoc
Inserts text at the given position and moves the cursor to the specified position

To avoid the possibility of infinite recursion, before inserting text {#disconnect_slots}
is called. After the text has been inserted {#connect_slots} is called.

@note nothing is done unless the active view (according to {Document#active_view})
  is associated with the document
@param [KTextEditor::Cursor] insert_pos the position where the text should be inserted
@param [String] lines the text to insert
@param [Array(Integer,Integer)] dest the position to move the cursor to, relative
  to the insertion position, as described in {Insertion#final_position}
=end
      def insert_text insert_pos, lines, dest
        view = @doc.active_view
        return unless view
        disconnect_slots
        replace_pos = KTextEditor::Cursor.new insert_pos.line, @doc.line_length(insert_pos.line)
        insert_pos.column = @doc.line_length insert_pos.line
        @doc.insert_text insert_pos, lines 
        final_pos = KTextEditor::Cursor.new insert_pos.line + lines.size - 1,
            lines[-1].size
        view.execute_action 'tools_align'
        dest_line = insert_pos.line+dest[0]
        dest_col = dest[1]
        dest_col += @doc.line_length(dest_line) + 1 if dest_col < 0
        view.go_to dest_line, dest_col
        connect_slots
      end
      
    end
    
  end
  
end