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
@api extension environment
@api_method #tabs
@api_method #views
@api_method #documents
=end
  class Environment
    
    include Extension
    
=begin rdoc
@return [MainWindow::ViewManager] the view manager associated with the environment
=end
    attr_accessor :view_manager
    
=begin rdoc
@param [Project] prj the project the extension is associated with
=end
    def initialize prj
      @project = prj
      @view_manager = nil
    end
    
=begin rdoc
The tabs living in the environment
@return [Array<Pane>] a list of the tabs contained in the environment
@raise [NoMethodError] unless a view manager has been associated with the environment
=end
    def tabs
      @view_manager.tabs.to_a
    end

=begin rdoc
The views living in the environment

@overload views
  @return [Array<EditorView>] a list of all the views living in the environment,
    in activation order (from recently activated to less recently activated)
  @raise [NoMethodError] unless a view manager has been associated with the environment
@overload views doc
  @param [Document] doc
  @return [Array<EditorView>] a list of all the views associated with the given document
    living in the environment, in activation order (from recently activated to
    less recently activated)
  @raise [NoMethodError] unless a view manager has been associated with the environment
=end
    def views doc = nil
      if doc then @view_manager.activation_order.select{|v| v.document == doc}
      else @view_manager.activation_order.dup
      end
    end
    
=begin rdoc
@return [Array<Document>] the documents living in the environment
@raise [NoMethodError] unless a view manager has been associated with the environment
=end
    def documents
      @view_manager.views.map{|v| v.document}.uniq
    end
    
  end
  
end