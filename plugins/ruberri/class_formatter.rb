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

    class ClassFormatter

     Data = Struct.new :title, :type, :name, :inheritance, :included, :comment,
         :constants, :class_methods, :instance_methods, :store, :store_type

     class Data
       def get_binding
         binding
       end
     end

      def initialize cls, store, store_type
        @store = RDoc::RI::Store.new store, store_type
        @cls = @store.load_class cls
        @data = Data.new
        opts = RDoc::Options.new.tap{|o| o.pipe = true}
        @formatter = RDoc::Markup::ToHtml.new opts
        @data.store_type = store_type
        @data.store = store
      end

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
