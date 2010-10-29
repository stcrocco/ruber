=begin
    Copyright (C) 2010 by Stefano Crocco   
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

require 'shellwords'

require_relative 'ui/config_widget'

module Ruber
  
  module RubyRunner

=begin rdoc
Config widget for the ruby runner plugin
=end
    class ConfigWidget < Qt::Widget
      
      slots :update_default_interpreter
      
=begin rdoc
Creates a new widget

@param [Qt::Widget] parent the widget's parent
=end
      def initialize parent = nil
        super
        @ui = Ui::RubyRunnerConfigWidget.new
        @ui.setupUi self
        connect @ui._ruby__interpreters, SIGNAL(:changed), self, SLOT(:update_default_interpreter)
      end
      
=begin rdoc
Writer for the @ruby/ruby_options@ setting

@return [nil]
=end
      def read_ruby_options val
        @ui._ruby__ruby_options.text = val.join ' '
        nil
      end
      
=begin rdoc
Reader for the @ruby/ruby_options@ setting

@return [<String>] with an entry per option. Options containing spaces are quoted
=end
      def store_ruby_options
        Shellwords.split_with_quotes @ui._ruby__ruby_options.text
      end

=begin rdoc
Writer for the @ruby/ruby@ setting

@param [String] the path of the default interpreter
@return [nil]
=end
      def default_interpreter= value
        it = @ui._ruby__ruby.each_with_index.find{|txt, i| txt == value}
        @ui._ruby__ruby.current_index = it ? it[1] : 0
        nil
      end

      private
      
=begin rdoc
Fills the "Ruby interpreters widget"

Before filling the widget, clears it. After filling the widget, it updates the
"Default interpreter" widget.

@param [<String>] a list of the paths of the availlable interpreters
=end
      def fill_interpreters value
        @ui._ruby__interpreters.clear
        @ui._ruby__interpreters.insert_string_list value
        update_default_interpreter
      end

=begin rdoc
Fills the "Default interpreter" combo box according to the availlable interpreters

This method attempts to preserve the current entry if possible. This means that
if an entry with the same text still exists, it will become current.

@return [nil]
=end
      def update_default_interpreter
        old_current = @ui._ruby__ruby.current_text
        @ui._ruby__ruby.clear
        @ui._ruby__ruby.add_items @ui._ruby__interpreters.items
        idx = @ui._ruby__ruby.items.index old_current
        @ui._ruby__ruby.current_index = idx ? idx : 0
        nil
      end
      
    end
    
  end
  
end