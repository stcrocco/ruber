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

    class Search

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
            list << find_classes(drv, cls) if cls =~ regexp
          end
          content = prepare_class_list list
        else content = {}
        end
        content
      end

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

      def find_classes drv, name
        begin cls = drv.expand_class(Regexp.quote(name))
        rescue RDoc::RI::Driver::NotFoundError
          return []
        end
        stores = drv.classes[cls]
        return unless stores
        classes = []
        stores.each do |s|
          classes << [s.load_class(cls), s]
        end
        classes
      end

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