require 'spec/common'

require 'fileutils'

require 'ruber/external_program_plugin'
require 'ruber/plugin_specification'
require 'ruber/output_widget'

describe Ruber::ExternalProgramPlugin do

  before do
    ui_file = random_string
    `touch #{ui_file}`
    @pdf = Ruber::PluginSpecification.full({:name => 'test', :ui_file => ui_file})
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(KDE::Application.instance)
    @components = flexmock{|m| m.should_ignore_missing}
    @mw = KParts::MainWindow.new nil, 0
    @mw.send(:create_shell_GUI)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw)
  end
  
  after do
    FileUtils.rm @pdf.ui_file
  end

  it 'inherits from Ruber::GuiPlugin' do
    Ruber::ExternalProgramPlugin.ancestors.should include(Ruber::GuiPlugin)
  end
  
  describe ', when created' do
    
    it 'takes one or two arguments' do
      lambda{Ruber::ExternalProgramPlugin.new @pdf, true}.should_not raise_error
      lambda{Ruber::ExternalProgramPlugin.new @pdf}.should_not raise_error
    end
    
    it 'creates a new process' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      plug.process.should be_a(KDE::Process)
    end
    
    it 'sets the value of the @line_buffered instance variable to the second argument' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      plug.instance_variable_get(:@line_buffered).should be_true
      plug = Ruber::ExternalProgramPlugin.new @pdf, false
      plug.instance_variable_get(:@line_buffered).should be_false
    end
    
    it 'sets the @buffer instance variable to nil' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      plug.instance_variables.should include(:@buffer)
      plug.instance_variable_get(:@buffer).should be_nil
    end
    
    it 'sets the @buffer_content_channel instance variable to nil' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      plug.instance_variables.should include(:@buffer_content_channel)
      plug.instance_variable_get(:@buffer_content_channel).should be_nil
    end
    
    it 'sets the @output_widget instance variable to nil, if it doesn\'t exist' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      plug.instance_variables.should include(:@output_widget)
      plug.instance_variable_get(:@output_widget).should be_nil
    end
    
    it 'doesn\'t set the @output_widget instance variable to nil if it already exists' do
      plug = Ruber::ExternalProgramPlugin.new(@pdf){@output_widget = 'test'}
      plug.instance_variables.should include(:@output_widget)
      plug.instance_variable_get(:@output_widget).should == 'test'
    end
    
    it 'sets the process\'s process channel mode to Qt::Process::SeparateChannels' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      plug.process.process_channel_mode.should == Qt::Process::SeparateChannels
    end
    
    it 'connects the process\'s readyReadStandardOutput() signal to a block which reads the contents of standard output, converts them to a string and calls do_stdout' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      data = Qt::ByteArray.new('xyz')
      flexmock(data).should_receive(:to_s).once.and_return 'xyz'
      flexmock(plug.process).should_receive(:read_all_standard_output).once.and_return(data)
      flexmock(plug).should_receive(:do_stdout).once.with('xyz')
      plug.process.instance_eval{emit readyReadStandardOutput}
    end
    
    it 'connects the process\'s readyReadStandardError() signal to a block which reads the contents of standard error, converts them to a string and calls do_stderr' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      data = Qt::ByteArray.new('xyz')
      flexmock(data).should_receive(:to_s).once.and_return 'xyz'
      flexmock(plug.process).should_receive(:read_all_standard_error).once.and_return(data)
      flexmock(plug).should_receive(:do_stderr).once.with('xyz')
      plug.process.instance_eval{emit readyReadStandardError}
    end    
    
    it 'connects the process\'s finished(int, QProcess::ExitStatus) signal with its slot_process_finished(int, QProcess::ExitStatus) slot' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      flexmock(plug).should_receive(:slot_process_finished).once.with(1, Qt::Process::CrashExit)
      plug.process.instance_eval{emit finished(1, Qt::Process::CrashExit)}
    end
    
    it 'connects the process\'s started() signal with its process_started() signal' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      m = flexmock{|mk| mk.should_receive(:started).once}
      plug.connect(SIGNAL('process_started()')){m.started}
      plug.process.instance_eval{emit started}
    end
    
    it 'connects the process\'s error(QProcess::ProcessError) signal to a block which calls failed_to_start if the argument is Qt::Process::FailedToStart' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      flexmock(plug).should_receive(:failed_to_start).once
      plug.process.instance_eval{emit error Qt::Process::FailedToStart}
      plug.process.instance_eval{emit error Qt::Process::Crashed}
    end
    
    it 'connects its process_finished(int, QString) signal to its display_exit_message(int, QString) slot' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      flexmock(plug).should_receive(:display_exit_message).once.with(5, 'crash')
      plug.instance_eval{emit process_finished(5, 'crash')}
    end
    
  end
  
  describe '#shutdown' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    it 'blocks the process\'s signals' do
      flexmock(@plug.process).should_receive(:block_signals).once.with(true)
      @plug.send :shutdown
    end
    
    it 'kills the process' do
      flexmock(@plug.process).should_receive(:kill).once
      @plug.send :shutdown
    end
    
  end
  
  describe '#do_stdout' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    describe 'if the plugin is not line buffered' do
      
      before do
        @plug.instance_variable_set(:@line_buffered, false)
      end
      
      it 'calls the process_standard_output passing it the argument split into lines' do
        flexmock(@plug).should_receive(:process_standard_output).twice.with %w[a b c]
        @plug.send :do_stdout, "a\nb\nc\n"
        @plug.send :do_stdout, "a\nb\nc"
      end
      
      it 'does nothing if the string is empty or made only of newlines' do
        flexmock(@plug).should_receive(:process_standard_output).never
        @plug.send :do_stdout, ""
        @plug.send :do_stdout, "\n"
      end
      
    end
    
    describe ', if the plugin is line buffered' do
      
      describe ' and the buffer is empty' do
        
        it 'calls the process_standard_output method passing it the string divided into lines, if the string ends in a newline' do
          flexmock(@plug).should_receive(:process_standard_output).once.with %w[a b c]
          @plug.send :do_stdout, "a\nb\nc\n"
        end
        
        it 'calls the process_standard_output method passing it the string divided into lines except for the last one if the string doesn\'t end in a newline' do
          flexmock(@plug).should_receive(:process_standard_output).once.with %w[a b]
          @plug.send :do_stdout, "a\nb\nc"
        end
        
        it 'puts the last line in the buffer and sets the buffer_content_channel to :stdout if the string doesn\'t end in a newline' do
          @plug.send :do_stdout, "a\nb\nc"
          @plug.instance_variable_get(:@buffer).should == 'c'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stdout
        end
        
        it 'puts the only line in the buffer, sets the buffer_content_channel to :stdout and does nothing else if there\'s only one string and it doesn\'t end in a newline' do
          flexmock(@plug).should_receive(:process_standard_output).never
          lambda{@plug.send :do_stdout, ''}.should_not raise_error
          @plug.send :do_stdout, "a"
          @plug.instance_variable_get(:@buffer).should == 'a'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stdout
        end
        
        it 'does nothing if the string is empty or made only of newlines' do
          flexmock(@plug).should_receive(:process_standard_output).never
          lambda{@plug.send :do_stdout, ''}.should_not raise_error
          lambda{@plug.send :do_stdout, "\n"}.should_not raise_error
        end

      end
      
      describe ', the buffer is not empty and its channel is stdout' do
        
        before do
          @plug.instance_variable_set(:@buffer, 'x')
          @plug.instance_variable_set(:@buffer_content_channel, :stdout)
          class << @plug
            alias :do_stdout_needed_for_test :do_stdout
          end
        end
        
        it 'adds the buffer to the beginning of the string, clears the buffer and calls itself with the new string' do
          flexmock(@plug).should_receive(:do_stdout).once.with("xa\nb\nc\n")
          @plug.send :do_stdout_needed_for_test, "a\nb\nc\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
        it 'does nothing if the string is empty' do
          flexmock(@plug).should_receive(:process_standard_output).never
          lambda{@plug.send :do_stdout, ''}.should_not raise_error
          @plug.instance_variable_get(:@buffer).should == 'x'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stdout
        end
        
        it 'adds the buffer to the beginning of the string, clears the buffer and calls itself with the new string even if the string only contains newlines' do
          flexmock(@plug).should_receive(:do_stdout).once.with("x\n\n")
          @plug.send :do_stdout_needed_for_test, "\n\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
        it 'doesn\'t call process_standard_output a second time' do
          flexmock(@plug).should_receive(:process_standard_output).once
          @plug.send :do_stdout, "a\nb\nc\n"
        end
        
      end
      
      describe ', the buffer is not empty and its channel is stderr' do
        
        before do
          @plug.instance_variable_set(:@buffer, 'x')
          @plug.instance_variable_set(:@buffer_content_channel, :stderr)
        end
        
        it 'clears the buffer and calls process_standard_error passing the an array containing the buffer as argument before going on' do
          flexmock(@plug).should_receive(:process_standard_error).once.with(["x"]).ordered
          flexmock(@plug).should_receive(:process_standard_output).once.with(%w[a b c]).ordered
          @plug.send :do_stdout, "a\nb\nc\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
        it 'does nothing if the string is empty' do
          flexmock(@plug).should_receive(:process_standard_output).never
          flexmock(@plug).should_receive(:do_stderr).never
          lambda{@plug.send :do_stdout, ''}.should_not raise_error
          @plug.instance_variable_get(:@buffer).should == 'x'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stderr
        end
        
        it 'clears the buffer, calls do_stderr passing the buffer and does nothing else if the string only contains newlines' do
          flexmock(@plug).should_receive(:process_standard_error).once.with(["x"]).ordered
          flexmock(@plug).should_receive(:process_standard_output).never
          @plug.send :do_stdout, "\n\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
      end
      
    end
    
  end
  
  describe '#do_stderr' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    describe 'if the plugin is not line buffered' do
      
      before do
        @plug.instance_variable_set(:@line_buffered, false)
      end
      
      it 'calls the process_standard_error passing it the argument split into lines' do
        flexmock(@plug).should_receive(:process_standard_error).twice.with %w[a b c]
        @plug.send :do_stderr, "a\nb\nc\n"
        @plug.send :do_stderr, "a\nb\nc"
      end
      
      it 'does nothing if the string is empty or made only of newlines' do
        flexmock(@plug).should_receive(:process_standard_error).never
        @plug.send :do_stderr, ""
        @plug.send :do_stderr, "\n"
      end
      
    end
    
    describe ', if the plugin is line buffered' do
      
      describe ' and the buffer is empty' do
        
        it 'calls the process_standard_error method passing it the string divided into lines, if the string ends in a newline' do
          flexmock(@plug).should_receive(:process_standard_error).once.with %w[a b c]
          @plug.send :do_stderr, "a\nb\nc\n"
        end
        
        it 'calls the process_standard_error method passing it the string divided into lines except for the last one if the string doesn\'t end in a newline' do
          flexmock(@plug).should_receive(:process_standard_error).once.with %w[a b]
          @plug.send :do_stderr, "a\nb\nc"
        end
        
        it 'puts the last line in the buffer and sets the buffer_content_channel to :stderr if the string doesn\'t end in a newline' do
          @plug.send :do_stderr, "a\nb\nc"
          @plug.instance_variable_get(:@buffer).should == 'c'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stderr
        end
        
        it 'puts the only line in the buffer, sets the buffer_content_channel to :stderr and does nothing else if there\'s only one string and it doesn\'t end in a newline' do
          flexmock(@plug).should_receive(:process_standard_error).never
          lambda{@plug.send :do_stderr, ''}.should_not raise_error
          @plug.send :do_stderr, "a"
          @plug.instance_variable_get(:@buffer).should == 'a'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stderr
        end
        
        it 'does nothing if the string is empty or made only of newlines' do
          flexmock(@plug).should_receive(:process_standard_error).never
          lambda{@plug.send :do_stderr, ''}.should_not raise_error
          lambda{@plug.send :do_stderr, "\n"}.should_not raise_error
        end
        
      end
      
      describe ', the buffer is not empty and its channel is stderr' do
        
        before do
          @plug.instance_variable_set(:@buffer, 'x')
          @plug.instance_variable_set(:@buffer_content_channel, :stderr)
          class << @plug
            alias :do_stderr_needed_for_test :do_stderr
          end
        end
        
        it 'adds the buffer to the beginning of the string, clears the buffer and calls itself with the new string' do
          flexmock(@plug).should_receive(:do_stderr).once.with("xa\nb\nc\n")
          @plug.send :do_stderr_needed_for_test, "a\nb\nc\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
        it 'does nothing if the string is empty' do
          flexmock(@plug).should_receive(:process_standard_error).never
          lambda{@plug.send :do_stderr, ''}.should_not raise_error
          @plug.instance_variable_get(:@buffer).should == 'x'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stderr
        end
        
        it 'adds the buffer to the beginning of the string, clears the buffer and calls itself with the new string even if the string only contains newlines' do
          flexmock(@plug).should_receive(:do_stderr).once.with("x\n\n")
          @plug.send :do_stderr_needed_for_test, "\n\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
        it 'doesn\'t call process_standard_error a second time' do
          flexmock(@plug).should_receive(:process_standard_error).once
          @plug.send :do_stderr, "a\nb\nc\n"
        end

        
      end
      
      describe ', the buffer is not empty and its channel is stdout' do
        
        before do
          @plug.instance_variable_set(:@buffer, 'x')
          @plug.instance_variable_set(:@buffer_content_channel, :stdout)
        end
        
        it 'clears the buffer and calls process_standard_output passing an array containing the buffer as argument before going on' do
          flexmock(@plug).should_receive(:process_standard_output).once.with(["x"]).ordered
          flexmock(@plug).should_receive(:process_standard_error).once.with(%w[a b c]).ordered
          @plug.send :do_stderr, "a\nb\nc\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
        it 'does nothing if the string is empty' do
          flexmock(@plug).should_receive(:process_standard_error).never
          flexmock(@plug).should_receive(:do_stdout).never
          lambda{@plug.send :do_stderr, ''}.should_not raise_error
          @plug.instance_variable_get(:@buffer).should == 'x'
          @plug.instance_variable_get(:@buffer_content_channel).should == :stdout
        end
        
        it 'clears the buffer, calls process_standard_output passing an array containing the buffer and does nothing else if the string only contains newlines' do
          flexmock(@plug).should_receive(:process_standard_output).once.with(["x"]).ordered
          flexmock(@plug).should_receive(:process_standard_error).never
          @plug.send :do_stderr, "\n\n"
          @plug.instance_variable_get(:@buffer).should be_nil
          @plug.instance_variable_get(:@buffer_content_channel).should be_nil
        end
        
      end
      
    end
    
  end
  
  describe '#process_standard_output' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    it 'does nothing if the @output_widget instance variable is nil' do
      lambda{@plug.send :process_standard_output, %w[a b]}.should_not raise_error
    end
    
    it 'inserts the entries of the array in the model associated to the @output_widget instance variable and set their output type to output if the @output_widget instance variable is not nil' do
      ow = Ruber::OutputWidget.new
      ow.set_color_for(:output, Qt::Color.new(0,0,0))
      mod = ow.model
      3.times{|i| mod.append_row Qt::StandardItem.new(i.to_s)}
      @plug.instance_variable_set :@output_widget, ow
      @plug.send :process_standard_output, %w[a b]
      mod.row_count.should == 5
      mod.column_count.should == 1
      mod.item(3,0).text.should == 'a'
      mod.item(3,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'output'
      mod.item(4,0).text.should == 'b'
      mod.item(4,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'output'
    end
    
  end
  
  describe '#process_standard_error' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    it 'does nothing if the @error_widget instance variable is nil' do
      lambda{@plug.send :process_standard_error, %w[a b]}.should_not raise_error
    end
    
    it 'inserts the entries of the array in the model associated to the @error_widget instance variable and set their error type to error if the @error_widget instance variable is not nil' do
      ow = Ruber::OutputWidget.new
      ow.set_color_for(:error, Qt::Color.new(0,0,0))
      mod = ow.model
      3.times{|i| mod.append_row Qt::StandardItem.new(i.to_s)}
      @plug.instance_variable_set :@output_widget, ow
      @plug.send :process_standard_error, %w[a b]
      mod.row_count.should == 5
      mod.column_count.should == 1
      mod.item(3,0).text.should == 'a'
      mod.item(3,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'error'
      mod.item(4,0).text.should == 'b'
      mod.item(4,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'error'
    end
    
  end
  
  describe '#slot_process_finished' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    it 'reads from standard output and standard error and calls the do_stdout and do_stderr methods (appending a newline if necessary)' do
      flexmock(@plug.process).should_receive(:read_all_standard_output).once.and_return(Qt::ByteArray.new('xyz'))
      flexmock(@plug.process).should_receive(:read_all_standard_output).once.and_return(Qt::ByteArray.new("xyz\n"))
      flexmock(@plug.process).should_receive(:read_all_standard_error).once.and_return(Qt::ByteArray.new('abc'))
      flexmock(@plug.process).should_receive(:read_all_standard_error).once.and_return(Qt::ByteArray.new("abc\n"))
      flexmock(@plug).should_receive(:do_stdout).twice.with("xyz\n")
      flexmock(@plug).should_receive(:do_stderr).twice.with("abc\n")
      @plug.send :slot_process_finished, 1, Qt::Process::NormalExit
      @plug.send :slot_process_finished, 1, Qt::Process::NormalExit
    end
    
    it 'emits the process_finished(int, QString) with "killed" as second argument if status is Qt::Process::CrashExit and code is 0' do
      m = flexmock{|mk| mk.should_receive(:test).once.with(0, 'killed')}
      @plug.connect(SIGNAL('process_finished(int, QString)')){|i, s| m.test i, s}
      @plug.process.instance_eval{emit finished(0, Qt::Process::CrashExit)}
    end
    
    it 'emits the process_finished(int, QString) with "crash" as second argument if status is Qt::Process::CrashExit and code is not 0' do
      m = flexmock{|mk| mk.should_receive(:test).once.with(5, 'crash')}
      @plug.connect(SIGNAL('process_finished(int, QString)')){|i, s| m.test i, s}
      @plug.process.instance_eval{emit finished(5, Qt::Process::CrashExit)}
    end
    
    it 'emits the process_finished(int, QString) with "" as second argument if status is Qt::Process::NormalExit' do
      m = flexmock{|mk| mk.should_receive(:test).once.with(0, '')}
      @plug.connect(SIGNAL('process_finished(int, QString)')){|i, s| m.test i, s}
      @plug.process.instance_eval{emit finished(0, Qt::Process::NormalExit)}
    end
    
  end
  
  describe '#failed_to_start' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    it 'emits the process_failed_to_start signal' do
      m = flexmock{|mk| mk.should_receive(:test).once}
      @plug.connect(SIGNAL(:process_failed_to_start)){m.test}
      @plug.send :failed_to_start
    end
    
    it 'displays a message of type error1 in the output widget @output_widget, if @output_widget is not nil' do
      ow = Ruber::OutputWidget.new
      ow.set_color_for :error1, Qt::Color.new(255,0,0)
      mod = ow.model
      3.times{|i| mod.append_row Qt::StandardItem.new(i.to_s)}
      @plug.instance_variable_set :@output_widget, ow
      @plug.process.set_program '/usr/bin/xyz', %w[-a --bc d]
      @plug.send :failed_to_start
      mod.row_count.should == 4
      mod.item(3,0).text.should == "/usr/bin/xyz failed to start. The command line was /usr/bin/xyz -a --bc d"
      mod.item(3,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'error1'
    end
    
    it 'doesn\'t attempt to display the error message if @output_widget is nil' do
      lambda{@plug.send :failed_to_start}.should_not raise_error
    end
    
  end
  
  describe '#run_process' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
      flexmock(@plug.process).should_receive(:start).by_default
    end
    
    it 'sets the working directory of the proces' do
      @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c]
      @plug.process.working_directory.should == ENV['HOME']
    end
    
    it 'clears the program and argument list' do
      flexmock(@plug).process.should_receive(:clear_program).once
      @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c]
    end
    
    it 'sets the program and argument list' do
      @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c]
      @plug.process.program.should == %w[/usr/bin/xyz a b c]
    end
    
    it 'starts the program, after having set all the parameters' do
      flexmock(@plug.process).should_receive(:clear_program).once.ordered
      flexmock(@plug.process).should_receive(:working_directory=).once.ordered
      flexmock(@plug.process).should_receive(:program=).once.ordered
      flexmock(@plug.process).should_receive(:start).once.ordered
      @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c]
    end
    
    describe 'if the @output_widget instance variable is not nil' do
      
      before do
        @ow = Ruber::OutputWidget.new
        @plug.instance_variable_set :@output_widget, @ow
      end
      
      it 'sets the title of the output widget to the command line before starting the program if the fourth parameter is an empty string' do
        flexmock(@ow).should_receive(:title=).with('/usr/bin/xyz a b c').once.ordered
        flexmock(@plug.process).should_receive(:start).once.ordered
        @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c], ''
      end
      
      it 'uses the fourth argument as title for the output widget if it\'s a non-empty string' do
        flexmock(@ow).should_receive(:title=).with('TITLE').once.ordered
        flexmock(@plug.process).should_receive(:start).once.ordered
        @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c], 'TITLE'
      end
      
      it 'doesn\'t attempt to set the output widget title if the fourth argument is nil or false' do
        flexmock(@ow).should_receive(:title=).never
        flexmock(@plug.process).should_receive(:start).twice
        @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c], false
        @plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c], nil
      end
      
    end
    
    it 'doesn\'t attempt to set the output widget title if the @output_widget instance variable is nil' do
      lambda{@plug.run_process '/usr/bin/xyz', ENV['HOME'], %w[a b c], ''}.should_not raise_error
    end

  end
  
  describe '#stop process' do
    
    it 'kills the process' do
      plug = Ruber::ExternalProgramPlugin.new @pdf
      flexmock(plug.process).should_receive(:kill).once
      plug.stop_process
    end
    
  end
  
  describe '#display_exit_ message' do
    
    before do
      @plug = Ruber::ExternalProgramPlugin.new @pdf
    end
    
    describe ', if the @output_widget instance variable is not nil' do
      
      before do
        @ow = Ruber::OutputWidget.new
        @ow.set_color_for :message, Qt::Color.new(255,0,0)
        @ow.set_color_for :message_bad, Qt::Color.new(255,0,0)
        @plug.instance_variable_set :@output_widget, @ow
        @mod = @ow.model
        5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      end
      
      it 'appends a line with output type message and text "Process exited normally" if the second argument is empty and code is 0' do
        @plug.process.program = %w[/usr/bin/xyz -a --bc d]
        @plug.send :display_exit_message, 0, ''
        @mod.row_count.should == 6
        @mod.item(5,0).text.should == 'Process exited normally'
        @mod.item(5,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      end
      
      it 'appends a line with output type message_bad and text "Process exited with code code" if the second argument is empty and code is not' do
        @plug.process.program = %w[/usr/bin/xyz -a --bc d]
        @plug.send :display_exit_message, 5, ''
        @mod.row_count.should == 6
        @mod.item(5,0).text.should == 'Process exited with code 5'
        @mod.item(5,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message_bad'
      end

      it 'appends a line with output type message and text "Process killed" if the second argument is "killed"' do
        @plug.process.program = %w[/usr/bin/xyz -a --bc d]
        @plug.send :display_exit_message, 0, 'killed'
        @mod.row_count.should == 6
        @mod.item(5,0).text.should == 'Process killed'
        @mod.item(5,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      end

      it 'appends a line with output type message_bad and text "Process crashed with code code" if the second argument is "crash"' do
        @plug.process.program = %w[/usr/bin/xyz -a --bc d]
        @plug.send :display_exit_message, 5, 'crash'
        @mod.row_count.should == 6
        @mod.item(5,0).text.should == 'Process crashed with code 5'
        @mod.item(5,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message_bad'
      end
      
    end
   
    describe ', if the @output_widget instance variable is nil' do
      
      it 'does nothing' do
        lambda{@plug.send :display_exit_message, 0, ''}.should_not raise_error
      end
      
    end
    
  end
  
end