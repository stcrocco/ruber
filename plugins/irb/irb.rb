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

require 'irb/irb_controller'
require_relative 'ui/irb_tool_widget'

module Ruber
  
  module IRB
    
    class Plugin < Ruber::Plugin
      
      def shutdown
        @widget.stop
        super
      end
      
    end
    
    class IRBWidget < Qt::Widget
      
      PROMPTS = {
        :PROMPT_I => '',
        :PROMPT_N => '',
        :PROMPT_S => '',
        :PROMPT_C => '',
        :RETURN => "==> "
      }
      
      def initialize parent = nil
        super
        @ui = Ui::ToolWidget.new
        @ui.setup_ui self
        @view = @ui.view
        @input = @ui.input
        self.focus_proxy = @input
        @controller = IRBController.new Ruber[:config][:irb, :irb], [], self
        @controller.connect SIGNAL('output_received()') do
          display_output @controller.output
        end
        @display_output = true
        @controller.prompts = PROMPTS
        @controller.start_irb
        @input.connect(SIGNAL('returnPressed(QString)')){|s| send_to_irb s}
        @input.completion_mode = KDE::GlobalSettings::CompletionAuto
        @controller.connect SIGNAL(:ready) do
          @input.enabled = true
          @input.set_focus if is_active_window
        end
        @ui.restart_irb.connect(SIGNAL(:clicked)) do
          @controller.restart_irb
        end
        @ui.send_abort.connect(SIGNAL(:clicked)) do
          @controller.interrupt
        end
        @controller.connect(SIGNAL(:interrupting_evaluation)) do
          @display_output = false
        end
        @controller.connect(SIGNAL(:evaluation_interrupted)) do
          @display_output = true
        end
        @cursor = @view.text_cursor
        @formats = {
          :input => Qt::TextCharFormat.new{|c| c.foreground = Qt::Brush.new Ruber[:config][:output_colors, :message]},
          :output => Qt::TextCharFormat.new{|c| c.foreground = Qt::Brush.new Ruber[:config][:output_colors, :output]}
        }
      end
      
      def stop
        @controller.stop
      end
      
      private
      
      def display_output lines
        return unless @display_output
        @cursor.move_position Qt::TextCursor::End
        lines.each do |l|
          Ruber[:app].process_events
          @cursor.char_format = @formats[l.category]
          @cursor.insert_text l.full_text+"\n"
        end
      end
      
      def send_to_irb line
        @input.completion_object.add_item line
        @input.insert_item 0, line
        @input.edit_text = ''
        @input.enabled = false
        @controller.send_to_irb [line]
      end
      
    end
    
    class ConfigWidget < Qt::Widget
      
    end
    
  end
  
end