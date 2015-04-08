=begin 
    Copyright (C) 2012 by Stefano Crocco   
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
  
  class ProjectedDocument
    
    attr_reader :document
    
    attr_reader :environment
    
    def initialize doc, env
      @document = doc
      @environment = env
    end
    
    def same_document? other
      if other.is_a?(ProjectedDocument) then @document == other.document
      else @document == other
      end
    end
    
    def own_project
      @document.own_project @environment
    end
    
    def project
      @document.project @environment
    end
    
    def extension name
      @document.extension name, @environment
    end
    
    def create_view parent = nil
      @document.create_view @environment, parent
    end
    
    def method_missing name, *args, &blk
      @document.send name, *args, &blk
    end
    
  end
  
end