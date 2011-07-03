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

require 'yaml'

module Ruber
  
  module YAMLSyntaxChecker
    
    class Plugin < Ruber::Plugin
      
      def initialize psf
        super
        Ruber[:syntax_checker].register_syntax_checker YAMLSyntaxChecker::Checker,
            [], ['*.yaml']
      end
      
      def unload
        Ruber[:syntax_checker].remove_syntax_checker YAMLSyntaxChecker::Checker
      end
      
    end
    
    class Checker
      
      def check_syntax str, format
        begin 
          YAML.parse str
          nil
        rescue ArgumentError => e
          match = e.message.match %r{syntax error on line\s+(-?\d+),\s+col\s+(-?\d+)}i
          return [] unless match
          line = [match[1].to_i, 0].max
          col = [match[2].to_i, 0].max
          [Ruber::SyntaxChecker::SyntaxError.new(line, col, 'Syntax error', 'Syntax error')]
        end
      end
      
    end
    
  end
  
end