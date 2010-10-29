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

require_relative 'ui/project_widget'

module Ruber
  
  module RubyRunner
    
=begin rdoc
Project widget for the ruby runner plugin
=end
    class ProjectWidget < ProjectConfigWidget
      
=begin rdoc
Creates a new instance

@param [Ruber::AbstractProject] prj the project the widget is for
=end
      def initialize prj
        super
        @ui = Ui::RubyRunnerProjectWidget.new
        @ui.setupUi self
        @ui._ruby__ruby.add_items Ruber[:config][:ruby, :interpreters]
      end
      
=begin rdoc
Reader for the @ruby/ruby@ option

It selects the entry having text equal to _value_ in the combo box (or the first
entry if there's no entry with text _value_)

@param [String] value the path of the interpreter to use
=end
      def interpreter= value
        item = @ui._ruby__ruby.each_with_index.find{|txt, i| txt == value}
        idx = item ? item[1] : 0
        @ui._ruby__ruby.current_index = idx
      end
      
    end
    
  end
  
end