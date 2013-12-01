require 'forwardable'

# Adds the {#subset_of?} method to array
class Array

  unless Array.instance_methods.include? :subset_of?

=begin rdoc
Whether @self@ is a subset of another array

@param [Array] other the array @self@ may be subset of
@return [Boolean] @true@ if all the elements of @self@ are also elements of
  _other_ and @false@ otherwise
=end
    def subset_of? other
      (self - other).empty?
    end
  end

end

# Main module for Dependent
module Dependent

=begin rdoc
Class representing one of the objects to load

Each solution enapsulates an object

@!method name
  @return [Symbol] the name of the object associated with the solution

@!method features
  @return [<Symbol>] a list of the features provided by the associated object
=end
  class Solution

    extend Forwardable

    def_delegators :@object, :name, :features

=begin rdoc
@return [#name,#deps,#features] the object associated with the solution
=end
    attr_reader :object

=begin rdoc
@return [<Solution>] a list of other solutions this solution directly depends on
=end
    attr_reader :direct_dependencies
    alias_method :direct_deps, :direct_dependencies

=begin rdoc
@return [<Solution>] a list of other solution this solution depends on, directly
  or indirectly
=end
    attr_accessor :all_dependencies
    alias_method :all_deps, :all_dependencies
    alias_method :dependencies, :all_dependencies

=begin rdoc
A list of solution which depend, directly or not, on this one

@return [<Solution,nil>] a list of solution which depend, directly or not, on this
  one. If the array contains @nil@ it means that the associated object was
  requested explicitly
=end
    attr_reader :required_by

=begin rdoc
A list of features this solution is required for

@return [<Symbol, nil>] a list of features this solution is required for. If the
  array contains @nil@ it means that the associated object was requested
  explicitly
=end
    attr_reader :required_for

=begin rdoc
@param [#name, #deps, #features] object the object associated with the solution.
  It must provide the following methods:
  * @name@: the name of the object
  * @features@: a list of symbols corresponding to the features provided by the
    object
  * @deps@: a list of features the object depends on
=end
    def initialize object
      @object = object
      @direct_dependencies = []
      @required_by = []
      @required_for = []
      @all_dependencies = []
    end

=begin rdoc
@return [Boolean] whether or not the dependencies of this solution have already
  been computed
=end
    def dependencies_fullfilled?
      @direct_dependencies.empty? or !@all_dependencies.empty?
    end

=begin rdoc
Compare this solution with another one by checking if one of them is a
replacement for the other

A solution is a replacement for another if it provides all the features the other
is required for (according to {#required_for}). An exception is if the latter
solutions'{#required_for} method returns an array containing @nil@, which means
the solution is required by the user

@param [Solution] other the solution to compare this to
@return [Integer] 1 if _other_ is a replacement for @self@
@return [Integer] -1 if @self@ if a replacement for _other_
@return [nil] if neither solution is a replacement for the other
=end
    def =~ other
      if @required_for.subset_of? other.object.features then 1
      elsif other.required_for.subset_of? @object.features then -1
      else nil
      end
    end

  end
   
=begin rdoc
Class which performs the computation and sorting of dependencies
=end
  class Solver
    
=begin rdoc
Exception raised when two objects which are both required to satisfy dependencies
provide the same features
=end
    class DuplicateFeatureError < RuntimeError
      
=begin rdoc
@return [{Symbol => [<Solution>]}] a list of the duplicate features. Each key
  in the hash is a duplicate features, with the corresponding array being the
  list of needed plugins which provide it
=end
      attr_reader :features
      
=begin rdoc
@param [{Symbol => [<Solution>]}] features a list of the duplicate features. Each key
  in the hash is a duplicate features, with the corresponding array being the
  list of needed plugins which provide it
=end
      def initialize features
        super "Multiple plugins provided the same features"
        @features = features.dup
      end
      
    end

=begin rdoc
Exception raised when there are circular dependencies among the objects to load
=end
    class CircularDependencies < RuntimeError

=begin rdoc
@return [<<Solution>>] a list of array of solutions. Each of the inner arrays
  corresponds to a list of objects which circularly depend on each other
=end
      attr_reader :dependencies

=begin rdoc
@param [<<Solution>>] circ a list of array of solutions. Each of the inner arrays
  corresponds to a list of objects which circularly depend on each other
=end
      def initialize circ
        super 'There were circular dependencies'
        @dependencies = circ
      end

    end

=begin rdoc
Exception raised when one of the objects needed to satisfy dependencies depend
on features which none of the availlable objects provides
=end
    class UnresolvedDependencies < RuntimeError

=begin rdoc
@return [<Symbol>] a list of the missing features
=end
      attr_reader :missing_features

=begin rdoc
@param [<Symbol>] missing a list of the missing features
=end
      def initialize missing
        @missing_features = missing
        super "No object provides the following features: #{missing.join ', '}"
      end

    end

=begin rdoc
Finds all the dependencies needed to satisfy given objects' requirements and
sorts them

@param [<#name>] req a list of the objects whose requirements must be satisfied
@param [<#name>] availlable a list of all availlable objects. It must include all
  objects contained in _req_ and in _extra_
@param [<#name>] extra a list of objects which can be used to satisfy dependencies
  but which shouldn't be loaded or sorted
@return [<Solution>] a list of the solutions needed to satisfy the given
  requirements in the correct order
=end
    def solve req, availlable, extra = []
      @availlable = availlable.inject({}) do |res, i|
        res[i.name] = Solution.new(i)
        res
      end
      @required = req.sort_by(&:name).map do |i|
        s = @availlable[i[0]]
        s.required_by << nil
        s.required_for << nil
        s
      end
      @extra = extra.map{|i| s = Solution.new i}
      @features = Hash.new{|h, k| h[k] = []}
      @availlable.each_value do |s|
        s.features.each{|f| @features[f] << s}
      end
      to_load, missing = find_direct_deps
      raise UnresolvedDependencies.new missing unless missing.empty?
      to_load.uniq!
      to_load = remove_duplicates to_load
      duplicates = find_duplicate_features to_load
      raise DuplicateFeatureError.new duplicates unless duplicates.empty?
      find_full_dependencies to_load
      remove_unneeded_deps to_load
      sort to_load
    end

    private

=begin rdoc
Finds the solutions needed to satisfy the direct dependencies of required plugins

This method is recursive, finding direct dependencies of direct dependencies
and so on.

This method returns a list of possible dependencies: it may include more than
one solution for the same feature.

@return [(<Solution>,<Solution>)] a pair whose first element is a list of all
  solutions needed to satisfy dependencies and whose second element is a list
  of missing dependencies
=end
    def find_direct_deps
      not_done = @required.dup
      found = []
      missing = []
      until not_done.empty?
        sol = not_done.shift
        sol.object.deps.each do |d|
          f = @features[d].find{|x| x.name == f} || @features[d][0]
          if f
            not_done << f unless found.include? f
            f.required_for << d
          else missing << d
          end
        end
        found << sol
      end
      [found, missing]
    end

=begin rdoc
Removes from a list of solutions those which are uneeded

A solution is considered uneeded if the user didn't request it and if all the
features it is required for are provided by another solution.

@param [<Solution>] sols a list of solutions to load
@return [<Solution>] a subset of _sols_ with all uneeded solutions removed
=end
    def remove_duplicates sols
      sols = sols.dup
      to_load = []
      count = nil
      while count != to_load.count
        count = to_load.count
        until sols.empty?
          s = sols.shift
          duplicates = []
          sols.each do |x|
            case s =~ x
            when 1
              duplicates << s
              x.required_for.concat s.required_for
              break
            when -1
              duplicates << x
              s.required_for.concat x.required_for
            end
          end
          to_load << s unless duplicates.include? s
          sols -= duplicates
        end
      end
      to_load
    end

=begin rdoc
In a list of solution, finds those providing the same features

More than one plugin providing the same feature means they can't be loaded at
the same time.

@param [<Solution>] sols a list of solutions
@return [{Symbol => <Solution>}] the features provided by more than one solution.
  The keys of the hash are the name of the duplicate features, while the values
  are arrays contaning the solutions providing them. If no duplicate features
  are found the hash is empty
=end
    def find_duplicate_features sols
      features = sols.inject(Hash.new{|h, k| h[k] = []}) do |res, s|
        s.object.features.each{|f| res[f] << s}
        res
      end
      features.select{|f, s| s.count != 1}
    end

=begin rdoc
Finds all the dependencies for the given solutions

Unlike {#find_direct_deps}, this method also finds indirect dependencies for
each solution, filling its {Solution#all_dependencies all_dependencies} attribute
@param [<Solution>] sols a list of all solutions to load. It must include all
  the needed dependencies
@return [void]
@raise [CircularDependencies] if there are circular dependencies among the
  solutions
=end
    def find_full_dependencies sols
      sols = sols.dup
      sols.each do |s|
        s.object.deps.each do |f|
          s.direct_dependencies << sols.find{|x| x.object.features.include? f}
        end
      end
      done = []
      until sols.empty?
        count = sols.count
        sols.delete_if do |s|
          if s.direct_dependencies.all? &:dependencies_fullfilled?
            indirect_deps = s.direct_dependencies.inject([]) do |res, d|
              res.concat d.all_dependencies
            end
            s.all_dependencies = s.direct_dependencies + indirect_deps
            s.all_dependencies.each do |d|
              d.required_by << s
            end
            done << s
          end
        end
        if count == sols.count
          circ = find_circular_deps sols
          raise CircularDependencies.new(circ)
        end
      end
    end

=begin rdoc
Finds circular dependencies among the solutions

This method is slow and it is meant to be called only when it has been otherwise
determined that circular dependencies among the solution do exist. This method
is then called to find out which solutions cause them.
@param [<Solution>] sols a list of solutions with circular dependencies among
  them
@return [Array< <Solution > >] an array of arrays of solutions. Each inner array
  represents a dependency cicle.
=end
    def find_circular_deps sols
      prc = lambda do |cur, line, circ|
        common = cur.direct_dependencies & line
        if !common.empty?
          common.each{|c| circ << (line + [cur] + [c])}
          return
        else
          line << cur
          cur.direct_dependencies.each do |d|
            prc.call d, line, circ
          end
        end
      end
      circ = []
      sols.each{|s| prc.call s, [], circ}
      simplify_circular_deps circ
    end

=begin rdoc
Removes equivalent cycles from a list of circular dependencies

Two cycles are equivalent if they represent the same cycle, only starting from
  a different solution.

@param [Array<Array <Solution> >] circ a list of the circular dependencies to
  simplify. Each inner array represents a circular dependency. It is assumed
  that the first and the last entry of each of those arrays are the same (this
  means the cycle is closed)
@return [Array< Array<Solution> >] the circular dependencies listed in _circ_
  with equivalent elements removed
=end
    def simplify_circular_deps circ
      #the last element of each entry is a duplicate of the first, so we
      #remove it
      hash = Hash[circ.map{|c| [c.map{|s| s.name}[0...-1], c]}]
      sorted_cycle = lambda do |c|
        offset = c.index c.min
        Array.new(c.count) do |i|
          pos = i + offset
            c[pos] || c[pos - c.count]
        end
      end
      equiv = hash.keys.group_by{|it| sorted_cycle[it]}
      equiv.values.map{|a| hash[a[0]]}
    end

=begin rdoc
Removes all solutions which haven't been explicitly requested and nobody depends
  on

@param [<Solution>] sols a list of solutions to load. Note that his array will
  be modified
@return [<Solution>] sols with all needless solutions removed
=end
    def remove_unneeded_deps sols
      loop do
        deleted = []
        sols.delete_if{|s| s.required_by.empty?}
        if deleted.empty? then break
        else
          sols.each do |s|
            deleted.each{|d| s.required_by.delete d}
          end
        end
      end
      sols
    end

=begin rdoc
Sorts the given solutions

The solutions are sorted so that any solution comes after all those it depends
upon and before all those depending on it. Two solutions not depending on each
other are sorted in an arbitrary order.

@param [<Solution>] solutions the solutions to sort
@return [<Solution>] an array with the sorted solutions
=end
    def sort solutions
      to_sort = Hash[solutions.map{|s| [s, s.all_dependencies.dup]}]
      sorted = []
      until to_sort.empty?
        cur = to_sort.select{|s, deps| deps.empty?}.keys.sort_by &:name
        sorted.concat cur
        cur.each{|s| to_sort.delete s}
        to_sort.each_value do |deps|
          deps.replace deps - cur
        end
      end
      sorted
    end

  end
    
  
end
