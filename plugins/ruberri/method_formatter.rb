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
      
      def initialize method, store, store_type
        @store = RDoc::RI::Store.new store, store_type
        cls= method.split(/(?:::)|#/, 2)[0]
        @method = @store.load_method cls, method
      end
      
      def to_html
        title = "#{@method.full_name}"
        title << " (from #{@store.friendly_path})" unless @store.friendly_path =~ /ruby core/
        parts = [RDoc::Markup::Heading.new(1, title)]
        parts << format_aliases
        parts << format_arglists
        parts << @method.comment
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
      
      def format_arglists
        return unless @method.arglists
        res = []
        arglists = @method.arglists.chomp.split("\n")
        arglists.each do |l|
          res << RDoc::Markup::Verbatim.new(l)
        end
        res
      end
      
      def format_aliases
        return if @method.aliases.empty?
        res = [RDoc::Markup::Heading.new(1, 'Also known as')]
        items = @method.aliases.map do |a|
          RDoc::Markup::ListItem.new nil, RDoc::Markup::Paragraph.new(a)
        end
        list = RDoc::Markup::List.new :BULLET, *items
        res << list
        res
      end
      
    end
    
  end
  
end

if $0 == __FILE__
  mth, store, store_type = *ARGV
  puts Ruber::RI::MethodFormatter.new(mth, store, store_type.to_sym).to_html
end