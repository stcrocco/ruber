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

require 'delegate'
require 'enumerator'
require 'forwardable'
require 'pathname'
require 'shellwords'
require 'ostruct'

require 'dictionary'
require 'facets/boolean'
require 'facets/enumerable/mash'

module Ruber

=begin rdoc
The Ruber installation directory
=end
  RUBER_DIR = File.expand_path File.join(__FILE__, '..', '..', '..')
  
=begin rdoc
The directory where the Ruber core files are
=end
  RUBER_LIB_DIR = File.join RUBER_DIR, 'lib/'
  
=begin rdoc
The default directory for globally installed plugins
=end
  RUBER_PLUGIN_DIR = File.join RUBER_DIR, 'plugins'
  
=begin rdoc
The Ruber @data@ directory 
=end
  RUBER_DATA_DIR = File.join RUBER_DIR, 'data'
end

module Kernel
  
=begin rdoc
Whether an object is _similar_ to a string
@return [Boolean] *true* if the object is similar to a string and *false* otherwise. In particular
currently it returns *true* for strings and symbol and *false* for all other objects.
=end
  def string_like?
    false
  end
  
=begin rdoc
@return [Binding] the binding of the object
=end
  def obj_binding
    binding
  end
  
  alias :same? :equal?
  
=begin rdoc
Executes the body of the block without emitting warnings

This method sets the @$VERBOSE@ global variable to *nil* (which disables warnings)
before calling the block and restores it to the original value after executing the
block (even if the block raises an exception)
@yield
@return [Object] the value returned by the block
=end
  def silently
    old_verbose, $VERBOSE = $VERBOSE, nil
    begin yield
    ensure
      $VERBOSE = old_verbose
    end
  end
  
end

class Object

=begin rdoc
Prints the given object and the position from which the method was called
@param [Object] the object to print on screen (its @inspect@ method will be used)
@return [nil]
=end
  def debug obj
    $stderr.puts "DEBUG(#{caller[0][/^[^:]+:\d+/]}): #{obj.inspect}\n"
  end
  alias_method :d, :debug
  
end

class OpenStruct
  #This is needed for compatibility with ruby 1.8, where there's an Object#type
  #deprecated method which forbids OpenStruct to define its own, thus breaking
  #the type entry of Options objects
  undef_method :type rescue nil
end

class Object

=begin rdoc
Encloses *self* in an array unless it's already an array

Unlike @Kernel#Array@, this doesn't use the @to_ary@ or @to_a@ methods

@return [Array] *self* enclosed in an array
=end
  def to_array
    [self]
  end
  
end

class Array
  
=begin rdoc
Override of {Object#to_array}

@return [Array] *self*
=end
  def to_array
    self
  end
  
  if RUBY_VERSION.match /8/
=begin rdoc
Choose a random element or n random elements

It's a version for ruby 1.8.7 of Array#sample from ruby 1.9. It uses Array#choice
which only exists in ruby 1.8.7 but this doesn't matter since this method is only
defined in ruby 1.8.7

*Note:* ruby 1.9 already defines this method, so the original version is kept

@param [Integer] n the number of elements to sample
@return [<Object>,Object] if _n_ is 1, then a single element is returned. If _n_
is greater than one, then an array of _n_ elements randomly chosen from those in
the array are returned (without duplicates). If _n_ is greater than the size
of the array, then the returned array will have the size of the array
=end
    def sample n = 1
      if n == 1 then choice
      else
        a = dup
        n = [a.size, n].min
        res = []
        n.times do
          res << a.delete(rand(a.size))
        end
        res
      end
    end
  end
  
=begin rdoc
Converts an array to a hash

Depending on the value of the argument, this method can work as the reverse of
@Hash#to_a@ or as @Hash.[]@.

In the first case, each element of the array must be an array of size 2. The first
element of each inner array will be used as key, while the second will be used as
the corresponding value.

In the second case, this method works exactly as @Hash.[]@
@param [Boolean] pairs whether to work as the inverse of @Hash#to_a@ or as @Hash.[]@
@return [Hash] a hash built as described above
=end
  def to_h pairs = true
    if pairs then self.inject({}){|res, i| res[i[0]] = i[1]; res}
    else Hash[*self]
    end
  end
  
=begin rdoc
Whether the array contains a single element and that element is equal to a given value
@param [Object] value the object to compare the only element of the array
@return [Boolean] *true* if the array has size 1 and its element is equal (according
to @==@) to _value_ and *false* otherwise.
=end
  def only? value
    self.size == 1 and self[0] == value
  end
  
end

class String
  
=begin rdoc
Splits the string in lines.
  
It's a shortcut for str.split("\n")

@return [<String>] an array containing the lines which make up the string
=end
  def split_lines
    split "\n"
  end
  
=begin rdoc
Overryde of {Kernel#string_like?}

@return [Boolean] *true*
=end
  def string_like?
    true
  end
  
end

class Symbol
  
=begin rdoc
Overryde of {Kernel#string_like?}

@return [Boolean] *true*
=end
  def string_like?
    true
  end

end

class Pathname

=begin rdoc
Whether the pathname represents a file or directory under the directory represented
by another pathname

@param [Pathname,String] the string or pathname representing the directory which
can be parent of *self*
=end
  def child_of? other
    other = Pathname.new(other) if other.is_a? String
    self.relative_path_from(other).to_s[0..2]!= '../'
  end
  
end

class Dictionary

# In ruby 1.9, it seems that passing a lambda to one of the Array#each or similar
# methods doesn't unpack the elements of the array, so the call to the lambda
# fails because of wrong number of arguments
  if RUBY_VERSION.match /9/

=begin rdoc
@private
Works as the method with the same name in facets but works around a bug with facets
and ruby 1.9
=end
    def order_by_value
      @order_by = lambda { |i| i[0] }
      order
      self
    end

=begin rdoc
@private
Works as the method with the same name in facets but works around a bug with facets
and ruby 1.9
=end
    def order_by_key
      @order_by = lambda { |i| i[0] }
      order
      self
    end
    
  end

=begin rdoc
Calls the block passing it each key and the corresponding value starting from the
last
@yield key, value
@return [Dictionary] *self*
=end
  def reverse_each
    order.reverse_each{|k| yield k, @hash[k] }
    self
  end
  
end

module Enumerable
  
=begin rdoc
Finds the first element for which the block returns a true value and returns the
value of the block

It works like @Enumerable#find@, but, instead of returning the element for which
the block returned a true value, it returns the value returned by the block.
@yield obj
@return [Object, nil] the first non-false value returned by the block or *nil*
if the block returns *nil* or *false* for all elements

@example Using @find!@
  [1, 2, 3, 4].find!{|i| 2*i if i > 2}
  => 6 #(3*2)
=end
  def find!
    each do |obj|
      res = yield obj
      return res if res
    end
    nil
  end
  alias_method :find_and_map, :find!
  
  alias_method :map_hash, :mash
end

module Ruber

=begin rdoc
Module for objects which can be activated and disactivated. It provides methods
for inquiring the active state and to change it. If the object is a @Qt::Object@,
and has an @activated()@ and a @deactivated@ signals, they will be
emitted when the state change. If the object is not a @Qt::Object@, or doesn't have
those signals, everything else will still work (in the rest of the documentation,
every time emitting a signal is mentioned, it's understood that the signal won't
be emitted if it doesn't exist).

Classes including this module may customize what is done when the state change by
overriding the {#do_activation} and {#do_deactivation} methods.

Classes mixing-in this module should initialize an instance variable called
<tt>@active</tt>. If they don't, one initialized to *nil* will be created the first
time it'll be needed (possibly with a warning).
=end
  module Activable
    
=begin rdoc
@return [Boolean] whether the object is active or not
=end
    def active?
      @active
    end
    
=begin rdoc
Makes the object inactive
    
If previously the object was active, emits the @deactivated@ signal
@return [nil]
=end
    def deactivate
      self.active = false
      nil
    end

=begin rdoc
Makes the object active
    
If previously the object was inactive, emits the @activated@ signal.
@return [nil]
=end
    def activate
      self.active = true
      nil
    end

=begin rdoc
Enables or disables the object

If the state of the object changes, the {#do_activation} or {#do_deactivation}
methods are called. This happens _after_ the state has been changed.

@param [Object] val whether the object should be activated or deactivated. If the
object is a true value, the object will be activated, otherwise it will be deactivated
@return [Object] _val_
=end
    def active= val
      old = @active
      @active = val.to_bool
      if old != @active
        @active ? do_activation : do_deactivation
      end
    end
    
    private
    
=begin rdoc
Method called after the state changes from active to inactive

It emits the @deactivated@ signal, if the class including the module has the signal.

Including classes can override this method to perform other actions every time the
object becomes inactive. In this case, they should call *super* if they want the
signal to be emitted
@return [nil]
=end
    def do_deactivation
      emit deactivated rescue NameError
    end

=begin rdoc
Method called after the state changes from inactive to active

It emits the @activated@ signal, if the class including the module has the signal.

Including classes can override this method to perform other actions every time the
object becomes active. In this case, they should call *super* if they want the
signal to be emitted
@return [nil]
=end
    def do_activation
      emit activated rescue NameError
    end
    
  end
    
end

module Shellwords

=begin rdoc
Similar to @Shellwords.split@, but attempts to include quotes in the returned
array for strings containing spaces.
  
Since it's impossible to find out from the output of @Shellwords#split@ whether a string was
quoted with signle or double quotes, the following approach is taken: if the
string contains double quotes, it's sourrounded with single quotes; otherwise
double quotes are used.

TODO: improve on the above algorithm.
@param [String] str the string to split
@return [<String>] an array as with @Shellwords#split@ but with strings containing
whitespaces quoted according to the above algorithm
=end
  def self.split_with_quotes str
    res = split str
    res.map! do |s|
      unless s.include? ' ' then s
      else
        quote = s.include?('"') ? "'" : '"'
        quote + s + quote
      end
    end
    res
  end
  
end
