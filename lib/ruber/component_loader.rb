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
require 'find'

require 'facets/kernel/deep_copy'

require 'ruber/plugin_specification'
require 'ruber/component_loader_helpers'

module Ruber
  
  module ComponentLoader

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
    def find_plugins dirs, info = false
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
    def resolve_features psfs, extra = []
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
@return [<Symbol>] a list of the names of the plugins (not features) needed
  to satisfy the dependencies of plugins in _to_load_. Note that this list
  doesn't contain the plugins in _to_load_
@raise (see DepsSolver#solve)

@see DepsSolver#solve
=end
    def fill_dependencies to_load, availlable
      solver = DepsSolver.new
      solver.solve to_load, availlable
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
    def sort_plugins psfs, known = []
      PluginSorter.new( psfs, known ).sort_plugins
    end
    
=begin rdoc
Loads the core component with the given name

The loading process works as follows:
* the component directory is added to the KDE resource dirs for the pixmap,
  data and appdata resource types. This doesn't happen for the application
  component
* A full {Ruber::PluginSpecification} is generated from the PSF. 
* the component object is created

@param [String] base_dir the directory containing the component directory
@param [String] name the subdirectory (relative to _base_dir_) where the @plugin.rb@ file of the component to load is
@param [Qt::Object,nil] keeper the keeper where the new component should be stored.
  It'll also become the parent (in the sense of @Qt::Object#parent@) of the new
  component
@raise [SystemCallError] if the PSF for the given component can't be opened
@raise [Ruber::PluginSpecification::PSFError] if the PSF for the given component
  is not valid
@return [Qt::Object] the component object
=end
    def load_component base_dir, name, keeper = nil
      dir = File.join base_dir, name
      if KDE::Application.instance
        KDE::Global.dirs.add_resource_dir 'pixmap', dir
        KDE::Global.dirs.add_resource_dir 'data', dir
        KDE::Global.dirs.add_resource_dir 'appdata', dir
      end
      file = File.join dir, 'plugin.yaml'
      psf = PluginSpecification.full file
      comp = psf.class_obj.new keeper, psf
      comp
    end
    
=begin rdoc
Loads the plugin contained in the given directory

The loading process works as follows:
* the plugin directory is added to the KDE resource dirs for the @pixmap@,
  @data@ and @appdata@ resource types.
* A full {Ruber::PluginSpecification} is generated from the PSF
  (see {Ruber::PluginSpecification.full})
* the plugin object (that is, an instance of the class specified in the @class@
  entry of the PSF) is created, passing @self@ as second argument
* the @component_loaded(QObject*)@ signal is emitted, with the plugin
  object as argument
* for each feature provided by the plugin, the signal @feature_loaded(QString, QObject*)@ is emitted with the name of the feature (as string) and the plugin
object as arguments
* the {PluginLike#delayed_initialize delayed_initialize} method of the plugin
  object is called
@param [String] dir the full path of the directory where the plugin file lives.
  The last part of the path should be the same as the name of the plugin
@param [PluginKeeper] keeper the object where the plugin should be stored
@return [Object] the plugin object. The actual class of this object depends on
  the contents of the @class@ entry of the PSF, but it'll most likely be a
  {PluginLike}
@raise [SystemCallError] if the PSF in the given directory can't be opened
@raise [Ruber::PluginSpecification::PSFError] if the PSF in the given directory
  is not valid
@note If included in a class not derived from @Qt::Object@, the signals won't
  be emitted. Everything else will work correctly.
  
  A class derived from Qt::Object which includes this module *must* define the
  following signals:
  * @component_loaded(QObject*)@
  * @feature_loaded(QString, QObject*)@
=end
    def load_plugin dir, keeper
      KDE::Global.dirs.add_resource_dir 'pixmap', dir
      KDE::Global.dirs.add_resource_dir 'data', dir
      KDE::Global.dirs.add_resource_dir 'appdata', dir
      file = File.join dir, 'plugin.yaml'
      psf = PluginSpecification.full YAML.load(File.read(file)), dir
      psf.directory = dir
      plug = psf.class_obj.new keeper, psf
      if self.is_a? Qt::Object
        emit component_loaded(plug)
        psf.features.each do |f| 
          emit feature_loaded(f.to_s, plug)
        end
      end
      plug.send :delayed_initialize
      plug
    end
    
    def find_needed_plugins to_load, dirs, extra = []
      psfs = create_plugins_info locate_plugins(dirs)
      to_load = to_load.map{|pl| psfs[pl]}
      availlable = psfs.values
      to_load.concat fill_dependencies(to_load, availlable).map{|pl| psfs[pl]}
      plugins = resolve_features to_load, extra
      extra_features = extra.inject([]){|res, i| res.concat i.features}
      plugins = sort_plugins plugins, extra_features
    end
    
=begin rdoc
Loads the given plugins, along with the needed dependencies

This is the standard method to load plugins, because it takes care of correctly
ordering them and gracefully handles any error which may arise.

The loading process goes as follows:
* the PSF for each plugin is found. The PSF is a file called @plugin.yaml@ in
  a directory with the same name as the plugin (called the plugin directory).
  The plugin directories are looked for in the directories passed as second
  argument.
* After reading the PSFs for all plugins, {#resolve_features} and {#sort_plugins}
  are used to put them in the correct order. They're ordered so that any plugin
  is loaded after all the plugins it depends on. Aside from this, the order is
  arbitrary (but consistent: the same plugins will be ordered in the same way
  every time this method is called).
* Each plugin is loaded using {#load_plugin}

When an exception is raised while loading a plugin and a block was passed to this method, the exception is caught and passed to the block. What happens next
depends on the value returned by the block:
* if the block returns @:skip@, the loading process stops and the method returns
  successfully
* if the block returns @:silent@, the loading process goes on. Further errors
  are ignored
* if the block returns a false value, the method immediately returns a failure
* in all other cases the loading process goes on. In case more errors occur,
  the block is called again.
Note that the block is only called for exception raised when loading the plugins,
not when resolving features or ordering the plugins.
@param [<Symbol,String>] plugins the names of the plugins to load
@param [<String>] dirs the absolute paths of the directory where to search for
  plugins. The directories are searched in the order they are in the list. Once
  a given plugin is found in a directory, other directories won't be searched
  for it.
@param [<PluginSpecification>] extra a list of already loaded plugins which
  can be used to resolve dependencies
@yield [plug, ex] a block called when an exception is raised loading a plugin. How the error is treated depends on the value returned by the block
@yieldparam [Symbol] plug the name of the plugin which was being loaded
@yieldparam [Exception] ex the exception raised while loading the plugin
yieldreturn [Symbol] a value telling the method how to recover from the error

@yieldreturn [Symbol] @:skip@ if the error should return immediately 
@return [(Boolean, <Object>)] a pair of values. The first tell whether the method
  was successful or not. The second is a list of all the loaded plugins
@raise [UnresolvedDep] if there were unresolved dependencies
@raise [CircularDep] if there were circular dependencies
@note If a plugin fails to load and the block tells to go on with other plugins,
  all plugins depending on the failed one will most likely fail, too.
@note This method doesn't change Ruber's state until the plugins have been
  ordered. This means that, if {UnresolvedDep} or {CircularDep} is raised, it's
  completely safe for the calling method to call again this method, possibly
  with a fixed list of plugins.
  
  Calling this method with the same plugin list after plugins start to load,
  instead, may lead to trouble, since some plugins may be duplicated. However,
  this isn't needed, given the flexibility provided by the block.
=end
    def load_plugins( plugins, dirs, extra = [] ) #:yields: ex
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
    
    def unload_plugin
      
    end
    
    private
    
=begin rdoc
Searches the given directories for plugins

A plugin is a subdirectory containing a file named @plugin.yaml@ (which is the
PSF for the plugin). The name of the subdirectory is assumed to be the same as
that of the plugin.
@param [<String>] dirs the absolute paths of the directories to search
@return [{Symbol => String}] the names of the plugins with the path of the
  corresponding PSF. If more than one directories contain the same plugin, the
  hash only contains the first one
=end
    def locate_plugins dirs
      plugin_files = {}
      dirs.reverse.each do |d|
        Find.find d do |sd|
          psf = File.join sd, 'plugin.yaml'
          if File.directory? sd and File.exist? psf
            plugin_files[File.basename(sd).to_sym] ||= psf
            Find.prune
          end
        end
#         Dir.entries(d).sort[2..-1].each do |f| 
#           full_dir = File.join d, f
#           p full_dir
#           if File.directory?(full_dir) and File.exist?(File.join(full_dir, 'plugin.yaml'))
#             plugin_files[f] = File.join full_dir, 'plugin.yaml'
#           end
#         end
      end
      
      plugin_files
    end
    
=begin rdoc
Create a plugin specification object for the given plugins

@param [{Symbol => String}] plugins a hash with the name of the plugins and the
  path of the corresponding PSF
@return [{Symbol=>PluginSpecification}] the {PluginSpecification}s for the given
  plugins stored by plugin name
@raise [InvalidPSF] if some of the given PSFs were invalid
@raise [SystemCallError] if some of the PSFs didn't exist
=end
    def create_plugins_info plugins
      errors = {}
      res = {}
      plugins.each_pair do |name, path| 
        begin res[name] = PluginSpecification.new(path)
        rescue ArgumentError, PluginSpecification::PSFError
          errors << path
        end
      end
      raise InvalidPSF.new errors unless errors.empty?
      res
    end
    
  end
  
end