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

=begin rdoc
Class with the task of producing an HTML page from the @RI@ documentation for a
method.

The HTML page is generated using an ERB template contained in the @method.rhtml@
file.
=end
    class MethodFormatter

      Data = Struct.new :store, :method, :method_origin, :arglists, :aliases,
          :comment
=begin rdoc
Helper class providing access to information provided by @RI@ from the ERB template.

@!attribute store
  @return [String] the path to the store file
@!attribute method
  @return [RDoc::AnyMethod] the object containing information about the method
@!attribute method_origin
  @return [String] the source of the method
@!attribute arglists
  @return [<String>] the various argument lists for the method
@!attribute aliases
  @return [<String>] a list of aliases for the method
@!attribute comment
  @return [String] the description associated with the class

@!method initialize
  Returns a new instance of Data

  All attributes are set to @nil@
  @return [Data]
=end

      class Data
=begin rdoc
The @Binding@ associated with the instance

@return [Binding] the @Binding@ associated with the instance. This is needed
  by ERB
=end
        def get_binding
          binding
        end
      end

=begin rdoc
@param [String] method the full name of the method
@param [String] store the path of the file containing the store
@param [String] store_type the type of the store
=end
      def initialize method, store, store_type
        @store = RDoc::RI::Store.new store, store_type
        cls= method.split(/(?:::)|#/, 2)[0]
        @method = @store.load_method cls, method
        @data = Data.new @store, @method
        opts = RDoc::Options.new.tap{|o| o.pipe = true}
        @formatter = RDoc::Markup::ToHtml.new opts
      end

=begin rdoc
Generates the HTML page for the method

@return [String] the HTML code of the page
=end
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

=begin rdoc
Generates HTML code from the RDoc-formatted documentation

@param [RDoc::Markup::Document] doc the document to format
=end
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
