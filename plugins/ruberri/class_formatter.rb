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
    
    class ClassFormatter
      
      def initialize cls, store
        @cls = cls
        @store = store
      end
      
      def to_html
        superclass = @cls.superclass if @cls.type == :class
        if superclass and superclass != 'Object'
          superclass = " < #{superclass}"
        elsif superclass == 'Object' then superclass = ''
        end
        title = "#{@cls.type.capitalize} #{@cls.full_name}#{superclass}"
        title << " (from #{@store.friendly_path})" unless @store.friendly_path =~ /ruby core/
        parts = [RDoc::Markup::Heading.new(1, title)]
        parts << format_included
        parts << @cls.comment
        parts << format_constants
        parts << format_class_methods
        parts << format_instance_methods
        parts.compact!
        doc = RDoc::Markup::Document.new
        last = parts.count - 1
        parts.each_with_index do |prt, i|
          if prt.is_a? Array then prt.each{|x| doc << x}
          else doc << prt
          end
          doc << RDoc::Markup::Rule.new(1) unless i == last
        end
        formatter = RDoc::Markup::ToHtml.new
        doc.accept formatter
      end
      
      private
      
      def format_included
        included = @cls.includes
        unless included.empty?
          res = []
          res << RDoc::Markup::Heading.new(2, "Included modules")
          list = RDoc::Markup::List.new :BULLET
          @cls.includes.each{|i| list << RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new(i.module.to_s) )}
          res << list
          res
        end
      end
      
      def format_class_methods
        methods = @cls.method_list.reject{|m| m.full_name.include? '#'}
        unless methods.empty?
          res = []
          res << RDoc::Markup::Heading.new(2, "Class methods")
          method_list = methods.map do |m|
            m.name
          end
          res << RDoc::Markup::Paragraph.new(method_list.join(' '))
          res
        end
      end
      
      def format_instance_methods
        methods = @cls.method_list.select{|m| m.full_name.include? '#'}
        unless methods.empty?
          res = []
          res << RDoc::Markup::Heading.new(2, "Instance methods")
          method_list = methods.map{|m| "<tt>#{m.name}</tt>"}
          res << RDoc::Markup::Paragraph.new(method_list.join(' '))
          res
        end
      end
      
      def format_constants
        return if @cls.constants.empty?
        res = []
        res << RDoc::Markup::Heading.new(2, "Constants defined in this #{@cls.type}")
        last = @cls.constants.count - 1
        @cls.constants.each_with_index do |c, i|
          res << RDoc::Markup::Heading.new(3, "<tt>#{c.name}</tt>")
          res << c.comment
          
        end
        res
      end
      
    end
    
  end
  
end