=begin 
    Copyright (C) 2010,2011,2012 by Stefano Crocco   
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

module Ruber

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

  class ComponentManager < Qt::Object
       
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
      @plugin_description = PluginSpecification.full({:name => :components, :class => self.class, :type => :core})
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
    to remove the missing plugins and the ones with invalid PSFs from the list)
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
      each_component(:reverse){|c| c.save_settings unless c.equal?(self)}
      @components[:config].write
      each_component(:reverse){|c| c.shutdown unless c.equal? self}  
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
    
    
    private

    
  end
  
end
