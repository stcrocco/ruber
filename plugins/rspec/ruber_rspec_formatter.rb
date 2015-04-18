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

require 'yaml'

module Ruber

  module RSpec

    begin
      require 'spec/runner/formatter/base_text_formatter'
      RSPEC_VERSION = 1
    rescue LoadError
      require 'rspec/core/version'
      require 'rspec/core/formatters/base_text_formatter'
      RSPEC_VERSION = ::RSpec::Core::Version::STRING.split('.')[0].to_i
    end

    base = RSPEC_VERSION == 1 ? Spec::Runner::Formatter::BaseTextFormatter : ::RSpec::Core::Formatters::BaseTextFormatter

=begin rdoc
RSpec formatter used by the rspec plugin

It writes data as YAML-formatted hashes. The data relative to a single example,
as well as the preamble and the summary, are separated from each other with special
strings, stored in the {STARTING_DELIMITER} and {ENDING_DELIMITER} constants. This
is made to avoid problems in case buffering breaks a string containing one of these
strings in pieces.

Among keys specific to each of them, all the hashes contain the @:type@ key, which
tells which kind of information the hash contains.

@$$$$%%%%$$$$KRUBY_BEGIN@

and

@$$$$%%%%$$$$KRUBY_END@

The output is flushed after every writing

This is a base class used by both {Version1Formatter} and {Version2Formatter} which
defines all the methods which haven't changed in from RSpec 1 to RSpec 2. In particular,
it doesn't contain the @example_failed@ and @example_pending@ methods as their
signature has changed from one version to the ohter.
=end
    class BaseFormatter < base

=begin rdoc
The starting delimiter used by the formatter
@todo (after first alpha) Change it to include the string @KRUBY@ with @RUBER@ inside it
=end
      STARTING_DELIMITER = '####%%%%####KRUBY_BEGIN'

=begin rdoc
The ending delimiter used by the formatter
@todo (after first alpha) Change it to include the string @KRUBY@ with @RUBER@ inside it
=end
      ENDING_DELIMITER = '####%%%%####KRUBY_END'

=begin rdoc
Method called by RSpec after the examples have been collected

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:start@
* @:count@: the number of examples found by RSpec
@param [Integer] count the number of examples
@return [nil]
=end
      def start count
        super
        hash = {:type => :start, :count => count}
        write_data hash
      end

=begin rdoc
Method called by RSpec after starting an example

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:new_example@
* @:description@: the name of the example, made of the name of the example group
and the description of the example itself
@param [Spec::Example::ExampleProxy] ex the started example
@return [nil]
=end
      def example_started ex
        super
        hash = {}
        hash[:type] = :new_example
        hash[:description] = "#{example_group.description} #{ex.description}"
        write_data hash
      end

=begin rdoc
Method called by RSpec after an example has been completed successfully

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:success@
* @:description@: the name of the passed example, made of the name of the example group
and the description of the example itself
@param [Spec::Example::ExampleProxy] ex the started example
@return [nil]
=end
      def example_passed ex
        super
        hash = {}
        hash[:type] = :success
        hash[:description] = "#{example_group.description} #{ex.description}"
        write_data hash
      end

=begin rdoc
Override of @Spec::Runner::Formatter::BaseTextFormatter#dump_failure@ which does nothing
@return [nil]
=end rdoc
      def dump_failure counter, fail
      end


=begin rdoc
Override of @Spec::Runner::Formatter::BaseTextFormatter#dump_pending@ which does nothing
@return [nil]
=end rdoc
      def dump_pending
      end

=begin rdoc
Method called by RSpec after running all the examples

It writes a summary containing the number of run, failed, passed an pending examples
to the output as a YAML dumnp of a hash. The hash has the following entries:
The hash contains the following entries (the keys are all symbols)
@:type@: @:summary@
@total@: the number of run examples
@failure@: the number of failed examples
@pending@: the number of pending examples
@passed@: the number of passed examples
@return [nil]
=end
      def dump_summary time, total, failure, pending
        hash = {
          :type => :summary,
          :total => total,
          :failure => failure,
          :pending => pending,
          :passed => total - (failure + pending)
        }
        write_data hash
      end

      def dump_failures
      end

      private

=begin rdoc
Writes data to the output stream

The data is passed in hashes and is written as a YAML dump between a starting
and an end delimiter. The output stream is flueshed both before and after writing,
so that the data is written alone on the string

@param [Hash] data the data to write on the output stream
@return [nil]
=end
      def write_data hash
#         STDERR.puts hash.inspect
        @output.flush
        str = "#{STARTING_DELIMITER}\n#{YAML.dump(hash)}\n#{ENDING_DELIMITER}"
        @output.puts str
#         @output.puts STARTING_DELIMITER
#         @output.puts YAML.dump(hash)
#         @output.puts ENDING_DELIMITER
        @output.flush
        nil
      end

    end

    class Version1Formatter < BaseFormatter

=begin rdoc
Method called by RSpec after an example has been completed and failed

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:failure@
* @:description@: the name of the failed example, made of the name of the example group
and the description of the example itself
* @:exception@: the name of the exception class which caused the failure
* @:message@: the error message contained in the exception which caused the failure
* @:location@: a string with the location (file name and line number) where the
failure happened
* @:backtrace@: a string containing the entries of the exception's backtrace, joined
by newlines
@param [Spec::Example::ExampleProxy] ex the failed example
@param [Integer] counter the number of the failed example
@param [Spec::Runner::Reporter::Failure] failure the object describing the failure
@return [nil]
=end
      def example_failed ex, counter, failure
        hash = {}
        hash[:type] = :failure
        hash[:description] = "#{@example_group.description} #{ex.description}"
        hash[:exception] = failure.exception.class.name
        hash[:message] = failure.exception.message
        hash[:location] = ex.location
        hash[:backtrace] = failure.exception.backtrace.join "\n"
        write_data hash
      end

=begin rdoc
Method called by RSpec after a pending example has been executed

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:pending@
* @:description@: the name of the pending example, made of the name of the example group
and the description of the example itself
* @:message@: the message produced by @pending@
* @:location@: a string with the location (file name and line number) of pending
example
@param [Spec::Example::ExampleProxy] ex the pending example
@param [String] msg the message associated with the pending example
@return [nil]
=end
      def example_pending ex, msg
        hash = {}
        hash[:type] = :pending
        hash[:description] = "#{@example_group.description} #{ex.description}"
        hash[:message] = msg
        hash[:location] = ex.location
        write_data hash
      end

    end

    class Version2Formatter < BaseFormatter
=begin rdoc
Method called by RSpec after an example has been completed and failed

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:failure@
* @:description@: the name of the failed example, made of the name of the example group
and the description of the example itself
* @:exception@: the name of the exception class which caused the failure
* @:message@: the error message contained in the exception which caused the failure
* @:location@: a string with the location (file name and line number) where the
failure happened
* @:backtrace@: a string containing the entries of the exception's backtrace, joined
by newlines
@param [RSpec::Core::Example] ex the failed example
@return [nil]
@todo add an entry contaning the code which caused the error (obtained using the
@read_failed_line@ method defined in @RSpec::Core::Formatters::BaseFormatter@).
=end
      def example_failed ex
        super
        hash = {}
        hash[:type] = :failure
        hash[:description] = ex.metadata[:full_description]
        # It seems that rspec up tp 2.2 uses :exception_encountered, while from
        # 2.3 it uses :exception. This should work for both
        exception = ex.metadata[:execution_result][:exception]
        exception ||= ex.metadata[:execution_result][:exception_encountered]
        hash[:exception] = exception.class.name
        hash[:message] = exception.message
        hash[:location] = ex.metadata[:location]
        hash[:backtrace] =  format_backtrace(exception.backtrace, ex).join "\n"
        write_data hash
      end

=begin rdoc
Method called by RSpec after a pending example has been executed

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:pending@
* @:description@: the name of the pending example, made of the name of the example group
and the description of the example itself
* @:message@: the message produced by @pending@
* @:location@: a string with the location (file name and line number) of pending
example
@param [RSpec::Core::Example] ex the pending example
@return [nil]
=end
      def example_pending ex
        super
        hash = {}
        hash[:type] = :pending
        hash[:description] = ex.metadata[:full_description]
        hash[:message] = ex.metadata[:execution_result][:pending_message]
        hash[:location] = ex.metadata[:location]
        write_data hash
      end

    end

    class Version3Formatter

=begin rdoc
The starting delimiter used by the formatter
@todo (after first alpha) Change it to include the string @KRUBY@ with @RUBER@ inside it
=end
      STARTING_DELIMITER = '####%%%%####KRUBY_BEGIN'

=begin rdoc
The ending delimiter used by the formatter
@todo (after first alpha) Change it to include the string @KRUBY@ with @RUBER@ inside it
=end
      ENDING_DELIMITER = '####%%%%####KRUBY_END'

      if RSPEC_VERSION == 3
        ::RSpec::Core::Formatters.register self, :start, :example_started, :example_passed,
            :example_failed, :example_pending, :dump_summary, :deprecation
      end

=begin rdoc
@param [Object] output where to display the output
=end
      def initialize output
        @output = output
      end

=begin rdoc
Method called by RSpec after the examples have been collected

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:start@
* @:count@: the number of examples found by RSpec
@param [RSpec::Core::Notifications::StartNotification] notif the notification
@return [nil]
=end
      def start notif
        hash = {:type => :start, :count => notif.count}
        write_data hash
      end

=begin rdoc
Method called by RSpec after starting an example

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:new_example@
* @:description@: the name of the example, made of the name of the example group
and the description of the example itself
@param [RSpec::Core::Notifications::ExampleNotification] notif the notification
@return [nil]
=end
      def example_started notif
        hash = {}
        hash[:type] = :new_example
        ex = notif.example
        hash[:description] = "#{ex.example_group.description} #{ex.description}"
        write_data hash
      end

=begin rdoc
Method called by RSpec after an example has been completed successfully

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:success@
* @:description@: the name of the passed example, made of the name of the example group
and the description of the example itself
@param [RSpec::Core::Notifications::ExampleNotification] notif the notification
@return [nil]
=end
      def example_passed notif
        hash = {}
        hash[:type] = :success
        ex = notif.example
        hash[:description] = "#{ex.example_group.description} #{ex.description}"
        write_data hash
      end

=begin rdoc
Method called by RSpec after an example has been completed and failed

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:failure@
* @:description@: the name of the failed example, made of the name of the example group
and the description of the example itself
* @:exception@: the name of the exception class which caused the failure
* @:message@: the error message contained in the exception which caused the failure
* @:location@: a string with the location (file name and line number) where the
failure happened
* @:backtrace@: a string containing the entries of the exception's backtrace, joined
by newlines
@param [RSpec::Core::Example] ex the failed example
@return [nil]
@todo add an entry contaning the code which caused the error (obtained using the
@read_failed_line@ method defined in @RSpec::Core::Formatters::BaseFormatter@).
=end
      def example_failed notif
        hash = {}
        hash[:type] = :failure
        hash[:description] = notif.description
        exception = notif.exception
        hash[:exception] = exception.class.name
        hash[:message] = exception.message
        loc = notif.message_lines[0].split(':', 2)[1] || notif.message_lines[0]
        hash[:location] =  "#{notif.example.metadata[:location]} (#{loc.lstrip})"
        hash[:backtrace] = exception.backtrace.join "\n"
        write_data hash
      end

=begin rdoc
Method called by RSpec after a pending example has been executed

It writes to the output a YAML dump of a hash with the following entries:
* @:type@: @:pending@
* @:description@: the name of the pending example, made of the name of the example group
and the description of the example itself
* @:message@: the message produced by @pending@
* @:location@: a string with the location (file name and line number) of pending
example
@param [RSpec::Core::Example] ex the pending example
@return [nil]
=end
      def example_pending notif
        hash = {}
        hash[:type] = :pending
        hash[:description] = notif.description
        hash[:message] = notif.example.execution_result.pending_message
        hash[:location] = notif.example.metadata[:location]
        write_data hash
      end

=begin rdoc
Method called by RSpec after running all the examples

It writes a summary containing the number of run, failed, passed an pending examples
to the output as a YAML dumnp of a hash. The hash has the following entries:
The hash contains the following entries (the keys are all symbols)
@:type@: @:summary@
@total@: the number of run examples
@failure@: the number of failed examples
@pending@: the number of pending examples
@passed@: the number of passed examples
@param [RSpec::Core::Notifications::SummaryNotification] notif the notification
@return [nil]
=end
      def dump_summary notif
        hash = {
          :type => :summary,
          :total => notif.example_count,
          :failure => notif.failure_count,
          :pending => notif.pending_count,
          :passed => notif.example_count - notif.failure_count - notif.pending_count
        }
        write_data hash
      end

=begin rdoc
Method called by RSpec when displaying a deprecation warning

It writes the message, site of the deprecation and replacement purposal
to the output as a YAML dumnp of a hash. The hash contains the following entries
(the keys are all symbols):
-@:type@::= @:deprecation@
-@:message@::= the message associated with the warning
-@:site@::= the site where the deprecation warning originated
-@:replacement@::= the suggested replacement
@param [RSpec::Core::Notifications::DeprecationNotification] notif the notification
@return [nil]
=end
      def deprecation notif
        hash = {:type => :deprecation, :message => notif.message, :site => notif.call_site, :replacement => notif.replacement}
        write_data hash
      end

      private

=begin rdoc
Writes data to the output stream

The data is passed in hashes and is written as a YAML dump between a starting
and an end delimiter. The output stream is flueshed both before and after writing,
so that the data is written alone on the string

@param [Hash] data the data to write on the output stream
@return [nil]
=end
      def write_data hash
        @output.flush
        str = "#{STARTING_DELIMITER}\n#{YAML.dump(hash)}\n#{ENDING_DELIMITER}"
        @output.puts str
        @output.flush
        nil
      end

    end

=begin rdoc
The actual formatter to use, depending on the RSpec version in use
=end
    Formatter = const_get "Version#{RSPEC_VERSION}Formatter"

  end

end