require 'ruber/dependent'

module Ruber

=begin rdoc
Class with the task of managing plugin dependencies

This class takes care of finding out which plugins need to be loaded or unloaded
but relays on other clases (managers) to do the actual loading and unloading.

There are three kind of managers, one for each kind of plugin: @library@, @global@
and @project@.
=end
  class ComponentLoader

=begin rdoc
@param [<PluginSpecification>] psfs a list of the availlable plugin specifications
@param [Hash] managers an hash containing the plugin managers for various kind
  of plugins. The keys are the type of plugins they manage and must be one of
  @:library@, @:global@ and @:project@. The hash must always contain the @:library@
  key and at least one of the other two
@raise [ArgumentError] if the @:library@ key or both the @:global@ and @:project@
  keys are missing
=end
    def initialize psfs, managers
      unless managers.include? :library
        raise ArgumentError, "missing library plugins manager"
      end
      unless managers[:global] or managers[:project]
        raise ArgumentError, "both global and project plugins manager are missing"
      end
      @managers = managers
      @psfs = Hash[psfs.map{|ps| [ps.name, ps]}]
      @loaded_plugins = []
    end

=begin rdoc
Chooses the plugin to be loaded

An attempt is made to find all needed dependencies for the given plugins. If the
attempt is successful, all plugins which aren't needed are unloaded, then the
neede plugins are loaded.

@param [<Symbol>] names a list of the names of the plugins to load
@raise [Dependent::Solver::CircularDependencies] if there are circular dependencies
  among the plugins to load
@raise [Dependent::Solver::DuplicateFeatureError] if multiple plugins among those
  needed to satisfy the dependencies provide the same feature
@raise [Dependent::Solver::UnresolvedDependencies] if some needed feature isn't
  provided by the availlable plugins
@return [void]
=end
    def set_chosen_plugins names
      chosen_psfs = names.map{|n| @psfs[]}
      solver = Dependent::Solver.new
      solutions = solver.solve chosen_psfs, @psfs.values
      unload_unneded_plugins solutions
      load_plugins solutions
    end

    private

=begin rdoc
Unloads all the plugins which aren't needed to satisfy the given set of solutions

@param [<Dependent::Solution>] solutions the solutions which should be kept
@return [void]
=end
    def unload_unneded_plugins solutions
      loaded_solutions = @loaded_plugins.map &:solution
      to_unload = loaded_solutions - solutions
      to_unload.concat loaded_solutions.select do |s|
        !(s.dependencies & to_unload).empty?
      end
      to_unload.sort! do |x, y|
        if x.dependencies.include? y then 1
        elsif y.dependencies.include x then -1
        else 0
        end
      end
      to_unload.each do |s|
        psf = @psfs[s.name]
        @managers[psf.type].unload_plugin psf
        psf.solution = nil
        @loaded_plugins.delete psf
      end
    end

=begin rdoc
Loads all the plugins which are needed to satisfy the given set of solutions

All plugins included in the given solutions set which are already loaded are kept;
the other are loaded.

@param [<Dependent::Solution>] solutions the solutions which must be loaded
@return [void]
=end
    def load_plugins solutions
      solutions.each do |s|
        psf = @psfs[s.name]
        unless @loaded_plugins.include? psf
          @managers[psf.type].load_plugin psf
          @loaded_plugins << psf
          psf.solution = s
        end
      end
    end

  end

end
