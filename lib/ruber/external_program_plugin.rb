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

require 'ruber/plugin'

module Ruber

=begin rdoc
Base class for plugins whose main task is to run an external program and maybe
(not necessarily) to display the output in a tool widget.

Basically, this class is a wrapper for <tt>KDE::Process</tt> providing a more
integrated API for the most common functions. In particular, it provides the
following functionality:
* automatic creation of the process
* automatic cleanup at shutdown
* automatic managing of buffered output
* nicer API to read from standard output and standard error
* simplified API to start the process
* automatic display of standard output and standard error in a tool widget (if required)
* display of the command line and of the process status in a tool widget (if required)

To start the process, you simply call the <tt>run_process</tt> method, passing it
the name of the program to run, the working directory and the arguments.

When the process emits the <tt>readyReadStandardOutput()</tt> or the
<tt>readyReadStandardError()</tt>, the contents of the appropriate stream are read
and split into lines. The resulting array are passed to the <tt>process_standard_output</tt>
or <tt>process_standard_error</tt> method. Derived classes can override these methods
to do what they want with the output.

In general, you can't be sure whether the data contained read from standard output
or error contains complete lines. To deal with this issue, when reading from a
stream, only full lines (that is, lines which end in "\n") are passed to
<tt>process_standard_output</tt> or <tt>process_standard_error</tt>. If the last
line isn't complete, it is stored in a buffer. The next time characters are read
from the process, if they came from the same channel, the buffer is added at the
beginning of the new stream; if they came from the other channel, they're passed
to the appropriate <tt>process_standard_*</tt> method. This behaviour can be
changed by passing the appropriate arguments to the constructor.

Some methods in this class have the ability to insert data in a OutputWidget. They
will do so if the <tt>@output_widget</tt> instance variable (which is created in
the constructor, if it doesn't already exist) is not *nil*. Note that those methods
don't check if <tt>@output_widget</tt> actually is an OutputWidget or not. If it
is something else, you'll get errors. In all the following documentation it is
assumed that:
* the expression <i>the output widget</i> refers to the object the <tt>@output_widget</tt>
  instance variable refers to, unless it's *nil*
* everything concerning the output widget will be ignored (without giving any error)
  if the output widget doesn't exist

===Signals
=====<tt>process_finished(int code, QString reason)</tt>
Signal emitted when the process finishes. _code_ is the exit code of the process,
while _reason_ is a string which can have one of the values "killed", "crash" or
be empty. If it's empty, it means that the program finished normally; "killed"
means that it was killed by the user and "crash" means that the program crashed.
=====<tt>process_started()</tt>
Signal emitted when the process has started
=====<tt>process_failed_to_start()</tt>
Signal emitted if the process couldn't be started (for example, because the given
program doesn't exist)
===Slots
* <tt>slot_process_finished(int, QProcess::ExitStatus)</tt>
* <tt>stop_process()</tt>
=end
  class ExternalProgramPlugin < GuiPlugin

    slots 'slot_process_finished(int, QProcess::ExitStatus)', 'display_exit_message(int, QString)',
        :stop_process

    signals 'process_finished(int, QString)', :process_started, :process_failed_to_start

=begin rdoc
The <tt>KDE::Process</tt> used by the plugin
=end
    attr_reader :process

=begin rdoc
Creates a new ExternalProgramPlugin.

_pdf_ is the plugin info object for the plugin. If <i>line_buffered</i> is *false*,
buffering won't be used (all the characters read from the process will be passed
to <tt>process_standard_output</tt> or <tt>process_standard_error</tt> even if they
don't end in a newline).

<b>Note:</b> the process' channel mode will be set to <tt>Qt::Process::SeparateChannels</tt>.
You can set it to any value you want later
=end
    def initialize pdf, line_buffered = true
      super pdf
      @buffer = nil
      @buffer_content_channel = nil
      @line_buffered = line_buffered
      @output_widget = nil unless defined? @output_widget
      @process = KDE::Process.new self
      @process.process_channel_mode = Qt::Process::SeparateChannels
      @process.output_channel_mode = KDE::Process::SeparateChannels
      @process.connect SIGNAL(:readyReadStandardOutput) do
        do_stdout @process.read_all_standard_output.to_s
      end
      @process.connect SIGNAL(:readyReadStandardError) do
        do_stderr @process.read_all_standard_error.to_s
      end
      connect @process, SIGNAL('finished(int, QProcess::ExitStatus)'), self, SLOT('slot_process_finished(int, QProcess::ExitStatus)')
      connect self, SIGNAL('process_finished(int, QString)'), self, SLOT('display_exit_message(int, QString)')
      @process.connect SIGNAL('error(QProcess::ProcessError)') do |e|
        failed_to_start if e == Qt::Process::FailedToStart
      end
      connect @process, SIGNAL('started()'), self, SIGNAL('process_started()')
    end

=begin rdoc
Starts the program.

_prog_ is the name of the program (you don't need to specify the absolute path
if it's in PATH). _args_ is an array containing the arguments. _dir_ is the working
directory.

_title_ is the string to display in the output widget. If it is an empty string, the name
of the program followed by its arguments will be used. If it is *nil* or *false*,
the title won't be set.
=end
    def run_process prog, dir, args, title = ''
      @buffer = nil
      @buffer_content_channel = nil
      @process.clear_program
      @process.working_directory = dir
      program = [prog] + args
      @process.program = program
      if @output_widget and title
        title = program.join ' ' if title.empty?
        @output_widget.title = title
      end
      @process.start
    end

=begin rdoc
Stops the process.

It's a shortcut for <tt>process.kill</tt>
=end
    def stop_process
      @process.kill
    end

=begin rdoc
Prepares the plugin to be unloaded by killing the process (no signal will be emitted
from the process or the plugin from now on).

If you reimplement this method, don't forget to call *super*. If you don't you
might cause a crash when Ruber is closed
=end
    def shutdown
      @process.block_signals true
      @process.kill
      super
    end

    private

=begin rdoc
Pre-processes the string _str_ then passes the resulting array to <tt>process_standard_output</tt>.

Pre-processing the string means:
* splitting it into lines
* emptying the buffer (by passing its contents to <tt>process_standard_error</tt>
  if it refers to standard error or prepending it to _str_ if it refers to standard
  output)
* putting the last line in the buffer if it doesn't end in a newline.

If the plugin is not buffered, then only the first step is done.

<b>Note:</b> if _str_ is empty, nothing will happen. If it consists only of newlines,
it will cause the buffer to be emptied (as described above) and nothing else.
<b>Note:</b> consecutive newlines will be treated as a single newline
=end
    def do_stdout str
      return if str.empty?
      if @line_buffered and @buffer
        buffer = @buffer
        channel = @buffer_content_channel
        @buffer = nil
        @buffer_content_channel = nil
        if channel == :stdout
          str = buffer + str
          return do_stdout str
        else process_standard_error [buffer]
        end
      end
      lines = str.split_lines
      if @line_buffered and !str.end_with? "\n"
        @buffer = lines.pop
        @buffer_content_channel = :stdout
      end
      return if lines.empty?
      process_standard_output lines
    end

=begin rdoc
Pre-processes the string _str_ then passes the resulting array to <tt>process_standard_error</tt>.

Pre-processing the string means:
* splitting it into lines
* emptying the buffer (by passing its contents to <tt>process_standard_output</tt>
  if it refers to standard output or prepending it to _str_ if it refers to standard
  error)
* putting the last line in the buffer if it doesn't end in a newline.

If the plugin is not buffered, then only the first step is done.

<b>Note:</b> if _str_ is empty, nothing will happen. If it consists only of newlines,
it will cause the buffer to be emptied (as described above) and nothing else.
<b>Note:</b> consecutive newlines will be treated as a single newline
=end
    def do_stderr str
      return if str.empty?
      if @line_buffered and @buffer
        buffer = @buffer
        channel = @buffer_content_channel
        @buffer = nil
        @buffer_content_channel = nil
        if channel == :stderr
          str = buffer + str
          return do_stderr str
        else process_standard_output [buffer]
        end
      end
      lines = str.split_lines
      if @line_buffered and !str.end_with? "\n"
        @buffer = lines.pop
        @buffer_content_channel = :stderr
      end
      return if lines.empty?
      process_standard_error lines
    end

=begin rdoc
Does something with the text written to standard output by the program.

The base class implementation of this method inserts the text at the end of the
output widget in the first column (one item per line) and sets the output type
to +:output+. Nothing is done if the output widget doesn't exist. Subclasses
can reimplement this method to do something else (in this case, you don't usually
want to call *super*)

_lines_ is an array where each entry corresponds to a line of output from the
program. If buffering is on, each entry is a complete line (or should be considered
such). If buffering is off, you'll have to take care of newlines by yourself.

@param [Array<String>] lines the output lines
@return [nil]
=end
    def process_standard_output lines
      return unless @output_widget
      mod = @output_widget.model
      rc = mod.row_count
      mod.insert_rows rc, lines.size
      lines.each_with_index do |l, i|
        idx = mod.index(i + rc, 0)
        mod.set_data idx, Qt::Variant.new(l)
        @output_widget.set_output_type idx, :output
      end
      nil
    end

=begin rdoc
Does something with the text written to standard error by the program.

The base class implementation of this method inserts the text at the end of the
output widget in the first column (one item per line) and sets the output type
to +:output+. Nothing is done if the output widget doesn't exist. Subclasses
can reimplement this method to do something else (in this case, you don't usually
want to call *super*)

_lines_ is an array where each entry corresponds to a line of output from the
program. If buffering is on, each entry is a complete line (or should be considered
such). If buffering is off, you'll have to take care of newlines by yourself.

@param [Array<String>] lines the lines on standard error
@return [nil]
=end
    def process_standard_error lines
      return unless @output_widget
      mod = @output_widget.model
      rc = mod.row_count
      mod.insert_rows rc, lines.size
      lines.each_with_index do |l, i|
        idx = mod.index(i + rc, 0)
        mod.set_data idx, Qt::Variant.new(l)
        @output_widget.set_output_type idx, :error
      end
      nil
    end

=begin rdoc
Method called if the program fails to start (in response, but not connected to,
the process <tt>error(QProcess::ProcessError)</tt> signal if the argument is
<tt>Qt::Process::FailedToStart</tt>).

It emits the <tt>process_failed_to_start()</tt> signal and displays an appropriate
message to the output widget (using the <tt>:error1</tt> output type).

If <tt>@output_widget</tt> is not *nil* but you don't want the message to be
generated, you'll need to override this method. If you do so, don't forget to
emit the <tt>failed_to_start()</tt> signal.
=end
    def failed_to_start
      emit process_failed_to_start
      if @output_widget
        mod = @output_widget.model
        rc = mod.row_count
        mod.insert_row rc
        cmd = @process.program
        cmd_line = cmd.join " "
        prog = cmd.shift
        idx = mod.index(rc, 0)
        mod.set_data idx, Qt::Variant.new("#{prog} failed to start. The command line was #{cmd_line}")
        @output_widget.set_output_type idx, :error1
      end
    end

=begin rdoc
Slot called in response to the process' <tt>finished(int, QProcess::ExitStatus)</tt>
signal.

It emits the <tt>process_finished(int, QString)</tt> signal
=end
    def slot_process_finished code, status
      str = @process.read_all_standard_output.to_s
      str << "\n" unless str.end_with?("\n")
      do_stdout str
      str = @process.read_all_standard_error.to_s
      str << "\n" unless str.end_with?("\n")
      do_stderr str
      reason = ''
      if status == Qt::Process::CrashExit
        reason = code == 0 ? 'killed' : 'crash'
      end
      emit process_finished code, reason
    end

=begin rdoc
Displays a message in the output widget describing the exit status of the program.

The message (output type message) has the format <i>program_name</i> <i>message</i>,
where message is:

* <tt>exited normally</tt> if _reason_ is an empty string
* <tt>was killed</tt> if _reason_ is 'killed'
* <tt>exited with code</tt> _code_ if _reason_ is 'crash'

This method is meant to be connected to the <tt>process_finished(int, QString)</tt>
signal. Its arguments match those of the signal.

If you want to change the message, override this method. If you don't want any
message and the <tt>@output_widget</tt> instance variable is not *nil*, you can
either disconnect this slot from the <tt>process_finished(int, QString)</tt>
signal or override this method without calling *super*
=end
    def display_exit_message code, reason
      return unless @output_widget
      mod = @output_widget.model
      rc = mod.row_count
      mod.insert_row rc
      idx = mod.index rc, 0
      type = :message
      text = "Process "
      case reason
      when ''
        if code == 0 then text << 'exited normally'
        else
          text << "exited with code #{code}"
          type = :message_bad
        end
      when 'killed' then text << 'killed'
      when 'crash'
        text << "crashed with code #{code}"
        type = :message_bad
      end
      mod.set_data idx, Qt::Variant.new(text)
      @output_widget.set_output_type idx, type
    end

  end

end