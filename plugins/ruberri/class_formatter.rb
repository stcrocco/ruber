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
require 'erb'

module Ruber

  module RI

=begin rdoc
Class with the task of producing an HTML page from the @RI@ documentation for a
class or module.

The HTML page is generated using an ERB template contained in the @class.rhtml@
file.
=end
    class ClassFormatter

     Data = Struct.new :title, :type, :name, :inheritance, :included, :comment,
         :constants, :class_methods, :instance_methods, :store, :store_type

=begin rdoc
Helper class providing access to information provided by @RI@ from the ERB template.

@!attribute title
  @return [String] the title of the page
@!attribute type
  @return [String] the type of entity (@module@ or @class@)
@!attribute name
  @return [String] the name of the class
@!attribute inheritance
 @return [String] the name of the base class or an empty string if the base
    class is @Object@
@!attribute included
  @return [<String>] a list of all included modules
@!attribute comment
  @return [String] the description associated with the class
@!attribute constants
  @return [{String => String}] the names of the constants defined in the class
    together with their descriptions
@!attribute class_methods
  @return [<RDoc::AnyMethod>] a list of class methods
@!attribute instance_methods
  @return [<RDoc::AnyMethod>] a list of instance methods
@!attribute store
  @return [String] the path to the store file
@!attribute store_type
  @return [String] the type of store

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
@param [String] cls the full name of the class
@param [String] store the path of the file containing the store
@param [String] store_type the type of the store
=end
      def initialize cls, store, store_type
        @store = RDoc::RI::Store.new store, store_type
        @cls = @store.load_class cls
        @data = Data.new
        opts = RDoc::Options.new.tap{|o| o.pipe = true}
        @formatter = RDoc::Markup::ToHtml.new opts
        @data.store_type = store_type
        @data.store = store
      end

=begin rdoc
Generates the HTML page for the class

@return [String] the HTML code of the page
=end
      def to_html
        superclass = @cls.superclass if @cls.type == :class
        if superclass and superclass != 'Object'
          @data.inheritance = " < #{superclass}"
        elsif superclass == 'Object' then @data.inheritance = ''
        end
        title = "#{@cls.type.capitalize} #{@cls.full_name}#{superclass}"
        title << " (from #{@store.friendly_path})" unless @store.friendly_path =~ /ruby core/
        @data.title = title
        @data.type = @cls.type.to_s
        @data.name= @cls.full_name
        @data.included = @cls.includes
        @data.comment = format_document @cls.comment
        @data.constants = {}
        @data.class_methods = []
        @data.instance_methods = []
        @cls.constants.each do |c|
          @data.constants[c.name] = format_document c.comment
        end
        inst_methods, cls_methods = @cls.method_list.partition{|m| m.full_name.include? '#'}
        cls_methods.each do |m|
          @data.class_methods << m
        end
        inst_methods.each{|m| @data.instance_methods << m}
        erb = ERB.new File.read(File.join(File.dirname(__FILE__), 'class.rhtml'))
        erb.result @data.get_binding
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
  cls, store, store_type = *ARGV
  puts Ruber::RI::ClassFormatter.new(cls, store, store_type.to_sym).to_html
end
