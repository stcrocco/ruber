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

begin require 'yard'
rescue LoadError
end


module Ruber
  
=begin rdoc
Plugin to parse ruby code. The parsing is performed using YARD, which should be
installed when the plugin is used.
@api feature ruby_parser
@plugin
=end
  module RubyParser
    
=begin rdoc
Plugin class for the @Ruby parser@ plugin
@api feature ruby_parser
@api_method #parse
=end
    class Plugin < Ruber::Plugin
      
=begin rdoc
Parses some ruby code

@param [String,#read] obj the object containing the code to parse. If it's a string,
  the content of the string will be parsed. If it's an object with a @#read@ method,
  that method will be called to obtain the code string
@return [YARD::CodeObjects::RootObject,nil] the root object of the code or *nil*
  if it wasn't possible to load YARD
=end
      def parse obj
        str = obj.respond_to?(:read) ? obj.read : obj
        begin 
          ast = YARD::Parser::SourceParser.parse_string(str, :ruby).parse.root
          prc = YARD::Handlers::Processor.new nil, false, :ruby
          prc.process(ast)
          prc.owner
        rescue NameError
          nil
        end
      end
      
    end
    
  end
  
end