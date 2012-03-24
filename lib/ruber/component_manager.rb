=begin 
    Copyright (C) 2010 by Stefano Crocco   
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

require 'forwardable'

require 'dictionary'
require 'facets/kernel/deep_copy'
require 'facets/boolean'

require 'ruber/plugin'
require 'ruber/plugin_specification'

=begin
Workflow:

* bin/ruber creates an instance of the component manager 
* the component manager adds itself to the list of components (in initialize)
* bin/ruber calls the component manager's load_core_components method
* load_core_components calls load_component for the application object
* Ruber::Application.new creates the application data and command line objects,
  before creating the object itself
* the application's setup method starts a single shot timer which will cause
  the user plugins to be loaded when the main window is displayed
* load_core_components calls load_component for the other core components:
  configuration, document keeper, project keeper, main window
* the setup method of the config object calls application#read_settings
* bin/ruber displays the main window and starts the application
* user plugins are loaded
=end

module Ruber
  
  class ComponentManager < Qt::Object
    
=begin rdoc
Helper class used to resolve dependencies among plugins. Most likely you don't
need to use it, but simply call <tt>Ruber::ComponentManager.sort_plugins</tt>.
=end
    class PluginSorter
      
=begin rdoc
Creates a new +PluginSorter+. _pdfs_ is an array of the plugin descriptions to
sort. _ignored_ is an array containing dependencies to be ignored(maybe because
they're already loaded). _ignored_ can be either an array of symbols, where each
symbol is the name of a feature, or an array of +PluginSpecification+s.
      
<b>Note:</b> _pdfs_ should contain dependencies in terms of actual plugins, not
of features.
=end
      def initialize pdfs, ignored = []
        @pdfs = {}
        @plugins = {}
        pdfs.each do |i|
          @pdfs[i.name] = i
          @plugins[i.name] = i.deps
        end
        @ignored = ignored.map{|i| i.is_a?(OpenStruct) ? i.name : i}
        @ready = []
        @deps = {}
      end

=begin rdoc
Sorts the plugins associated with the object, according with their dependencies 
and returns an array containing the plugin descriptions sorted in dependence order,
from the dependence to the dependent.

If some of the plugins have dependency which doesn't correspond neither to another
plugin nor to one of the plugins to ignore, <tt>Ruber::ComponentManager::UnresolvedDep</tt>
will be raised.

If there's a circular dependency among the plugins, <tt>Ruber::ComponentManager::CircularDep</tt>
will be raised.
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
        res.map{|i| @pdfs[i]}
      end

      private
      
=begin rdoc
  Checks whether all the dependencies among the plugins are satisifed either by
  another plugin or by a plugin in the _ignore_ list. Returns a hash which is
  empty if all the dependencies were satisifed and otherwise has for keys the
  names of plugins whose dependencies couldn't be found and for values arrays
  containing the names of the missing dependencies for that plugin.
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
  Finds the dependencies of the plugin _plug_. To do this, it calls itself
  recursively for each of the direct dependencies of the plugin. The dependencies
  found are stored in the <tt>@deps</tt> hash. 
      
  To avoid an endless loop or a SystemStackError in case of circular dependencies,
  each time the method is called, it is also passed a second argument, an array
  containing the names of the plugins whose dependencies have lead to that call.
      
  If circular dependencies are found, the entry in <tt>@deps</tt> corresponding 
  to the plugin is set to *nil*, and an array containing the pairs of plugins with
  circular dependencies is returned. If no circular dependencies exist, the returned
  array is empty.
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
      
=begin
  Old implementation of sort_plugins (just in case it turns out to be necessary)
def sort_plugins      
  res = []
  until @remaining.empty?
    @ready = @remaining.select{|k, v| v.empty?}.map{|k, v| k}.sort_by{|i| i.to_s}
    report_problem if @ready.empty?
    res += @ready.map{|i| @descriptions[i]}
    @remaining.delete_if{|k, v| @ready.include? k}
    @remaining.each_key{|k| @remaining[k] -= @ready}
  end
  res
end

=end

      
    end

=begin rdoc
  Helper class which contains the methods needed to find all the plugins needed
  to satisfy the dependencies of a given set of plugins.
  
  The difference between this class and PluginSorter is that the latter needs
  to know all the plugins which should be loaded, while this class has the job of
  finding out which ones need to be loaded.
=end
    class DepsSolver

=begin rdoc
  Creates a new +DepsSolver+.
      
  <i>to_load</i> is an array containing the PluginSpecification corresponding describing
  the plugins to load, while <i>availlable</i> is an array containing the 
  PluginSpecification which can be used to resolve dependencies.
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
  Tries to resolve the dependencies for the given plugins, returning an array
  containing the plugins needed to satisfy all the dependencies. When a plugin
  depends on a feature _f_, then _f_ is included in the list of needed plugins, 
  together with its dependencies, unless another required plugin already provides
  that feature.
      
  If some dependencies can't be satisfied, UnresolvedDep is raised. If there are
  circular dependencies, CircularDep is raised.
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
  Recursively finds all the dependencies for the plugin described by the PluginSpecification
  _pl_.
      
  _errors_ is a hash used to store missing dependencies and circular dependencies.
  It should have a <tt>:circular</tt> and a <tt>:missing</tt> key. The corresponding
  values should be an array and a hash.
      
  _stack_ is an array containing the names of the plugins whose dependencies are
  being solved and is used to detect circular dependencies. For example, if _stack_
  is: <tt>[:a, :b, :c]</tt>, it would mean that we're resolving the dependencies
  of the plugin :c, which is a dependency of the plugin :b, which is a dependency
  of the plugin :a. If this array contains <tt>pl.name</tt>, then there's a circular
  dependency.
  
  <b>Note:</b> this method doesn't raise exceptions if there are circular or missing
  dependencies. Rather, it adds them to _errors_ and goes on (this means that it
  skips both missing and circular dependencies).
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
  Attempts to remove from the list of needed dependencies all those dependencies
  which are there only to provide features already provided by other plugins.
  
  For example, if the list of needed plugins includes both the plugin <tt>:a</tt>
  and the plugin <tt>:b</tt>, which provides the feature <tt>:a</tt>, then the
  plugin <tt>:a</tt> whould be removed from the list.
      
  If after removing plugins as described above, the list contains plugins which
  aren't needed anymore, because they were there only to satisfy the dependencies
  of plugins which have already been removed, they're also removed.
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
      end
      
    end
  
=begin rdoc
Base class for UnresolvedDep and CircularDep exceptions. It represents all the
possible kinds of dependency errors.
=end
  class DependencyError < RuntimeError
  end

=begin rdoc
  Exception raised by <tt>Ruber::ComponentManager</tt> when some dependencies of
  the plugins can't be found.
=end
    class UnresolvedDep < DependencyError
      
=begin rdoc
  a hash containing the missing dependencies. The keys are the names of the plugins
  who have unknown dependencies, while the values are arrays with the name of the
  missing dependencies
=end
      attr_reader :missing
      
=begin rdoc
  Creates a new <tt>Ruber::ComponentManager::UnresolvedDep</tt>. _missing_ is a
  hash containing the missing dependencies. It must have the same format as
  the +missing+ attribute.
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
  Exception raised by <tt>Ruber::ComponentManager</tt> when circular dependencies
  among plugins are detected.
=end
    class CircularDep < DependencyError
      
=begin rdoc
  The plugins among which the circular dependencies exist. It's an array of 
  arrays. Each inner array contains the name of the two plugins depending
  (perhaps indirectly) on each other.
=end
      attr_reader :circular_deps
      
=begin rdoc
  Creates a new <tt>Ruber::ComponentManager::CircularDep</tt>. _circular_ is an
  array containing the plugins among which the circular dependencies exist, whith
  the format described for <tt>Ruber::ComponentManager::CircularDep#circular_deps</tt>
=end
      def initialize circular
        @circular_deps = circular.deep_copy
        super "There were circular dependencies among the following pairs of plugins: #{circular.map{|i| "#{i[0]} and #{i[1]}"}.join ', '}"
      end
    end

=begin rdoc
  Exception raised when some plugins couldn't be found. _plugins_ is an array containing
  the names of the plugins which couldn't be found, while _dirs_ is an array of
  the directories searched for those plugins
=end
    class MissingPlugins < StandardError
      attr_reader :plugins, :dirs
      def initialize plugins, dirs
        @plugins = plugins.dup
        @dirs = dirs.dup
        super "The plugins #{@plugins.join ' '} couldn't be found in the directories #{@dirs.join ' '}"
      end
    end

=begin rdoc
  Exception raised when some of the PDFs for the plugins to be loaded contain error.
  It differs from <tt>Ruber::ComponentManager::PluginSpecification::PSFError</tt> only
  in the fact that it contains the list of files which produced an error.
=end
    class InvalidPDF < StandardError

# An array containing the files which produced errors
      attr_reader :files

# Creates a new instance. _files_  is an array containing the names of the files
# which produced errors.
      def initialize files
        @files = files.dup
        super "The following plugin description files contained errors: #{files.join ' '}"
      end
    end

=begin rdoc
  Looks in the directories specified in the _dirs_ array for plugins and returns
  a hash having the directory of each found plugin as keys and either the name
  or the PluginSpecification for each plugin as values, depending on the value of the
  _info_ parameter.
    
  <b>Note:</b> if more than one directory contains a plugin with the given name,
  only the first (according to the order in which directories are in _dirs_) will
  be taken into account.
=end
    def self.find_plugins dirs, info = false
      res = {}
      dirs.each do |dir|
        Dir.entries(dir).sort[2..-1].each do |name|
          next if res[name.to_sym]
          d = File.join dir, name
          if File.directory?(d) and File.exist?(File.join d, 'plugin.yaml')
            if info then 
              res[name.to_sym] = PluginSpecification.intro(File.join d, 'plugin.yaml')
            else res[name.to_sym] = d
            end
          end
        end
      end
      res
    end

    
=begin rdoc
  Replaces features in plugin dependencies with the names of the plugin providing
  them. _pdfs_ is an array containing the <tt>Ruber::PluginSpecification</tt>s of plugins whose dependencies should
  be changed, while _extra_ is an array containing the <tt>PluginSpecification</tt>s of plugins
  which should be used to look up features, but which should not be changed. For
  example, _extra_ may contain descriptions for plugins which are already loaded.

  It returns an array containing a copy of the <tt>Ruber::PluginSpecification</tt>s whith the dependencies
  correctly changed. If a dependency is unknown, <tt>Ruber::ComponentManager::UnresolvedDep</tt>
  will be raised.
=end
    def self.resolve_features pdfs, extra = []
      features = (pdfs+extra).inject({}) do |res, pl|
        pl.features.each{|f| res[f] = pl.name}
        res
      end
      missing = Hash.new{|h, k| h[k] = []}
      new_pdfs = pdfs.map do |pl|
        res = pl.deep_copy
        res.deps = pl.deps.map do |d| 
          f = features[d]
          missing[pl.name] << d unless f
          f
        end.uniq.compact
        res
      end
      raise UnresolvedDep.new Hash[missing] unless missing.empty?
      new_pdfs
    end

=begin rdoc
  Finds all the dependencies for the given plugins choosing among a list.
  <i>to_load</i> is an array containing the +PluginSpecification+ for the plugins to load,
  while _availlable_ is an array containing the plugins which can be used to satisfy
  the dependencies.
    
  This method uses <tt>DepsSolver#solve</tt>, so see the documentation for it for
  a more complete description.
=end
    def self.fill_dependencies to_load, availlable
      solver = DepsSolver.new to_load, availlable
      solver.solve
    end

=begin rdoc
  Sorts the plugins in the _pdfs_ array, according with their dependencies 
  and returns an array containing the plugin descriptions sorted in dependence order,
  from the dependence to the dependent.
      
  _known_ is an array of either symbols or <tt>Ruber::PluginSpecification</tt>s corresponding
  to plugins which can be depended upon but which shouldn't be sorted with the 
  others (for example, because they're already loaded).

  If some of the plugins have dependency which doesn't correspond neither to another
  plugin nor to one of the knonw plugins, <tt>Ruber::ComponentManager::UnresolvedDep</tt>
  will be raised.

  If there's a circular dependency among the plugins, <tt>Ruber::ComponentManager::CircularDep</tt>
  will be raised.
=end
    def self.sort_plugins pdfs, known = []
      PluginSorter.new( pdfs, known ).sort_plugins
    end
    
    extend Forwardable
    
    include Enumerable
    
    signals 'loading_component(QObject*)', 'component_loaded(QObject*)',
        'feature_loaded(QString, QObject*)', 'unloading_component(QObject*)'
    
    def_delegators :@features, :[]
    
# Returns the <tt>PluginSpecification</tt> describing the +ComponentManager+
    attr_reader :plugin_description

# Creates a new +ComponentManager+
    def initialize
      super
      @components = Dictionary[:components, self]
      @features = {:components => self}
      @plugin_description = PluginSpecification.full({:name => :components, :class => self.class})
    end

# Returns <tt>:components</tt>
    def component_name
      @plugin_description.name
    end
    alias plugin_name component_name
    
=begin rdoc
Method required for the Plugin interface. Does nothing
=end
    def register_with_project prj
    end
    
=begin rdoc
Method required for the Plugin interface. Does nothing
=end
    def remove_from_project prj
    end

=begin rdoc
Method required for the Plugin interface. Does nothing
=end    
    def update_project prj
    end

=begin rdoc
  Returns an array containing all the loaded plugins (but not the components), in loading order
=end
    def plugins
      @components.inject([]) do |res, i| 
        res << i[1] if i[1].is_a? Ruber::Plugin
        res
      end
    end

=begin rdoc
  Returns an array containing all the loaded components, in loading order
=end
    def components
      @components.inject([]){|res, i| res << i[1]}
    end

=begin rdoc
 Calls the block for each component, passing it as argument to the block. The
 components are passed in reverse loading order (i.e., the last loaded component
 will be the first passed to the block.)
=end
    def each_component order = :normal #:yields: comp
      if order == :reverse then @components.reverse_each{|k, v| yield v}
      else @components.each{|k, v| yield v}
      end
    end

=begin rdoc
 Calls the block for each plugin (that is, for every component of class 
 <tt>Ruber::Plugin</tt> or derived), passing it as argument to the block. The
 plugins are passed in reverse loading order (i.e., the last loaded plugin
 will be the first passed to the block.)
=end
    def each_plugin order = :normal #:yields: plug
      meth = @components.method(order == :reverse ? :reverse_each : :each)
      meth.call do |k, v| 
        yield v if v.is_a?(Ruber::Plugin)
      end
    end
    alias each each_plugin

=begin rdoc
  <b>For internal use only</b>
    
  Adds the given component to the list of components and at the end of the list
  of sorted components.
=end
    def add comp
      @components<< [comp.component_name, comp]
      comp.plugin_description.features.each{|f| @features[f] = comp}
    end

=begin rdoc
  Loads the component with name _name_.
  
  _name_ is the name of a subdirectory (called the <i>component directory</i> 
  in the directory where <tt>component_manager.rb</tt>
  is. That directory should contain the PDF file for the component to load.
    
  The loading process works as follows:
  * the component directory is added to the KDE resource dirs for the +pixmap+,
    +data+ and +appdata+ resource types.
  * A full <tt>Ruber::PluginSpecification</tt> is generated from the PDF
    (see <tt>Ruber::PluginSpecification.full</tt>). If the file can't
    be read, +SystemCallError+ is raised; if it isn't a valid PDF, 
    <tt>Ruber::PluginSpecification::PSFError</tt> is raised. In both cases, a message box
    warning the user is shown.
  * the component object (that is, an instance of the class specified in the +class+
    entry of the PDF) is created
  * the <tt>component_loaded(QObject*)</tt> signal is emitted, passing the component
    object as argument
  * the component object is returned.
    
  <b>Note:</b> this method doesn't insert the component object in the components
  list: the component should take care to do it itself, using the +add+ method.
=end
    def load_component name
      dir = File.expand_path File.join(File.dirname(__FILE__), name)
      if KDE::Application.instance
        KDE::Global.dirs.add_resource_dir 'pixmap', dir
        KDE::Global.dirs.add_resource_dir 'data', dir
        KDE::Global.dirs.add_resource_dir 'appdata', dir
      end
      file = File.join dir, 'plugin.yaml'
      pdf = PluginSpecification.full file
      parent = @components[:app] || self #Ruber[:app] rescue self
      comp = pdf.class_obj.new parent, pdf
      emit component_loaded(comp)
      comp
    end

=begin rdoc
  Loads the plugin in the directory _dir_.
  
  The directory _dir_ should contain the PDF for the plugin, and its last part
  should correspond to the plugin name.
    
  The loading process works as follows:
  * the plugin directory is added to the KDE resource dirs for the +pixmap+,
    +data+ and +appdata+ resource types.
  * A full <tt>Ruber::PluginSpecification</tt> is generated from the PDF
    (see <tt>Ruber::PluginSpecification.full</tt>). If the file can't
    be read, +SystemCallError+ is raised; if it isn't a valid PDF, 
    <tt>Ruber::PluginSpecification::PSFError</tt> is raised.
  * the plugin object (that is, an instance of the class specified in the +class+
    entry of the PDF) is created
  * the <tt>component_loaded(QObject*)</tt> signal is emitted, passing the component
    object as argument
  * for each feature provided by the plugin, the signal <tt>feature_loaded(QString, QObject*)</tt>
    is emitted, passing the name of the feature (as string) and the plugin object
    as arguments
  * for each feature _f_ provided by the plugin, a signal "unloading_f(QObject*)"
    is defined
  * the plugin object is returned.
    
  <b>Note:</b> this method doesn't insert the plugin object in the components
  list: the plugin should take care to do it itself, using the +add+ method.
=end
    def load_plugin dir
      KDE::Global.dirs.add_resource_dir 'pixmap', dir
      KDE::Global.dirs.add_resource_dir 'data', dir
      KDE::Global.dirs.add_resource_dir 'appdata', dir
      file = File.join dir, 'plugin.yaml'
      pdf = PluginSpecification.full YAML.load(File.read(file)), dir
      pdf.directory = dir
      plug = pdf.class_obj.new pdf
      emit component_loaded(plug)
      pdf.features.each do |f| 
        self.class.class_eval{signals "unloading_#{f}(QObject*)"}
        emit feature_loaded(f.to_s, plug)
      end
      plug.send :delayed_initialize
      plug
    end

=begin rdoc
  Makes the +ComponentManager+ load the given plugins. It is the standard method
  to load plugins, because it takes into account dependency order and features.
    
  For each plugin, a directory with the same name and containing a file
  <tt>plugin.yaml</tt> is searched in the directories in the _dirs_ array.
  Directories near the beginning of the array have the precedence with respect
  to those near the end of the array (that is, if a plugin is found both in the
  second and in the fourth directories of _dir_, the one in the second directory
  is used). If the directory for some plugins can't be found, +MissingPlugins+ is
  raised.
    
  This method attempts to resolve the features for the plugins (see
  <tt>Ruber::ComponentManager.resolve_features</tt>) and to sort them, using also
  the already loaded plugins, if any. If it fails, it raises +UnresolvedDep+ or
  +CircularDep+.
    
  Once the plugins have been sorted, it attempts to load each one, according to
  the dependency order. The order in which independent plugins are loaded is
  arbitrary (but consistent: the order will be the same every time). If a plugin
  fails to load, there are several behaviours:
  * if no block has been given, the exception raised by the plugin is propagated
  otherwise, the block is passed with the exception as argument. Depending on the
  value returned by the block, the following happens:
  * if the block returns <tt>:skip</tt>, all remaining plugins are skipped and
    the method returns *true*
  * if the block returns <tt>:silent</tt>, an attempt to load the remaining plugins
    is made. Other loading failures will be ignored
  * if the block any other true value, then the failed plugin is ignored and an
    attempt to load the remaining plugins is made.
  * if the block returns *false* or *nil*, the method immediately returns *false*
  
  <tt>load_plugins</tt> returns *true* if all the plugins were successfully loaded
  (or if some failed but the block always returned a true value) and false otherwise.
  
  ===== Notes
  * After a failure, dependencies aren't recomputed. This means that most likely
    all the plugins dependent on the failed one will fail, too
  * This method can be conceptually divided into two phases: plugin ordering and
    plugin loading. The first part doesn't change any state. This means that, if
    it fails, the caller is free to attempt to solve the problem (for example,
    to remove the missing plugins and the ones with invalid PDFs from the list)
    and call again <tt>load_plugins</tt>. The part which actually _does_ something
    is the second. If called twice with the same arguments, it can cause trouble,
    since no attempt to skip already-loaded plugins is made. If the caller wants
    to correct errors caused in the second phase, it should put the logic to do
    so in the block.
=end
    def load_plugins( plugins, dirs ) #:yields: ex
      plugins = plugins.map(&:to_s)
      plugin_files = locate_plugins dirs
      plugins = create_plugins_info plugins, plugin_files, dirs
      plugins = ComponentManager.resolve_features plugins, self.plugins.map{|pl| pl.plugin_description}
      plugins = ComponentManager.sort_plugins plugins, @features.keys
      silent = false
      plugins.each do |pl| 
        begin load_plugin File.dirname(plugin_files[pl.name.to_s])
        rescue Exception => e
          @components.delete pl.name
          if silent then next
          elsif block_given? 
            res = yield pl, e
            if res == :skip then break
            elsif res == :silent then silent = true
            elsif !res then return false
            end
          else raise
          end
        end
      end
      true
    end

=begin rdoc
  Prepares the application for being cleanly closed. To do so, it:
  * asks each plugin to save its settings
  * emits the signal <tt>unloading_component(QObject*)</tt> for each component,
    in reverse loading order
  * calls the shutdown method for each component (in their shutdown methods,
    plugins should emit the "closing(QObject*)" signal)
  * calls the delete_later method of the plugins (not of the components)
  * deletes all the features provided by plugins from the list of features
  * delete all the plugins from the list of loaded components.
=end
    def shutdown
      save_components_settings
      each_component(:reverse){|c| c.shutdown unless c.equal? self}
#       @components[:config].write
#       each_component do |c|
#         unless c.equal? self
#           if c.is_a? Plugin
#             c.plugin_description.features.each{|f| emit method("unloading_#{f}").call( c)}
#           end
#           emit unloading_component(c)
#           c.shutdown
#         end
#       end
#       each_plugin {|pl| pl.delete_later}
#       @features.delete_if{|f, pl| pl.is_a? Plugin}
#       @components.delete_if{|_, pl| pl.is_a?(Plugin)}      
    end

=begin rdoc
  Unloads the plugin called _name_ (_name_ must be a symbol) by doing the following:
  * emit the signal "unloading_*(QObject*)" for each feature provided by the plugin
  * emit the signal "unloading_component(QObject*)"
  * call the +shutdown+ method of the plugin
  * call the <tt>delete_later</tt> method of the plugin
  * remove the features provided by the plugin from the list of features
  * remove the plugin from the list of components
  
  If _name_ corresponds to a basic component and not to a plugin, +ArgumentError+
  will be raised (you can't unload a basic component).
=end
    def unload_plugin name
      plug = @components[name]
      if plug.nil? then raise ArgumentError, "No plugin with name #{name}"
      elsif !plug.is_a?(Plugin) then raise ArgumentError, "A component can't be unloaded"
      end
#       plug.save_settings
      plug.plugin_description.features.each do |f|
        emit method("unloading_#{f}").call( plug )
      end
      emit unloading_component plug
      plug.unload
      plug.delete_later
      plug.plugin_description.features.each{|f| @features.delete f}
      @components.delete plug.plugin_name
    end

=begin rdoc
  Calls the <tt>query_close</tt> method of all the components (in arbitrary order).
  As soon as one of them returns a false value, it stops and returns *false*. If all
  the calls to <tt>query_close</tt> return a true value, *true* is returned.
    
  This method is intented to be called from <tt>MainWindow#queryClose</tt>.
=end
    def query_close 
      res = each_component(:reverse) do |c| 
        unless c.equal? self
          break false unless c.query_close 
        end
      end
      res.to_bool
    end
    
    def session_data
      res = {}
      each_component do |c|
        res.merge! c.session_data unless c.same? self
      end
      res
    end
    
    def restore_session data
      each_component do |c|
        c.restore_session data unless c.same? self
      end
    end
    
=begin rdoc
Saves the settings of each component

It calls the @#save_settings@ method of each component, then calls the {ConfigManager#write write} method of the config object

@return [nil]
=end
    def save_components_settings
      each_component(:reverse){|c| c.save_settings unless c.equal?(self)}
      @components[:config].write
      nil
    end
    
    
    private
    
=begin rdoc
  Searches the directories in the _dirs_ array for all the subdirectories containing
  a plugin.yaml file and returns the paths of the files. Returns a hash with keys
  corresponding to plugin names and values corresponding to the path of the PDF
  for the plugin.
=end
    def locate_plugins dirs
      plugin_files = {}
      dirs.reverse.each do |d|
        Dir.entries(d).sort[2..-1].each do |f| 
          full_dir = File.join d, f
          if File.directory?(full_dir) and File.exist?(File.join(full_dir, 'plugin.yaml'))
            plugin_files[f] = File.join full_dir, 'plugin.yaml'
          end
        end
      end
      plugin_files
    end


=begin rdoc
  Attempts to create <tt>Ruber::PluginSpecification</tt>s for each plugin in the _plugins_
  array. The path for the PDFs is taken from _files_, which is an hash with the
  plugin names as keys and the PDFs paths as values.
    
  If some PDFs are missing, <tt>MissingPlugins</tt> is raised. If some PDFs are
  invalid, +InvalidPDF+ is raised. Otherwise, an array containing the <tt>PluginSpecification</tt>s
  for the plugins is returned.
=end
    def create_plugins_info plugins, files, dirs
      missing = []
      errors = []
      res = plugins.map do |pl| 
        file = files[pl]
        if file 
          begin PluginSpecification.new file
          rescue ArgumentError, PluginSpecification::PSFError
            errors << file
          end
        else missing << pl
        end
      end
      raise MissingPlugins.new missing, dirs unless missing.empty?
      raise InvalidPDF.new errors unless errors.empty?
      res
    end
    
  end
  
end
