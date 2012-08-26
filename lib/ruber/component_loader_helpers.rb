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
   
=begin rdoc
Helper class used to resolve dependencies among plugins. It is used by
{Ruber::ComponentManager.sort_plugins Ruber::ComponentManager.sort_plugins}.
=end
  class PluginSorter
  
=begin rdoc
@param [<PluginSpecification>] psf the specifications of the plugins to sort
@param [<PluginSpecification,Symbol>] ignored a list of dependencies which can
be considered satisfied even if they're not included in _psfs_. Usually, this
array contains plugins which have already been loaded
  
@note _psfs_ should contain dependencies in terms of actual plugins, not of features
=end
  def initialize psfs, ignored = []
    @psfs = {}
    @plugins = {}
    psfs.each do |i|
      @psfs[i.name] = i
      @plugins[i.name] = i.deps
    end
    @ignored = ignored.map{|i| i.is_a?(OpenStruct) ? i.name : i}
    @ready = []
    @deps = {}
  end

=begin rdoc
Sorts the plugins

@return [<PluginSpecification>] an array containing the plugins to be loaded
sorted so that a plugin comes after those it depends upon. Dependencies
on ignored plugins aren't taken into account
@raise [Ruber::ComponentManager::UnresolvedDep] if some plugins have unsatisfied
dependencies
@raise [Ruber::ComponentManager::CircularDep] if there are circuolar dependencies 
among the plugins (that is, @A@ depends on @B@ and @B@ depends, directly or
indirectly, on @A@)
=end
  def sort_plugins
    @plugins.each_value do |v|
      v.reject!{|d| @ignored.include? d}
    end
    unknown = find_unknown_deps
    raise ComponentManager::UnresolvedDep.new unknown unless unknown.empty?
    circular = @plugins.keys.inject([]){ |res, plug|  res + find_dep( plug ) }
    raise ComponentManager::CircularDep.new(circular.uniq) unless circular.empty?
    deps = @deps.reject{|k, v| v.nil? }
    res = []
    old_size = deps.size
    until deps.empty?
      ready = deps.select{|k, v| v.empty?}.map{|i| i[0]}.sort_by{|i| i.to_s}
      res += ready
      ready.each do |i|
        deps.each{|d| d[1].delete i}
        deps.delete i
      end
      raise "Circular deps (this shouldn't happen)" unless old_size > deps.size
      old_size = deps.size
    end
    res.map{|i| @psfs[i]}
  end

  private
  
=begin rdoc

Checks whether all the dependencies among the plugins are statisfied

A dependency can be satisfied either by one of the plugins to sort or by one
of the plugins to ignore.

@return [{Symbol => <Symbol>}] an empty hash if all dependencies were satisfied.
If some plugins have dependencies which aren't either in the plugin list
nor in the list of plugins to ignore, the hash has the names of the plugins
with unsatisfied dependencies as keys and arrays with the names of the missing
dependencies as values
=end
  def find_unknown_deps
    known = @plugins.keys
    res = Hash.new{|h, k| h[k] = []}
    known.each do |i|
      missing_deps = @plugins[i] - known
      missing_deps.each{|d| res[d] << i}
    end
    res
  end
  
=begin rdoc
Finds the dependencies of a plugin

To do this, it calls itself recursively for each of the direct dependencies of
the plugin. The dependencies found are stored in the @@deps@ hash. 
  
To avoid an endless loop or a @SystemStackError@ in case of circular dependencies,
each time the method is called, it is also passed a second argument, an array
containing the names of the plugins whose dependencies have lead to that call.
  
If circular dependencies are found, the entry in @@deps@ corresponding 
to the plugin is set to *nil*.

@param [Symbol] plug the name of the plugin whose dependencies are to be found
@param [<Symbol>] stack the chain of dependencies which lead to this
@return [<(Symbol,Symbol)>] an empty array if there isn't no circular dependency 
or an array containing pairs of names of plugins which depend on one another
if there are circular dependencies
=end
  def find_dep plug, stack = []
    direct_deps = @plugins[plug] || []
    circ = []
    deps = []
    circ << plug if stack.include? plug
    direct_deps.each{|d| circ << plug << d if stack.include? d}
    if circ.empty?
      deps = []
      res = direct_deps.each do |d|
        circ += find_dep d, stack + [plug] unless @deps.has_key? d
        deps += @deps[d] + [d] if @deps[d] 
      end
    end
    @deps[plug] = circ.empty? ? deps : nil
    circ
  end
        
end


=begin rdoc
Helper class which contains the methods needed to find all the plugins needed
to satisfy the dependencies of a given set of plugins.

The difference between this class and @PluginSorter@ is that the latter needs
to know all the plugins which should be loaded, while this class performs the job of
finding out which ones need to be loaded.
=end
  class DepsSolver

=begin rdoc
@param [<PluginSpecification>] to_load the plugin specifications corresponding
to the plugin which one wants to load
@param [<PluginSpecification>] availlable a list of all the availlable pluings
=end
    def initialize to_load, availlable
      @to_load = to_load.map{|i| [i.name, i]}.to_h
      @availlable = availlable.map{|i| [i.name, i]}.to_h
      @loaded_features = to_load.inject({}) do |res, i|
        i.features.each{|f| (res[f] ||= []) << i}
        res
      end
      @availlable_plugins = availlable.map{|i| [i.name, i]}.to_h
      @availlable_features = availlable.inject({}) do |res, i|
        i.features.each{|f| (res[f] ||= []) << i}
        res
      end
      # @res is an array containing the result, that is the list of names of
      # the plugins to load to satisfy all dependencies.
      # @deps is a hash containing the reasons for which a given plugin should
      # be loaded. Each key is the name of a plugin, while each value is an array
      # containing the list of plugins directly depending on the key. If the key
      # is in the list of plugins to load (that is in the first argument passed
      # to the constructor), the array contains nil.
      @res = []
      @deps = Hash.new{|h, k| h[k] = []}
    end

=begin rdoc
Tries to resolve the dependencies for the given plugins

If a plugin depends on a feature, a plugin with that name is added to the list
of needed plugins, unless the feature is already provided by either another
dependency or one of the plugins to load.

@return [<Symbol>] a list of the names of the needed plugins (not features)
@raise [UnresolvedDep] if a plugin which needs to be loaded depends on a feature
no other plugin provides
@raise [CircularDep] if there's a circular dependencies among plugins which
need to be loaded (that is, if there are two plugins depending on each other)
=end
    def solve
      errors = {:missing => {}, :circular => []}
      @res = @to_load.values.inject([]) do |r, i| 
        @deps[i.name] << nil
        r + solve_for(i, errors, [])
      end
      if !errors[:missing].empty? then raise UnresolvedDep.new errors[:missing]
      elsif !errors[:circular].empty? then raise CircularDep.new errors[:circular]
      end
      remove_unneeded_deps
      @res
    end
    
    private

=begin rdoc
Finds all the dependencies for a given plugin

@param [PluginSpecification] pl the plugin specification for the plugin to finds
the dependencies for
@param [{:circular => Array, :missing => {Symbol => <Symbol>}}] errors a hash where to store
errors. Circular dependencis are stored under the @:circular@ key as pairs
of plugins depending on each other. Missing dependencies errors are stored
under the @:missing@ keys, with the keys being the names of the plugins which
have missing depenencies and the values arrays containing the names of the
missing dependencies.

This hash will be modified by this method
@param [<Symbol>] stack the names of the plugins whose dependencies are being
solved. It's used to find circular dependencies. For example, if it the array
is: <tt>[:a, :b, :c]</tt>, it means that we're resolving the dependencies
of the plugin :c, which is a dependency of the plugin :b, which is a dependency
of the plugin :a. If the name of the plugin _pl_ is @:a@, @:b@ or @:c@, then
we know there's a circular dependency.

@note@ this method doesn't raise exceptions if there are circular or missing
dependencies. Rather, it adds them to _errors_ and goes on (this means that it
skips both missing and circular dependencies).
@return [<Symbol>] a list of all the dependencies for _pl_
=end
    def solve_for pl, errors, stack
      deps = []
      if stack.include? pl.name
        errors[:circular] << [stack.at(stack.index(pl.name + 1)), pl.name]
        return deps
      end
      stack << pl.name
      unless pl.deps.empty?
        pl.deps.each do |dep|
          next if @loaded_features.include? dep
          new_pl = @availlable_plugins[dep]
          if new_pl
            deps << dep
            @deps[dep] << pl.name
            deps += solve_for new_pl, errors, stack
          else
            (errors[:missing][dep] ||= []) << pl.name
            return []
          end
        end
      end
      stack.pop
      deps
    end

=begin rdoc
Removes from the dependencies list plugins which aren't truly needed

Given how dependency solving works, it is possible that a plugin has been included
in the dependency list to satisfy a dependency on a given feature, but later
another plugin providing the same feature has been required by another plugin.
In this case, the former plugin (and all those it depends upon, if they're now
unneeded) is removed from the dependency list.

@return [nil]
=end
    def remove_unneeded_deps
      h = Hash.new{|hash, k| hash[k] = []}
      #A hash having the features as keys and the plugins providing them
      #as values
      deps_features = @res.inject(h) do |res, i|
        @availlable_plugins[i].features.each{|f| res[f] << i}
        res
      end
      to_delete = @res.find{|i| !@deps[i].include?(nil) and !deps_features[i].uniq.only? i}
      until to_delete.nil?
        @res.delete to_delete
        deps_features.each_value{|i| i.delete to_delete}
        new = deps_features[to_delete]
        @deps[new] += @deps[to_delete]
        @deps.delete to_delete
        @deps.each_value{|i| i.delete to_delete}
        to_delete = @res.find{|i| !@deps.include?(nil) and !deps_features[i].only? i}
        to_delete = @deps.find{|k, v| v.empty?}[0] rescue nil unless to_delete
      end
      nil
    end
    
  end

=begin rdoc
Exception representing an error while resolving dependencies
=end
class DependencyError < RuntimeError
end

=begin rdoc
Exceptiong raised when a plugin has a missing dependency
=end
  class UnresolvedDep < DependencyError
    
=begin rdoc
The missing dependencies

@return [{Symbol => <Symbol>}] the missing dependencies. The hash has the names
of the plugins whose dependencies couldn't be satisfied as keys, and an array
with the names of the missing dependencies as values
=end
    attr_reader :missing
    
=begin rdoc
@param [{Symbol => <Symbol>}] missing the missing dependencies, as in {#missing}
=end
    def initialize missing
      @missing = Hash[missing]
      text = @missing.map do |k, v|
        "#{k} (needed by #{v.join ','})"
      end
      super "The following plugins couldn't be found: #{text.join(', ')}"
    end
    
  end
  
=begin rdoc
Exception raised when circular dependencies among plugins are detected
=end
  class CircularDep < DependencyError
    
=begin rdoc
The circular dependencies among the plugins

@return [<(Symbol, Symbol)>] an array containing the circular dependencies. Each
entry of the array is a pair of symbols, which are the names of the plugins
depending (perhaps indirectly) on each other
=end
    attr_reader :circular_deps
    
=begin rdoc
@param [<(Symbol, Symbol)>] circular an array describing the circular dependencies
among the plugin. It has the same format as {#circular_deps}
=end
    def initialize circular
      @circular_deps = circular.deep_copy
      super "There were circular dependencies among the following pairs of plugins: #{circular.map{|i| "#{i[0]} and #{i[1]}"}.join ', '}"
    end
  end

=begin rdoc
Exception raised when some plugins can't be found. _plugins_ is an array containing
the names of the plugins which couldn't be found, while _dirs_ is an array of
the directories searched for those plugins
=end
  class MissingPlugins < StandardError
    
=begin rdoc
The plugins which coulnd't be found

@return [<Symbol>] an array with the names of the plugins which couldn't be
found
=end
    attr_reader :plugins
    
=begin rdoc
The directories which were searched for plugins

@return [<String>] an array with the directories searched for plugins
=end
    attr_reader :dirs
    
=begin rdoc
@param [<Symbol>] plugins an array with the names of the plugins which couldn't
be found
@param [<String>] dirs an array with the directories searched for plugins
=end
    def initialize plugins, dirs
      @plugins = plugins.dup
      @dirs = dirs.dup
      super "The plugins #{@plugins.join ' '} couldn't be found in the directories #{@dirs.join ' '}"
    end
  end

=begin rdoc
Exception raised when some PSFs contain errors
=end
  class InvalidPSF < StandardError

# An array containing the files which produced errors
    
=begin rdoc
The paths of the invalid PSFs

@return [<String>] an array with the paths of the invalid PSFs
=end
    attr_reader :files

=begin rdoc
@param [<String>] files an array with the paths of the invalid PSFs
=end
    def initialize files
      @files = files.dup
      super "The following plugin description files contained errors: #{files.join ' '}"
    end
  end
  
end