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

require 'korundum4'
require 'ktexteditor'

module KTextEditor
  
  class Cursor
    
=begin rdoc
Override of @Object#inspect@

@return [String] a string representation of the cursor which displays line and column
  number
=end
    def inspect
      if !disposed?
        "<#{self.class}:#{object_id} line=#{line} column=#{column}>"
      else "<#{self.class}:#{object_id} DISPOSED>"
      end
    end
    
=begin rdoc
Override of @Object#==@

@param [Object] other the object to compare with *self*
@return [Boolean] *true* if _other_ is a @KTextEditor::Cursor@ with the same line
  and column number and *false* otherwise
=end
    def == other
      return false unless other.is_a? KTextEditor::Cursor
      line == other.line and column == other.column
    end
    
=begin rdoc
Override of @Object#dup@

@return [Cursor] a {Cursor} with the same line and column number
=end
    def dup
      self.class.new self.line, self.column
    end

=begin rdoc
Override of @Object#clone@

@return [Cursor] a {Cursor} with the same line and column number
=end
    def clone
      res = dup
      res.freeze if self.frozen?
      res
    end
    
  end
  
  class Range
   
=begin rdoc
Override of @Object#inspect@

@return [String] a string representation of the cursor which displays the
  start and end line and column
=end
    def inspect
      return "<#{self.class}:#{object_id} DISPOSED>" if disposed?
      start_c = self.start
      end_c = self.end
      "<#{self.class}:#{object_id} start=(#{start_c.line};#{start_c.column}) end=(#{end_c.line};#{end_c.column})>"
    end

=begin rdoc
Override of @Object#==@

@param [Object] other the object to compare with *self*
@return [Boolean] *true* if _other_ is a @KTextEditor::Range@ with the same start
  and end and *false* otherwise
=end
    def == other
      return false unless other.is_a? KTextEditor::Range
      start == other.start and self.end == other.end
    end

=begin rdoc
Override of @Object#dup@

@return [Range] a {Range} with the same start and end
=end
    def dup
      self.class.new self.start, self.end
    end

=begin rdoc
Override of @Object#clone@

@return [Range] a {Range} with the same start and end
=end
    def clone
      res = dup
      res.freeze if self.frozen?
      res
    end
    
  end
  
end