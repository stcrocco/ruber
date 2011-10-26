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
require_relative 'ui/irb_config_widget'

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
        :PROMPT_I=>"%N(%m):%03n:%i> ",
        :PROMPT_N=>"%N(%m):%03n:%i> ",
        :PROMPT_S=>"%N(%m):%03n:%i%l ",
        :PROMPT_C=>"%N(%m):%03n:%i* ",
        :RETURN=>"=> "
      }
      
      def initialize parent = nil
        super
        @ui = Ui::ToolWidget.new
        @ui.setup_ui self
        @view = @ui.view
        @input = @ui.input
        self.focus_proxy = @input
        @controller = IRBController.new Ruber[:config][:irb, :irb], [], self
        @controller.connect(SIGNAL(:output_ready)){ display_output @controller.output}
        @display_output = true
        @controller.prompts = Ruber[:config][:irb, :prompts]
        @controller.start_irb
        @input.connect(SIGNAL('returnPressed(QString)')){|s| send_to_irb s}
        @input.completion_mode = KDE::GlobalSettings::CompletionAuto
        @controller.connect SIGNAL(:ready) do
          @input.enabled = true
          @input.set_focus if is_active_window
        end
        @ui.restart_irb.connect(SIGNAL(:clicked)){@controller.restart_irb}
        @ui.send_abort.connect(SIGNAL(:clicked)){ @controller.interrupt}
        @controller.connect(SIGNAL(:interrupting_evaluation)){ @display_output = false}
        @controller.connect(SIGNAL(:evaluation_interrupted)){ @display_output = true}
        @controller.connect SIGNAL(:irb_exited) do
          @view.document.clear
          @lines.clear
        end
        @cursor = @view.text_cursor
        @formats = {:input => Qt::TextCharFormat.new, :output => Qt::TextCharFormat.new }
        @lines = []
      end
      
      def stop
        @controller.stop_irb
      end
      
      def load_settings
        @controller.prompts = Ruber[:config][:irb, :prompts]
        @view.font = Ruber[:config][:general, :output_font]
        @formats[:input].foreground = Qt::Brush.new Ruber[:config][:output_colors, :message]
        @formats[:output].foreground = Qt::Brush.new Ruber[:config][:output_colors, :output]
        blk = @view.document.begin
        cur = Qt::TextCursor.new @view.document
        @lines.each do |l|
          cur.set_position blk.position
          cur.move_position Qt::TextCursor::EndOfLine, Qt::TextCursor::KeepAnchor
          cur.char_format = @formats[l]
          blk = blk.next
        end
      end
      slots :load_settings
      
      private
      
      def display_output lines
        return unless @display_output
        @cursor.move_position Qt::TextCursor::End
        lines.each do |l|
          Ruber[:app].process_events
          @cursor.char_format = @formats[l.category]
          @cursor.insert_text l.full_text+"\n"
          @lines << l.category
        end
        @cursor.move_position Qt::TextCursor::End
        @view.text_cursor = @cursor
        @view.ensure_cursor_visible
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
      
      def initialize parent = nil
        super
        @ui = Ui::ConfigWidget.new
        @ui.setup_ui self
      end
      
      def read_settings
        prompts = @settings_dialog.container[:irb, :prompts]
        @ui.prompt_i.text = prompts[:PROMPT_I]
        @ui.prompt_n.text = prompts[:PROMPT_N]
        @ui.prompt_s.text = prompts[:PROMPT_S]
        @ui.prompt_c.text = prompts[:PROMPT_C]
        @ui.prompt_return.text = prompts[:RETURN]
      end
      
      def store_settings
        prompts = {}
        prompts[:PROMPT_I] = @ui.prompt_i.text
        prompts[:PROMPT_N] = @ui.prompt_n.text
        prompts[:PROMPT_S] = @ui.prompt_s.text
        prompts[:PROMPT_C] = @ui.prompt_c.text
        prompts[:RETURN] = @ui.prompt_return.text
        @settings_dialog.container[:irb, :prompts] = prompts
      end
      
    end
    
  end
  
end