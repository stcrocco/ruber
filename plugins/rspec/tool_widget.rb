module Ruber

  module RSpec

=begin rdoc
Filter model used by the RSpec output widget

It allows to choose whether to accept items corresponding to output to standard error or to reject
it. To find out if a given item corresponds to the output of standard error or
standard output, this model uses the data contained in a custom role in the output.
The index of this role is {RSpec::OutputWidget::OutputTypeRole}.
=end
    class FilterModel < FilteredOutputWidget::FilterModel

      slots 'toggle_display_stderr(bool)'

=begin rdoc
Whether output from standard error should be displayed or not
@return [Boolean]
=end
      attr_reader :display_stderr

=begin rdoc
Create a new instance

The new instance is set not to show the output from standard error

@param [Qt::Object, nil] parent the parent object
=end
      def initialize parent = nil
        super
        @display_stderr = false
      end

=begin rdoc
Sets whether to display or ignore items corresponding to output to standard error

If this choice has changed, the model is invalidated.

@param [Boolean] val whether to display or ignore the output to standard error
@return [Boolean] _val_
=end
      def display_stderr= val
        old, @display_stderr = @display_stderr, val
        invalidate if old != @display_stderr
        @display_standard_error
      end
      alias_method :toggle_display_stderr, :display_stderr=

=begin rdoc
Override of {FilteredOutputWidget::FilterModel#filterAcceptsRow}

According to the value of {#display_stderr}, it can filter out items corresponding
to standard error. In all other respects, it behaves as the base class method.
@param [Integer] r the row number
@param [Qt::ModelIndex] parent the parent index
@return [Boolean] *true* if the row should be displayed and *false* otherwise
=end
      def filterAcceptsRow r, parent
        if !@display_stderr
          idx = source_model.index(r,0,parent)
          return false if idx.data(OutputWidget::OutputTypeRole).to_string == 'output1'
        end
        super
      end

    end

=begin rdoc
Tool widget used by the rspec plugin.

It displays the output from the spec program in a multi column tree. The name of
failing or pending examples are displayed in a full line; all other information,
such as the location of the example, the error message and so on are displayed
in child items.

While the examples are being run, a progress bar is shown.
=end
    class ToolWidget < FilteredOutputWidget

      slots :spec_started, 'spec_finished(int, QString)'

=begin rdoc
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize parent = nil
        super parent, :view => :tree, :filter => FilterModel.new
        @toplevel_width = 0
        @ignore_word_wrap_option = true
        view.text_elide_mode = Qt::ElideNone
        model.append_column [] if model.column_count < 2
        @progress_bar = Qt::ProgressBar.new(self){|w| w.hide}
        layout.add_widget @progress_bar, 2,0
        view.header_hidden = true
        view.header.resize_mode = Qt::HeaderView::ResizeToContents
        connect Ruber[:rspec], SIGNAL(:process_started), self, SLOT(:spec_started)
        connect Ruber[:rspec], SIGNAL('process_finished(int, QString)'), self, SLOT('spec_finished(int, QString)')
        view.word_wrap = true
        filter.connect(SIGNAL('rowsInserted(QModelIndex, int, int)')) do |par, st, en|
          if !par.valid?
            st.upto(en) do |i|
              view.set_first_column_spanned i, par, true
            end
          end
        end
        #without these, the horizontal scrollbars won't be shown
        connect view, SIGNAL('expanded(QModelIndex)'), self, SLOT(:resize_columns)
        connect view, SIGNAL('collapsed(QModelIndex)'), self, SLOT(:resize_columns)
        setup_actions
      end

=begin rdoc
Displays the data relative to an example in the widget

Actually, this method simply passes its argument to a more specific method, depending
on the data it contains.

@param [Hash] data a hash containing the data describing the results of running
the example. This hash must contain the @:type@ key, which tells which kind of
event the hash describes. The other entries change depending on the method which
will be called, which is determined according to the @:type@ entry:
 * @:success@: {#display_successful_example}
 * @:failure@: {#display_failed_example}
 * @:pending@: {#display_pending_example}
 * @:new_example@: {#change_current_example}
 * @:start@: {#set_example_count}
 * @:summary@: {#display_summary}
If the @:type@ entry doesn't have one of the previous values, the hash will be
converted to a string and displayed in the widget
=end
      def display_example data
        unless data.is_a?(Hash)
          model.insert_lines data.to_s, :output, nil
          return
        end
        case data[:type]
        when :success then display_successful_example data
        when :failure then display_failed_example data
        when :pending then display_pending_example data
        when :new_example then change_current_example data
        when :start then set_example_count data
        when :summary then display_summary data
        when :deprecation then display_deprecation data
        else model.insert_lines data.to_s, :output, nil
        end
      end

      def load_settings
        super
        compute_spanning_cols_size
        resize_columns
      end

=begin rdoc
Changes the current example

Currently, this only affects the tool tip displayed by the progress bar.

@param [Hash] data the data to use. It must contain the @:description@ entry,
which contains the text of the tool tip to use.
@return [nil]
=end
      def change_current_example data
        @progress_bar.tool_tip = data[:description]
        nil
      end

=begin rdoc
Sets the number of examples found by the spec program.

This is used to set the maximum value of the progress bar.

@param [Hash] data the data to use. It must contain the @:count@ entry,
which contains the number of examples
@return [nil]
=end
      def set_example_count data
        @progress_bar.maximum = data[:count]
        nil
      end


=begin rdoc
Updates the progress bar by incrementing its value by one

@param [Hash] data the data to use. Currently it's unused
@return [nil]
=end
      def display_successful_example data
        @progress_bar.value += 1
        nil
      end

=begin rdoc
Displays information about a failed example in the tool widget.

@param [Hash] data the data about the example.

@option data [String] :location the line number where the error occurred
@option data [String] :description the name of the failed example
@option data [String] :message the explaination of why the example failed
@option data [String] :exception the content of the exception
@option data [String] :backtrace the backtrace of the exception (a single new-line separated string)
@return [nil]
=end
      def display_failed_example data
        @progress_bar.value += 1
        top = model.insert("[FAILURE] #{data[:description]}", :error, nil).first
        model.insert ['From:', data[:location]], :message, nil, :parent => top
        ex_label = model.insert('Exception:', :message, nil, :parent => top).first
        exception_body = "#{data[:message]} (#{data[:exception]})".split_lines.delete_if{|l| l.strip.empty?}
        #exception_body may contain more than one line and some of them may be empty
        model.set exception_body.shift, :message, ex_label.row, :col => 1, :parent => top
        exception_body.each do |l|
          unless l.strip.empty?
            model.set l, :message, top.row_count, :col => 1, :parent => top
          end
        end
        backtrace = data[:backtrace].split_lines
        back_label, back = model.insert(['Backtrace:', backtrace.shift], :message, nil, :parent => top)
        backtrace.each do |l|
          model.insert [nil, l], :message, nil, :parent => back_label
        end
        top_index = filter.map_from_source(top.index)
        view.collapse top_index
        view.set_first_column_spanned top_index.row, Qt::ModelIndex.new, true
        view.expand filter.map_from_source(back_label.index)
        nil
      end

=begin rdoc
Displays information about a pending example in the tool widget

@param [Hash] data
@option data [String] :location the line number where the error occurred
@option data [String] :description the name of the failed example
@option data [String] :message the explaination of why the example failed
@return [nil]
=end
      def display_pending_example data
        @progress_bar.value += 1
        top = model.insert("[PENDING] #{data[:description]}", :warning, nil)[0]
        model.insert ['From:', data[:location]], :message, nil, :parent => top
        model.insert ['Message: ', "#{data[:message]} (#{data[:exception]})"], :message, nil, :parent => top
        nil
      end

=begin rdoc
Displays a deprecation notice from rspec

@parah [Hash] data the data about the deprecation
@option data [String] @:message@ the message associated with the deprecation warning
@option data [String] @:site@ where the deprecation warning came from
@option data [String] @:replacement@ the replacement suggested by RSpec
@return [nil]
=end
      def display_deprecation data
        top = model.insert("[DEPRECATION] #{data[:message]}", :warning, nil)[0]
        if working_dir then site = data[:site].sub(/^#{Regexp.quote working_dir}\//, './')
        else site = data[:site]
        end
        model.insert ['From:', site], :message, nil, :parent => top
        model.insert ['Suggestions:', data[:replacement]], :message, nil, :parent => top
        nil
      end

=begin rdoc
Displays a summary of the spec run in the tool widget

The summary is a single title line which contains the number or successful, pending
and failed example.

@param [Hash] data
@option data [Integer] :total the number of run examples
@option data [Integer] :passed the number of passed examples
@option data [Integer] :failed the number of failed examples
@option data [Integer] :pending the number of pending examples
@return [nil]
=end
      def display_summary data
        @progress_bar.hide
        if data[:passed] == data[:total]
          self.title = "[SUMMARY] All #{data[:total]} examples passed"
          set_output_type model.index(0,0), :message_good
        else
          text = "[SUMMARY]      Examples: #{data[:total]}"
          text << "      Failed: #{data[:failure]}" if data[:failure] > 0
          text << "      Pending: #{data[:pending]}" if data[:pending] > 0
          text << "      Passed: #{data[:passed]}"
          self.title = text
          type = data[:failure] > 0 ? :message_bad : :message
          set_output_type model.index(0,0), type
        end
        nil
      end

=begin rdoc
Override of {OutputWidget#title=}

It's needed to have the title element span all columns

@param [String] val the new title
=end
      def title= val
        super
        model.item(0,0).tool_tip = val
        view.set_first_column_spanned 0, Qt::ModelIndex.new, true
      end

      private

=begin rdoc
Resets the tool widget and sets the cursor to busy
@return [nil]
=end
      def spec_started
        @progress_bar.maximum = 0
        @progress_bar.value = 0
        @progress_bar.show
        @progress_bar.tool_tip = ''
        actions['show_stderr'].checked = false
        self.cursor = Qt::Cursor.new(Qt::BusyCursor)
        nil
      end

=begin rdoc
Does the necessary cleanup for when spec finishes running

It hides the progress widget and restores the default cursor.

@param [Integer] code the exit code
@param [String] reason why the program exited
@return [nil]
=end
      def spec_finished code, reason
        @progress_bar.hide
        @progress_bar.value = 0
        @progress_bar.maximum = 100
        self.set_focus
        unset_cursor
        unless reason == 'killed'
          non_stderr_types = %w[message message_good message_bad warning error]
          only_stderr = !model.item(0,0).text.match(/^\[SUMMARY\]/)
          if only_stderr
            1.upto(model.row_count - 1) do |i|
              if non_stderr_types.include? model.item(i,0).data(OutputWidget::OutputTypeRole).to_string
                only_stderr = false
                break
              end
            end
          end
          if only_stderr
            actions['show_stderr'].checked = true
            model.insert "spec wasn't able to run the examples", :message_bad, nil
          end
        end
        compute_spanning_cols_size
        auto_expand_items
        nil
      end

=begin rdoc
Expands items according to the @rspec/auto_expand@ option

If the option is @:expand_first@, the first failed example is expanded; if the
option is @:expand_all@, all failed or pending examples are expanded. If the option
is @:expand_none@, nothing is done
@return [nil]
=end
      def auto_expand_items
        if model.row_count > 1
          case Ruber[:config][:rspec, :auto_expand]
          when :expand_first
            item = model.each_row.find{|items| items[0].has_children}
            view.expand filter_model.map_from_source(item[0].index) if item
          when :expand_all
            without_resizing_columns do
              model.each_row do |items|
                view.expand filter_model.map_from_source(items[0].index)
              end
            end
            resize_columns
          end
        end
        nil
      end

      def compute_spanning_cols_size
        metrics = view.font_metrics
        @toplevel_width = source_model.each_row.map{|r| metrics.bounding_rect(r[0].text).width}.max || 0
      end

      def resize_columns
        view.resize_column_to_contents 0
        view.resize_column_to_contents 1
        min_width = @toplevel_width - view.column_width(0) + 30
        view.set_column_width 1, min_width if view.column_width(1) < min_width
      end
      slots :resize_columns

      def without_resizing_columns
        disconnect view, SIGNAL('expanded(QModelIndex)'), self, SLOT(:resize_columns)
        begin yield
        ensure connect view, SIGNAL('expanded(QModelIndex)'), self, SLOT(:resize_columns)
        end
      end

=begin rdoc
Creates the additional actions.

It adds a single action, which allows the user to chose whether messages from
standard error should be displayed or not.

@return [nil]
=end
      def setup_actions
        action_list << nil << 'show_stderr'
        a = KDE::ToggleAction.new 'S&how Standard Error', self
        actions['show_stderr'] = a
        a.checked = false
        connect a, SIGNAL('toggled(bool)'), filter, SLOT('toggle_display_stderr(bool)')
      end

=begin rdoc
Override of {OutputWidget#find_filename_in_index}

It works as the base class method, but, if it doesn't find a result in _idx_,
it looks for it in the parent indexes

@param [Qt::ModelIndex] idx the index where to look for a file name
@return [Array<String,Integer>,String,nil] see {OutputWidget#find_filename_in_index}
=end
      def find_filename_in_index idx
        res = super
        unless res
          idx = idx.parent while idx.parent.valid?
          idx = idx.child(0,1)
          res = super idx if idx.valid?
        end
        res
      end

=begin rdoc
Override of {OutputWidget#text_for_clipboard}

@param [<Qt::ModelIndex>] idxs the selected indexes
@return [QString] the text to copy to the clipboard
=end
      def text_for_clipboard idxs
        order = {}
        idxs.each do |i|
          val = []
          parent = i
          while parent.parent.valid?
            parent = parent.parent
            val.unshift parent.row
          end
          val << [i.row, i.column]
          order[val] = i
        end
        order = order.sort do |a, b|
          a, b = a[0], b[0]
          res = a[0..-2] <=>  b[0..-2]
          if res == 0 then a[-1] <=> b[-1]
          else res
          end
        end
        prev = order.shift[1]
        text = prev.data.valid? ? prev.data.to_string : ''
        order.each do |_, v|
          text << ( (prev.parent == v.parent and prev.row == v.row) ? "\t" : "\n")
          text << (v.data.valid? ? v.data.to_string : '')
          prev = v
        end
        text
      end

    end

  end

end