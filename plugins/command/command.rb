module Ruber

=begin rdoc
Plugin which allows to evaluate some ruby code from within the Ruber environment,
thus effectively giving Ruber commands (this is different from the Ruby Runner
plugin, which simply starts a new ruby interpreter and runs a script in it).

This plugin doesn't provide a plugin class but just a tool widget where the user
can enter the code and a button to execute it. It also doesn't provide any
API for the feature.

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
        self.layout = Qt::VBoxLayout.new self
        @editor = Qt::PlainTextEdit.new
        layout.add_widget @editor
        self.focus_proxy = @editor
        @button = Qt::PushButton.new("Execute")
        connect @button, SIGNAL(:clicked), self, SLOT(:execute_command)
        layout.add_widget @button
      end
      
=begin rdoc
Executes the text in the tool widget in the ruby interpreter where Ruber is running
in. If an exception is raised by the code, it won't be propagated to Ruber. Instead,
it will be displayed on standard error and in a message box.
      
@return [Boolean] *true* if the code was executed successfully and *false* if an exception
was raised.
=end
      def execute_command
        code = @editor.to_plain_text
        begin 
          eval code, TOPLEVEL_BINDING, 'COMMAND'
          true
        rescue Exception => ex
          lines = ex.message.split_lines
          msg = "<i></i>The command you issued raised the following Exception:<br/><pre>#{ex.message}</pre>"
          details = "<pre>#{ex.message}\n\n#{ex.backtrace.join("\n")}"
          KDE::MessageBox.detailed_sorry Ruber[:main_window], msg, details, 
              "Command Error"
          $stderr.puts "#{ex.message}\n#{ex.backtrace.join("\n")}"
          false
        end
      end
      
=begin rdoc
Called whenever the global settings change and when the plugin is first loaded

Sets the font of the editor to the font chosen by the user as the output font
@return [nil]
=end
      def load_settings
        @editor.font = Ruber[:config][:general, :output_font]
        nil
      end
      
    end
    
  end
  
end