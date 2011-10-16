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
  
    # Incapsulates the information about the special prompt used by the plugin
    class PromptMatcher
      
      # Mapping between prompt types and characters used to represent them in the prompt
      TYPES = {'n' => :normal, 's' => :string, 'c' => :statement, 'i' => :indent, 'r' => :return }
      
      # Mapping between prompt names used by IRB and characters used to represent them in the prompt
      PROMPTS = {:PROMPT_I => 'n', :PROMPT_N => 'i', :PROMPT_S => 's', :PROMPT_C => 'c', :RETURN => 'r'}

      # @return [{Symbol=>String}] the prompt to be used in IRB
      attr_reader :prompts
      
# @param [String] id the identifier used to mark the beginning and end of a prompt
# @param [{Symbol=>String}] prompts the prompts to use. The recognized keys are:
#  @:PROMPT_I@, @:PROMPT_N@, @:PROMPT_S@, @:PROMPT_C@, @:RETURN@. They have the
#  same meaninig as the keys of any entry in @IRB.conf[:PROMPT]@
      def initialize id, prompts
        @id = id
        @prompts = {}
        prompts.each_pair do |k, v|
          @prompts[k] = "quirb:#{@id}:#{v}:quirb:#{@id}:#{PROMPTS[k]}:"
        end
      end
      
# Checks whether a string begins with a prompt
# 
# @param [String] str the string to check
# @return [IrbLine, nil] an {IrbLine} with the information about the prompt and the
#  string if the string starts with a prompt or *nil* if the string doesn't start
#  with a prompt
      def match str
        res = str.split "quirb:#{@id}:", 3
        return if !res or !res[0].empty? or res.size < 3
        res[1].slice! -1 #removes an ending :
        letter, sep, line = res[2].partition ':'
        type = TYPES[letter]
        if type then IrbLine.new type, line, res[1]
        else nil
        end
      end
      
    end
    
# A parsed line from IRB
# 
# It contains information about the prompt for the line, the text of the line and the
# type and category of prompt
    class IrbLine
      
# @return [Symbol] the type of line. It can be:
#  * @:output@ if there's no prompt
#  * @:return@ if the line starts with a @:RETURN@ prompt
#  * @:normal@ if the line starts with a @:PROMPT_I@ prompt
#  * @:string@ if the line starts with a @:PROMPT_S@ prompt
#  * @:statement@ if the line starts with a @:PROMPT_C@ prompt
#  * @:indent@ if the line starts with a @:PROMPT_N@ prompt
      attr_reader :type
      
# @return [String] the content of the line
      attr_reader :text

# @return [Symbol] the category of the line (basing on the prompt {#type}). It is
#  @:output@ if the prompt type is @:output@ or @:return@ and @:input@ otherwise
      attr_reader :category
      
# @return [String] the text of the prompt
      attr_reader :prompt

# @return [String] the full text of the line, made from the IRB prompt and the line
#  contents
      attr_reader :full_text
      
# The category corresponding to each line type
      CATEGORIES = {
        :output => :output, 
        :return => :output,
        :normal => :input,
        :string => :input,
        :statement => :input,
        :indent => :input
      }
      
# @param [Symbol] type the type of the line. It can be: @:output@, @:return@, @:normal@,
#  @:string@, @:statement@ or @:indent@
# @param [String] text the text of the line
# @param [String] the text of the prompt
      def initialize type, text, prompt
        @text = text
        @type = type
        @prompt = prompt
        @full_text = @prompt + @text
        @category = (type == :return or type == :output) ? :output : :input
      end
      
    end
    
    class IRBController < Qt::Object
      
      # Signal emitted when there's output from irb to be read
      # 
      # This signal can be emitted either as soon as IRB writes the output or at regular
      # intervals (provided there's actually output availlable) according to the
      # value of {#interval}
      signals :output_ready
      
      # Signal emitted just before IRB is stopped, for whatever reason. Connecting
      # to this signal is the last opportunity to read the output from it.
      signals :about_to_stop_irb
      
      # Signal emitted just before interrupting IRB by sending a @SIGINT@ signal
      signals :interrupting_evaluation
      
      # Signal emitted after IRB has been interrupted by sending a @SIGINT@ signal
      signals :evaluation_interrupted
      
      # Signal emitted when IRB is ready to receive input (that is, when it gives
      # a prompt when there aren't lines yet to be sent)
      signals :ready
            
      # @return [<String>] the options to pass to IRB. Note that changing this
      #  after IRB has been started won't have any effect until you restart IRB.
      attr_accessor :irb_options
      
      # @return [String] the path if the IRB program. Note that changing this
      #  after IRB has been started won't have any effect until you restart IRB.
      attr_accessor :irb_program
      
      # @return [Integer,nil] the minimum time interval (in milliseconds) between
      #  two {#output_ready} methods. If *nil*, the {#output_ready} signal will
      #  be emitted as soon as output is received from IRB. The default value is
      #  100 milliseconds
      attr_accessor :interval
      
      # @param [String] irb the path of the IRB program
      # @param [<String>] options the options to pass to the IRB program
      # @param [Qt::Object,nil] parent the parent object
      def initialize irb, options, parent = nil
        super parent
        @irb_program = irb
        @irb_options = options.dup
        @timer = Qt::Timer.new self
        connect @timer, SIGNAL(:timeout), self, SLOT(:timer_ticked)
        @pending_prompt = nil
        @interrupting = false
        @evaluating = false
        @input = []
        @output = []
        @interval = 100
      end
      
      # Whether or not there's output ready to be read
      # @return [Boolean] *true* if there's output to be read using {#output} and
      #  *false* otherwise
      def has_output?
        !@output.empty?
      end
      
      # Interrupts IRB evaluation by sending IRB the @SIGINT@ signal
      # 
      # This will also clear any pending input. The {#output_ready} signal won't
      # be emitted until IRB sends an empty prompt. The {#interrupting_evaluation}
      # signal is emitted before sending IRB the @SIGINT@ signal
      # @return nil
      def interrupt
        @interrupting = true
        @timer.stop
        @input.clear
        emit interrupting_evaluation
        Process.kill :INT, @irb.pid
        nil
      end
      
      # Sends input to IRB
      # 
      # The input lines are sent one by one, expecting a prompt before sending a
      # new one. The {#ready} signal is emitted at the first prompt after the last
      # line has been sent. If there are lines waiting to be sent, the new ones
      # will be added at the end of the queue.
      # @param [<String>] input the lines to send IRB
      # @return [nil]
      def send_to_irb input
        @input.concat input
        unless @evaluating
          @evaluating = true
          send_next_line
        end
        nil
      end
      slots :send_to_irb
      
      # Stops the IRB process
      # 
      # The {#about_to_stop_irb} is emitted before stopping IRB. No further
      # {#output_ready} signals are emitted.
      # 
      # You'll need to call {#start_irb} if you want IRB to be restarted after
      # calling this method. If all you need is to stop IRB and immediately restart
      # it, however, use {#restart_irb} rather than {#stop}
      # 
      # @return [nil]
      # @note this method will wait for up to two seconds for IRB to stop. If it
      # doesn't stop by that time, it will return all the same.
      def stop_irb
        disconnect @irb, SIGNAL('finished(int, QProcess::ExitStatus)'), self, SLOT(:irb_finished)
        stop :kill
        # It seems it takes some time before irb is killed.
        @irb.wait_for_finished 2000
      end
      
      # Stops and immediately restarts the IRB process
      # The {#about_to_stop_irb} is emitted before stopping IRB. After emitting
      # this signal, all output will be cleared, so you won't be able to access it
      # anymore.
      # 
      # @return [nil]
      def restart_irb
        stop :terminate
        nil
      end
      slots :restart_irb
      
      # Sends IRB a signal
      # 
      # @param [String,Symbol,Integer] signal the name or number of the signal.
      #  Signal names may be with or without the @SIG@ prefix
      # @raise [ArgumentError] if the signal name or number is not valid
      # @raise [RuntimeError] if it wasn't possible to send the signal
      # @return [nil]
      # @note if you want to stop evaluation (for example, to exit and endless loop),
      #  do not use this method to send a @SIGINT@, but use {#interrupt}. Simply
      #  sending a @SIGINT@ signal may not work very well in that case, as, if IRB
      #  keeps sending output, {#output_ready} signals will kept being emitted
      def send_signal signal
        pid = @irb.pid
        begin Process.kill signal, pid
        rescue Errno::EINVAL, RangeError, ArgumentError
          raise ArgumentError, "Invalid signal #{signal}"
        rescue Errno::ESRCH, Errno::EPERM
          raise RuntimeError, "It wasn't possible to send IRB a signal"
        end
        nil
      end
      
      # Changes the prompt
      # 
      # Calling this method is the same as adding a new entry to @IRB.conf[:PROMPT]@
      # and changing the current prompt using @IRB.conf.prompt_mode=@.
      # 
      # @param [{Symbol=>String}] the new prompt. The recognized keys are:
      #  @:PROMPT_I@, @:PROMPT_N@, @:PROMPT_S@, @:PROMPT_C@, @:RETURN@. They have the
      #  same meaninig as the keys of any entry in @IRB.conf[:PROMPT]@
      # @return [nil]
      # @note in the return prompt, don't add the ending @%s\n@, as it will be
      #  added automatically
      # @note users must not use @IRB.conf[:PROMPT]@ or @IRB.conf.prompt_mode=@
      #  to change IRB's prompt, but always call this method. This is
      #  because {IRBController}, behind the scenes, needs to add a special string to the
      #  prompt chosen by the user to work correctly
      # @note changing the prompt takes effect immediately, even if IRB has already
      #  been started
      def prompts= prompts
        id = Array.new(5){rand(10)}.join ''
        @prompt = PromptMatcher.new id, prompts
      end

      # Starts IRB
      # 
      # If IRB is already running, it'll be stopped. The {#ready} signal will be
      # emitted when IRB is ready to accept output.
      # 
      # This method will wait for IRB to start for up to two seconds before returning.
      # @return [Boolean] *true* if IRB was started successfully and *false* if
      #  it didn't start within two seconds
      def start_irb
        if @irb
          @irb.kill
          @irb.delete_later 
        end
        @irb = Qt::Process.new self
        @irb.process_channel_mode = Qt::Process::MergedChannels
        set_irb_env
        connect @irb, SIGNAL('finished(int, QProcess::ExitStatus)'), self, SLOT(:irb_finished)
        options = @irb_options + ['--noreadline']
        @irb.start @irb_program, options
        @irb.wait_for_started 2000
        if @irb.state == Qt::Process::Running
          change_irb_prompt
          true
        else false
        end
      end
      
      # @return [Boolean] whether IRB is running or not
      def running?
        @irb.state == Qt::Process::Running
      end
      
      # The state of the IRB process
      # 
      # @return [Symbol] @:running@ if the IRB process is running, @:starting@ if
      #  an attempt to start the IRB process was made but IRB hasn't started yet
      #  and @:not_running@ if either IRB has not yet been started or if the attempt
      #  to start it has failed
      def state
        @irb.state
      end
            
      # Reads a number of lines of output
      # 
      # Lines which have been read are removed from the output buffer
      # @param [Integer,nil] n the number of lines to read
      # @return [<IrbLine>] an array containing the first _n_ lines of output. If
      #  there are less than _n_ lines of output, all of them are returned. If
      #  there's no output, an empty array is returned. If _n_ is *nil*, the whole
      #  content of the output buffer is returned
      def output n = 100
        if n then n = [n, @output.size].min
        else n = @output.count
        end
        @output.shift n
      end
      
      private
      
      # Sends IRB the command to change the prompt
      # 
      # IRB should not be given input until this command has been executed
      # @return [nil]
      def change_irb_prompt
        prompts = @prompt.prompts.dup
        prompts[:RETURN] += "%s\n"
        connect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:wait_for_prompt_changed)
        cmd = "IRB.conf[:PROMPT][:QUIRB]=#{prompts.inspect}\nconf.prompt_mode = :QUIRB\n"
        @irb.write cmd
        nil
      end
      
      # Helper method to stop IRB
      # 
      # It's used by both {#stop_irb} and {#restart_irb}. It takes care of reading
      # any unread output from IRB, emitting the {#about_to_stop_irb} signal, 
      # stopping the timer and so on.
      # @param [Symbol] meth the method to call to stop IRB. It can be either 
      #  :kill or :terminate, which will call respectively @Qt::Process#kill@ or
      #  @Qt::Process#terminate@
      # @return [nil]
      def stop meth
        parse_output @irb.read_all_standard_output.to_s.split("\n")
        emit about_to_stop_irb
        @timer.stop
        @irb.disconnect SIGNAL(:readyReadStandardOutput)
        @irb.send meth
        nil
      end
      
      # Changes the environment associated with the IRB process
      # 
      # The environment is changed by adding an @IRBRC@ variable which points to
      # the @irbrc.rb@ file in the same directory as @irb_controller.rb@.
      # @return [nil]
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
        nil
      end
      
      # Slot called whenever IRB sends output before changes to the prompt have
      # taken effect
      # 
      # If the lines sent by IRB contain the correct prompt, the @readyReadStandardOutput@
      # signal from the IRB process will be connected to the {#process_output}
      # signal and the {#ready} signal will be emitted
      def wait_for_prompt_changed
        lines = @irb.read_all_standard_output.to_s.split "\n"
        found = false
        lines.each do |l|
          if @prompt.match l
            disconnect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:wait_for_prompt_changed)
            connect @irb, SIGNAL(:readyReadStandardOutput), self, SLOT(:process_output)
            found = true
            break
          end
        end
        if found
          empty_prompt = lines.reverse_each.find do |l|
            res = @prompt.match l
            res and res.category == :input and res.text.empty?
          end
          @pending_prompt = @prompt.match empty_prompt
          emit ready
        end
      end
      slots :wait_for_prompt_changed

      # Restarts IRB after it has been terminated
      # 
      # This method is connected to the IRB process's @finished(int, QProcess::ExitStatus)@
      # signal, so that a new IRB process can be automatically started. This doesn't
      # happen when {#stop_irb} is used to kill the IRB process
      # @return [nil]
      def irb_finished
        @irb.delete_later
        start_irb
        nil
      end
      slots :irb_finished
      
      # Sends the next line of input to the IRB process
      # 
      # If there's no queued input line, the {#ready} signal will be emitted
      # @return [nil]
      def send_next_line
        if @input.empty? 
          @evaluating = false
          emit ready
        else @irb.write @input.shift + "\n"
        end
      end
      
      # Slot called whenever IRB sends output after the prompt has correctly
      # been set up
      # 
      # It adds the output lines to the output buffer, after converting them to
      # {IrbLine} objects. If the last line is a prompt line and the controller
      # is sending input to IRB, it calls {#send_next_line}.
      # 
      # If the controller is interrupting IRB and a prompt is found, the {#evaluation_interrupted}
      # signal is emitted, followed by the {#ready} signal
      # @return [nil]
      def process_output
        new_lines = @irb.read_all_standard_output.to_s.split "\n"
        lines = parse_output new_lines
        return unless @prompt
        return unless lines
        @output.concat lines
        if lines.last and lines.last.category == :input and lines.last.text.empty?
          is_ready = true
          @pending_prompt = @output.pop
        end
        if @prompt and !@interrupting
          emit output_ready if !@interval or @output.count <= 100
          @timer.start(@interval) if @interval and !@output.empty? and !@timer.active?
          send_next_line if (@evaluating and is_ready) or !@evaluating
        elsif @interrupting
          if is_ready
            @interrupting = false
            emit evaluation_interrupted
            @output.clear
            send_next_line
          end
        end
        nil
      end
      slots :process_output
      
      # Slot called in response to the timer timing out
      # 
      # It emits the {#output_ready} signal and stops the timer if there's no
      # more output
      # @return [nil]
      def timer_ticked
        emit output_ready
        @timer.stop if @output.empty?
        nil
      end
      slots :timer_ticked
      
      # Parses output lines from IRB, converting them to {IrbLine} objects
      # 
      # If the prompt has been set up, the lines will be processed using {PromptMatcher#match},
      # otherwise they'll all be considered output lines with no prompt.
      # 
      # If the controller is sending input to IRB and there's a pending prompt,
      # that prompt will be added to the beginning of the first line, then removed
      # @param [<String>] lines the lines to process
      # @return [<IrbLine>, nil] an array of {IrbLine} objects corresponding to
      #  the processed lines or *nil* if _lines_ is empty
      def parse_output lines
        return if lines.empty?
        if @prompt
          parsed_lines = lines.map do |l| 
            @prompt.match(l) || IrbLine.new( :output, l, '')
          end
        else
          parsed_lines = lines.map{|l| IrbLine.new :output, l, ''}
        end
        if @evaluating and @pending_prompt and parsed_lines[0].type == :output
          parsed_lines[0] = IrbLine.new :normal, lines[0], @pending_prompt.prompt
          @pending_prompt = nil
        end
        parsed_lines
      end
      slots :parse_output

    end
    
  end
  
end