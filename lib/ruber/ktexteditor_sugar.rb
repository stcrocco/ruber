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
    
    def inspect
      "<#{self.class}:#{object_id} line=#{line} column=#{column}"
    end
    
    def == other
      return false unless other.is_a? KTextEditor::Cursor
      line == other.line and column == other.column
    end
    
    def dup
      self.class.new self.line, self.column
    end
    
    def clone
      res = self.class.new self.line, self.column
      res.freeze if self.frozen?
      res
    end
    
  end
  
end