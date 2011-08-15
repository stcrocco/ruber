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

require_relative 'ui/tool_widget'
require_relative 'class_formatter'
require_relative 'method_formatter'

require 'rdoc/ri/driver'
require 'rdoc/ri/store'

module Ruber
  
  module RI
    
    class Plugin < Ruber::Plugin
      
      def search text
        drv = RDoc::RI::Driver.new
        classes = find_classes drv, text
        methods = find_methods drv, text
        if classes and classes.count > 1 
          content = format_class_list classes
        elsif classes and classes.count == 1 
          content = format_class *classes[0]
        elsif methods and methods.count > 1
          content = format_method_list methods
        elsif methods and methods.count == 1
          content = format_method *methods[0]
        elsif !(hash = drv.classes).empty?
          regexp = /::#{Regexp.quote text}$/
          list = []
          hash.each_key do |cls|
            list << find_classes(drv, cls) if cls =~ regexp
          end
          content = format_class_list list
        else content = '<h1>Nothing found</h1>'
        end
        @tool_widget.content = content
      end
      
      private 
      
      def display_url url
        scheme = url.scheme
        store, type, name = url.path.split('$', 3)
        store = RDoc::RI::Store.new store, type.to_sym
        if scheme == 'method'
          cls= name.split(/(?:::)|#/, 2)[0]
          @tool_widget.content = format_method store.load_method( cls, name), store
        else 
          @tool_widget.content = format_class(store.load_class(name), store)
        end
      end
      slots 'display_url(QUrl)'
      
      def format_class_list classes
        res = "<h1>Results from RI</h1>"
        classes.each do |cls, store|
          url = "class://#{store.path}$#{store.type}$#{cls.full_name}"
          res << %[<p><a href="#{url}">#{cls.full_name} &ndash; from #{store.friendly_path}</a></p>]
        end
        res
      end
      
      def format_method_list methods
        res = "<h1>Results from RI</h1>"
        methods.each do |mth, store|
          encoded_name = Qt::Url.to_percent_encoding(mth.full_name)
          url = "method://#{store.path}$#{store.type}$#{encoded_name}"
          res << %[<p><a href="#{url}">#{mth.full_name} &ndash; from #{store.friendly_path}</a></p>]
        end
        res
      end
      
      def format_class cls, store
        formatter = ClassFormatter.new cls, store
        formatter.to_html
      end
      
      def format_method method, store
        formatter = MethodFormatter.new method, store
        formatter.to_html
      end
      
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
    
    class ToolWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::RIToolWidget.new
        @ui.setup_ui self
        connect @ui.search_term, SIGNAL(:returnPressed), @ui.search, SIGNAL(:clicked)
        connect @ui.search, SIGNAL(:clicked), self, SLOT(:start_search)
        @ui.content.open_links = false
        connect @ui.content, SIGNAL('anchorClicked(QUrl)'), Ruber[:ruberri], SLOT('display_url(QUrl)')
      end
      
      def content= txt
        @ui.content.text = txt
      end
      
      def set_focus reason = Qt::OtherFocusReason
        super
        @ui.search_term.set_focus
      end

      private
      
      def start_search
        text = @ui.search_term.text
        unless text.empty?
          Ruber[:ruberri].search text
        end
      end
      slots :start_search
      
    end
    
  end
  
end