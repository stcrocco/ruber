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
require 'facets/kernel/deep_copy'

require 'ruber/plugin_specification'
require 'ruber/component_loader_helpers'

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
    
=begin rdoc
Replaces dependencies on features with dependencies on the plugins which provide them

@param [<PluginSpecification>] psfs the plugins whose dependencies should be
  replaced
@param [<PluginSpecification>] extra a list of plugins having where features
  can be found but whose dependencies shouldn't be replaced (for example, they
  can be plugins which have already been loaded)
@return [<PluginSpecification>] a list containing copies of the elements of _psfs_
  with the dependencies corrected
@raise [UnresolvedDep] if some plugins depended on features provided by no plugin
=end
    def self.resolve_features psfs, extra = []
      features = (psfs+extra).inject({}) do |res, pl|
        pl.features.each{|f| res[f] = pl.name}
        res
      end
      missing = Hash.new{|h, k| h[k] = []}
      new_psfs = psfs.map do |pl|
        res = pl.deep_copy
        res.deps = pl.deps.map do |d| 
          f = features[d]
          missing[pl.name] << d unless f
          f
        end.uniq.compact
        res
      end
      raise UnresolvedDep.new Hash[missing] unless missing.empty?
      new_psfs
    end

=begin rdoc
Finds all the dependencies for the given plugins choosing among a list
  
@param [<PluginSpecification>] to_load the plugins to find dependencies for
@param [<PluginSpecification>] availlable other plugins which can be used to
  satisfy dependencies of _to_load_
@return (see DepsSolver#solve)
@raise (see DepsSolver#solve)

@see DepsSolver#solve
=end
    def self.fill_dependencies to_load, availlable
      solver = DepsSolver.new to_load, availlable
      solver.solve
    end
    
=begin rdoc
Sorts the given plugin in dependency order

The plugins are sorted so that a plugin comes after any other plugin it depends
on.

@param [<PluginSpecification>] psfs the plugins to sort. It must contain all
  the needed plugins (that is, this method won't search for plugins needed to
  satisfy dependencies: it assumes this has already been done and all plugins
  are included in this array)
@param [<Symbol,PluginSpecification>] known a list of plugins or list of feature
  names which can be used
  to satisfy dependencies. For example, they may be plugins which have already
  been loaded
@return [<PluginSpecification>] the same plugins contained in _psfs_ so that
  every plugin in the array only depends on those preceding it and never depends
  on those following it
@raise [UnresolvedDep] if any plugin in _psfs_ has a dependency which can't be
  satisfied neither by other plugins in _psfs_ nor by plugins in _known_
@raise [CircularDep] if there are circular dependencies between plugins
=end
    def self.sort_plugins psfs, known = []
      PluginSorter.new( psfs, known ).sort_plugins
    end
    
  end
  
end