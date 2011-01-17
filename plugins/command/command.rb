=begin 
    Copyright (C) 2010,2011 by Stefano Crocco   
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

require 'command/output'
require_relative 'ui/tool_widget'

module Ruber

=begin rdoc
Plugin which allows to evaluate some ruby code from within the Ruber environment,
thus effectively giving Ruber commands (this is different from the Ruby Runner
plugin, which simply starts a new ruby interpreter and runs a script in it).

This plugin doesn't provide a plugin class but just a tool widget where the user
can enter the code and a button to execute it. It also doesn't provide any
API for the feature. Beside the editor widget, the plugin also provides an output
widget, where the text written to standard output and standard error by the code
executed will be displayed.

*Note:* the ruby code is executed in the top level context. Any exception
raised by the code won't cause Ruber to crash, but will be displayed in a dialog.
=end
  module CommandPlugin   
    
=begin rdoc
The tool widget where the user can enter the ruby code to execute.
=end
    class ToolWidget < Qt::Widget
            
      slots :execute_command, :load_settings

=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::CommandToolWidget.new
        @ui.setup_ui self
        self.focus_proxy = @ui.editor
        connect @ui.execute, SIGNAL(:clicked), self, SLOT(:execute_command)
        @ui.clear.connect(SIGNAL(:clicked)){@ui.output.clear}
      end
      
=begin rdoc
Executes the text in the tool widget in the ruby interpreter where Ruber is running
in. If an exception is raised by the code, it won't be propagated to Ruber. Instead,
it will be displayed on standard error and in a message box.
      
@return [Boolean] *true* if the code was executed successfully and *false* if an exception
was raised.
=end
      def execute_command
        code = @ui.editor.to_plain_text
        begin 
          old_stdout = $stdout
          old_stderr = $stderr
          $stdout = Output.new @ui.output, Ruber[:config][:output_colors, :output], $stdout.fileno
          $stderr = Output.new @ui.output, Ruber[:config][:output_colors, :error], $stderr.fileno
          eval code, TOPLEVEL_BINDING, 'COMMAND'
          true
        rescue Exception => ex
          dlg = ExceptionDialog.new ex, Ruber[:main_window], true, 
              'The command you issued raised the following exception:'
          dlg.set_button_text KDE::Dialog::Ok, i18n('Ok')
          dlg.exec
          $stdout = old_stdout
          $stderr = old_stderr
          false
        end
      end
      
=begin rdoc
Called whenever the global settings change and when the plugin is first loaded

Sets the font of the editor to the font chosen by the user as the output font
@return [nil]
=end
      def load_settings
        font = Ruber[:config][:general, :output_font]
        @ui.editor.font = font
        @ui.output.font = font
        nil
      end
      
    end
    
  end
  
end