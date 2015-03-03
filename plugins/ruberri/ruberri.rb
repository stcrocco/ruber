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

require 'rdoc/ri/driver'
require 'rdoc/ri/store'
require 'open3'
require 'yaml'

module Ruber

  module RI

    class Plugin < Ruber::Plugin

      def search text
        cmd = [ruby, File.join(File.dirname(__FILE__), 'search.rb'), text]
        list = nil
        err = nil
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          list = stdout.read
          err = stderr.read
          status = thr.value
        end
        if status.success?
          display_search_result YAML.load(list)
        else
          text = <<-EOS
<h1>Error</h1>
<p>It was impossible to search the RI database. The reported error was:</p>
<verbatim>
#{err}
</verbatim>
EOS
          @tool_widget.content = text
        end

      end

      private

      def ruby
        Ruber[:ruby_development].interpreter_for Ruber[:world].active_document
      end

      def display_search_result found
        if found[:list] and found[:list].count > 1
          if found[:type] == :class then content = format_class_list found[:list]
          else content = format_method_list found[:list]
          end
          @tool_widget.content = content
        elsif found[:list] and found[:list].count == 1
          obj = found[:list][0]
          display found[:type], obj[:store], obj[:store_type], obj[:name]
        else @tool_widget.content = '<h1>Nothing found</h1>'
        end
      end

      def display_url url
        scheme = url.scheme
        store, type, name = url.path.split('$', 3)
        display scheme.to_sym, store, type.to_sym, name
      end
      slots 'display_url(QUrl)'

      def display type, store, store_type, name
        if type == :method
          @tool_widget.content = format_method name, store, store_type
        else
          @tool_widget.content = format_class name, store, store_type
        end
      end

      def format_class_list classes
        res = "<h1>Results from RI</h1>"
        classes.each do |data|
          encoded_name = Qt::Url.to_percent_encoding data[:name]
          url = "class://#{data[:store]}$#{data[:store_type]}$#{encoded_name}"
          res << %[<p><a href="#{url}">#{data[:name]} &ndash; from #{data[:friendly_store]}</a></p>]
        end
        res
      end

      def format_method_list methods
        res = "<h1>Results from RI</h1>"
        methods.each do |data|
          encoded_name = Qt::Url.to_percent_encoding(data[:name])
          url = "method://#{data[:store]}$#{data[:store_type]}$#{encoded_name}"
          res << %[<p><a href="#{url}">#{data[:name]} &ndash; from #{data[:friendly_store]}</a></p>]
        end
        res
      end

      def format_class cls, store, store_type
        cmd = [ruby, File.join(File.dirname(__FILE__), 'class_formatter.rb'), cls, store, store_type.to_s]
        html = nil
        err = nil
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          html = stdout.read
          err = stderr.read
          status = thr.value
        end
        if status.success?
          @tool_widget.content = html
        else
          text = <<-EOS
<h1>Error</h1>
<p>It was impossible to loop #{cls} up in the RI database. The reported error was:</p>
<verbatim>
#{err}
</verbatim>
EOS
        end

      end

      def format_method method, store, store_type
        cmd = [ruby, File.join(File.dirname(__FILE__), 'method_formatter.rb'), method, store, store_type.to_s]
        html = nil
        err = nil
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          html = stdout.read
          err = stderr.read
          status = thr.value
        end
        if status.success?
          @tool_widget.content = html
        else
          text = <<-EOS
<h1>Error</h1>
<p>It was impossible to look #{method} up the RI database. The reported error was:</p>
<verbatim>
#{err}
</verbatim>
EOS
        end
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
        @ui = Ruber::Ui::RIToolWidget.new
        @ui.setup_ui self
        connect @ui.search_term, SIGNAL(:returnPressed), @ui.search, SIGNAL(:clicked)
        connect @ui.search, SIGNAL(:clicked), self, SLOT(:start_search)
        @ui.content.open_links = false
        connect @ui.content, SIGNAL('anchorClicked(QUrl)'), Ruber[:ruberri], SLOT('display_url(QUrl)')
      end

      def content
        @ui.content.to_html
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