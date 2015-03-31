=begin
    Copyright (C) 2011 by Stefano Crocco
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
require 'rdoc/ri/driver'

module Ruber

  module RI

=begin rdoc
Helper class which performs a search in the @RI@ database
=end
    class Search

=begin rdoc
Performs a search in the @RI@ database

The search results are returned in a hash with the following entries:

- @:type@::= whether the search returned results for classes or methods. It can
  be either @:class@ or @:method@
- @@:list@::= a list containing the entries found in the RI database

Each entry is a hash with the following keys:

- @:store@::= the path of the file containing the store with the entry
- @:friendly_store@::= a human friendly name for the store
- @:store_type@::= the type of store
- @:name@::= the full name of the class or method

@param [String] text the text to search
@return [Hash] a hash containing the results of the search
=end
      def search text
        drv = RDoc::RI::Driver.new
        classes = find_classes drv, text
        methods = find_methods drv, text
        if classes then content = prepare_class_list classes
        elsif methods then content = prepare_method_list methods
        elsif !(hash = drv.classes).empty?
          regexp = /::#{Regexp.quote text}$/
          list = []
          hash.each_key do |cls|
            list.concat find_classes(drv, cls) if cls =~ regexp
          end
          content = prepare_class_list list
        else content = {}
        end
        content
      end

=begin rdoc
Puts RI data from a list of classes into a hash

@param [<(RDoc::NormalClass, RDoc::Store)>] classes a list of classes with the
  store they're from
@return [Hash] a hash containing information for the given classes. The hash has
  the keys @:type@ and @:list@. @:key@ is always @:class@ (even for modules),
  while @:list@ is a list of hashes, each describing one of the classes. Each
  hash has the following entries:

  - @:store@::= the name of the store file
  - @:friendly_store@::= a human friendly version of the store path
  - @:store_type@::= the type of store
  - @:name@::= the fill name of the class
=end
      def prepare_class_list classes
        found = {:type => :class}
        list = []
        classes.each do |cls, store|
          data = {
            :store => store.path,
            :friendly_store => store.friendly_path,
            :store_type => store.type,
            :name => cls.full_name
          }
          list << data
        end
        found[:list] = list
        found
      end

=begin rdoc
Puts RI data from a list of methods into a hash

@param [<(RDoc::NormalClass, RDoc::Store)>] methods a list of classes with the
  store they're from
@return [Hash] a hash containing information for the given classes. The hash has
  the keys @:type@ and @:list@. @:key@ is always @:class@ (even for modules),
  while @:list@ is a list of hashes, each describing one of the classes. Each
  hash has the following entries:

  - @:store@::= the name of the store file
  - @:friendly_store@::= a human friendly version of the store path
  - @:store_type@::= the type of store
  - @:name@::= the fill name of the class
=end
      def prepare_method_list methods
        found = {:type => :method}
        list = []
        methods.each do |mth, store|
          data = {
            :store => store.path,
            :friendly_store => store.friendly_path,
            :store_type => store.type,
            :name => mth.full_name
          }
          list << data
        end
        found[:list] = list
        found
      end

=begin rdoc
Find classes with a given name

@param [RDoc::Ri::Driver] drv the ri driver to look for classes
@param [String] name the name of the class
@return [<(RDoc::NormalClass, RDoc::Store)>] a list of found classes together
  with the store they're in
=end
      def find_classes drv, name
        begin cls = drv.expand_class(Regexp.quote(name))
        rescue RDoc::RI::Driver::NotFoundError
          return
        end
        stores = drv.classes[cls]
        return unless stores
        classes = []
        stores.each do |s|
          classes << [s.load_class(cls), s]
        end
        classes
      end

=begin rdoc
Find methods with a given name

@param [RDoc::Ri::Driver] drv the ri driver to look for methods
@param [String] name the name of the method
@return [<(RDoc::AnyMethod, Rdoc::Store)>] a list of found methods together
  with the store they're in
=end
      def find_methods drv, name
        found = drv.load_methods_matching name
        return nil if found.empty?
        filtered = drv.filter_methods found, name
        methods = []
        filtered.each do |store, mthds|
          mthds.each{|m| methods << [m, store]}
        end
        methods.empty? ? nil : methods
      end

    end

  end

end

puts YAML.dump(Ruber::RI::Search.new.search(ARGV[0] || ''))