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

module Ruber
  
  module IRB
  
    class PromptMatcher
      
      MODES = {'n' => :normal, 's' => :string, 'c' => :statement, 'i' => :indent, 'r' => :return }
      
      def initialize id, prompts
        @id = id
        names = {:PROMPT_I => :normal, :PROMPT_N => :indent, :PROMPT_S => :string, :PROMPT_c => :statement, :RETURN => :return}
        @prompts = {}
        names.each_pair{|k, v| @prompts[v] = prompts[k]}
      end
      
      def match str
        res = str.split "quirb:#{@id}:", 3
        return if !res or !res[0].empty? or res.size < 3
        res[1].slice! 0 #removes a leading :
        letter, sep, line = res[2].partition ':'
        type = MODES[letter]
        if type == :return
          [type, res[1].chop]
        elsif type then [type, res[1]+line]
        else nil
        end
      end
      
      def add_prompt str, type
        "quirb:#{@id}:#{@prompts[type]}:quirb:#{@id}:#{MODES.invert[type]}:" << str
      end
      
    end
    
    class IrbLine
      
      attr_reader :type, :text, :category
      
      CATEGORIES = {
        :output => :output, 
        :return => :output,
        :normal => :input,
        :string => :input,
        :statement => :input,
        :indent => :input
      }
      
      def initialize type, text
        @text = text
        @type = type
        @category = (type == :return or type == :output) ? :output : :input
      end
      
      def same_category_as? other
        other = other.type unless other.is_a? Symbol
        CATEGORIES[@type] == CATEGORIES[other]
      end
      
    end
    
    class IRBController < Qt::Object
      
      signals :output_received
      
      signals :about_to_stop_irb
      
      signals :interrupting_evaluation
      
      signals :evaluation_interrupted
      
      signals :ready
            
      attr_accessor :irb_options
      
      attr_accessor :irb_program
      
      TIMER_INTERVAL = 100
      def initialize irb, options, parent = nil
        super parent
        @irb_program = irb
        @irb_options = options.dup
        @timer = Qt::Timer.new self
        connect @timer, SIGNAL(:timeout), self, SLOT(:timer_ticked)
        @interrupting = false
        @in_evaluation = false
        @input = []
        @output = []
      end
      
      def interrupt
        @interrupting = true
        @timer.stop
        @input.clear
        emit interrupting_evaluation
        Process.kill :INT, @irb.pid
      end
      
      def send_to_irb input
        @input.concat input
        unless @in_evaluation
          @in_evaluation = true
          send_next_line
        end
      end
      slots :send_to_irb
      
      def restart_irb
        process_output nil
        emit about_to_stop_irb unless @output.empty?
        @timer.stop
        @irb.disconnect SIGNAL(:readyReadStandardOutput)
        @irb.terminate
      end
      slots :restart_irb
      
      def send_signal signal
        pid = @irb.pid
        begin Process.kill signal, pid
        rescue Errno::EINVAL, RangeError, ArgumentError
          Qt::MessageBox.warning nil, 'Quirb', "Invalid signal: #{signal}"
        rescue Errno::ESRCH, Errno::EPERM
          Qt::MessageBox.warning nil, 'Quirb', "Couldn't send signal to irb"
        end
        $signal = true
        @output.clear
      end
      
      def prompts= prompts
        @user_prompts = prompts.dup
        id = Array.new(5){rand(10)}.join ''
        prompt_string = "quirb:#{id}"
        @prompt = PromptMatcher.new id, @user_prompts
        @prompts = {}
        names = {:PROMPT_I => :normal, :PROMPT_N => :indent, :PROMPT_S => :string, :PROMPT_c => :statement, :RETURN => :return}
        names.each_pair do |k, v|
          @prompts[k] = @prompt.add_prompt '', v
        end
        @prompts[:RETURN] << "\n"
      end
      
      def start_irb
        @irb.delete_later if @irb
        @irb = Qt::Process.new self
        @irb.process_channel_mode = Qt::Process::MergedChannels
        set_irb_env
        connect @irb, SIGNAL('finished(int, QProcess::ExitStatus)'), self, SLOT(:irb_finished)
        options = @irb_options + ['--noreadline']
        @irb.start @irb_program, options
        @irb.wait_for_started
        change_irb_prompt if @irb.state == Qt::Process::Running
      end
      
      def change_irb_prompt
        disconnect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:process_output)
        connect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:wait_for_prompt_changed)
        cmd = "IRB.conf[:PROMPT][:QUIRB]=#{@prompts.inspect}\nconf.prompt_mode = :QUIRB\n"
        @irb.write cmd
      end
      
      def output
        n = [100, @output.size].min
        @output.shift n
      end
      
      private
      
      def set_irb_env
        dir = File.dirname(__FILE__)
        vars = ['IRBRC', File.join(dir, 'irbrc.rb')]
        if defined? Qt::ProcessEnvironment
          env = Qt::ProcessEnvironment.system_environment
          env.insert *vars
          @irb.process_environment = env
        else 
          env = @irb.system_environment
          env << vars.join('=')
          @irb.environment = env
        end
      end
      
      def wait_for_prompt_changed
        lines = @irb.read_all_standard_output.to_s.split "\n"
        lines.each do |l|
          if @prompt.match l
            disconnect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:wait_for_prompt_changed)
            connect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:output_ready)
            break
          end
        end
      end
      slots :wait_for_prompt_changed
      
      def irb_finished
        @irb.delete_later
        start_irb
      end
      slots :irb_finished
      
      def send_next_line
        if @input.empty? 
          @in_evaluation = false
          emit ready
        else @irb.write @input.shift + "\n" unless @input.empty?
        end
      end
      
      def output_ready
        new_lines = @irb.read_all_standard_output.to_s.split "\n"
        lines = process_output new_lines, false
        return unless lines
        @output.concat lines
        if @prompt and !@interrupting
          if lines.last and lines.last.category == :input and lines.last.text.empty?
            is_ready = true
            @output.pop
          end
          emit output_received if @output.count <= 100
          @timer.start(TIMER_INTERVAL) if !@output.empty? and !@timer.active?
          send_next_line if (@in_evaluation and is_ready) or !@in_evaluation
        elsif @interrupting
          prompt_line = lines.find{|l| l.category == :input and l.text.empty?}
          if prompt_line
            @interrupting = false
            idx = lines.index prompt_line
            lines = @output.pop lines.size - idx + 1
            emit evaluation_interrupted
            @output = lines
            emit output_received
            send_next_line
          end
        end
      end
      slots :output_ready
      
      def timer_ticked
        emit output_received
        @timer.stop if @output.empty?
      end
      slots :timer_ticked
      
      def process_output lines, remove_empty_prompt = true
        lines = @irb.read_all_standard_output.to_s.split "\n" unless lines
        return if lines.empty?
        if @prompt
          filtered_lines = lines.map do |l| 
            match = @prompt.match(l) || [:output, l]
            IrbLine.new match[0], match[1]
          end
        else
          filtered_lines = lines.map do |l|
            IrbLine.new :output, l
          end
        end
        if @status == :input_sent and filtered_lines[0].type == :output
          line = @prompt.add_prompt lines[0], :normal 
          match = @prompt.match line
          filtered_lines[0] = IrbLine.new match[0], match[1]
        end
        if remove_empty_prompt
          if filtered_lines[-1] and filtered_lines[-1].category == :input and filtered_lines[-1].text.empty?
            filtered_lines.slice! -1
          end
        end
        filtered_lines
      end
      slots :process_output

    end
    
  end
  
end