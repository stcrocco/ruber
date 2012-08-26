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

require 'ruber/plugin_specification'

module Ruber
  
  class ComponentLoader < Qt::Object

=begin rdoc
Finds all the plugins in the given directories

If more than one directory contains a plugin with a given name, only the first
one will be returned.

@param [<String>] dirs the absolute paths of the directories where to look for
  plugins
@param [Boolean] info whether to return the names of the plugins or
    {PluginSpecification} objects describing them
@return [{Symbol=>PluginSpecification}]  a hash having the
    plugin names as keys and the {PluginSpecification} objects containing their introduction as values, if _info_ is *true*
@return [{Symbol=>PluginSpecification}] a hash having the
  plugin names as keys and the path of the plugin files as values, if _info_ is *false*
=end
    def self.find_plugins dirs, info = false
      res = {}
      dirs.each do |dir|
        Dir.entries(dir).sort[2..-1].each do |name|
          next if res[name.to_sym]
          d = File.join dir, name
          file = File.join d, 'plugin.yaml'
          if File.directory?(d) and File.exist?(file)
            if info then 
              res[name.to_sym] = PluginSpecification.intro file
            else res[name.to_sym] = file
            end
          end
        end
      end
      res
    end

    
  end
  
end