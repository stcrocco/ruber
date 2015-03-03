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

require 'rdoc/ri/driver'
require 'rdoc/ri/store'
require 'rdoc/markup/document'
require 'rdoc/markup/to_html'

module Ruber

  module RI

    class MethodFormatter

      Data = Struct.new :store, :method, :method_origin, :arglists, :aliases,
          :comment

      class Data
        def get_binding
          binding
        end
      end

      def initialize method, store, store_type
        @store = RDoc::RI::Store.new store, store_type
        cls= method.split(/(?:::)|#/, 2)[0]
        @method = @store.load_method cls, method
        @data = Data.new @store, @method
        opts = RDoc::Options.new.tap{|o| o.pipe = true}
        @formatter = RDoc::Markup::ToHtml.new opts
      end

      def to_html
        erb = ERB.new File.read(File.join(File.dirname(__FILE__), 'method.rhtml'))
        @data.method_origin = @store.friendly_path =~ /ruby core/ ? '' : " (from #{@store.friendly_path})"
        @data.aliases = @method.aliases.map{|a| a.name}
        @data.arglists = @method.arglists.chomp.split "\n"
        @data.comment = format_document @method.comment
        bnd = @data.get_binding
        erb.result bnd #@data.get_binding
      end

      private

      def format_document doc
        doc.accept @formatter
      end

    end

  end

end

if $0 == __FILE__
  mth, store, store_type = *ARGV
  puts Ruber::RI::MethodFormatter.new(mth, store, store_type.to_sym).to_html
end
