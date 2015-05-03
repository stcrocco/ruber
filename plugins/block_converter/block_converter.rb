module Ruber

=begin rdoc
Module for the block converter plugin

This plugin converts a @do/end@ block to a brace block and vice versa.

Currently, the user needs to select the block to convert. The selection should
start right before the @do@ or opening brace and and right after the @end@ or
the closing brace.
=end
  module BlockConverter

=begin rdoc
Plugin class for the block converter plugin
=end
    class Plugin < GuiPlugin

      BlockInfo = Struct.new :type, :args, :content, :one_line

=begin rdoc
Class containing the information obtained by parsing a block

@!attribute type
  @return [Symbol] the type of block. It can be either @:do_block@ or @:brace_block@
@!attribute args
  @return [String] the string with the arguments passed to the block, without the
    leading and trailing @|@
@!attribute content
  @return [String] the content of the block, without leading or trailing newlines
@!attribute one_line
  @return [Boolean] whether the code of block has a single line or not
@!method initialize type, args, content, one_line
  Returns a new istance of BlockInfo
  @param [Symbol] type the type of block. See {#type}
  @param [String] args the arguments of the block. See {#args}
  @param [String] content the contents of the block. See {#content}
  @param [Boolean] one_line whether the code of the block is on one line or not
  @return [BlockInfo]
=end
      class BlockInfo;end

=begin rdoc
Regexps for detecting a @do/end@ or a brace block
=end
      REGEXPS = {
        :do => /\A\s*do\b\s*(?:\|([^|]+)\|)?(.*)\bend\Z/m,
        :brace => /\A\s*\{\s*(?:\|([^|]+)\|)?(.*)\}\s*\Z/m
      }

=begin rdoc
Converts the selected block in the current view from @do/end@ to brace and vice versa

If there isn't a view or the view doesn't have a selection, nothing is done.

If the selected text isn't recognized as a block, the user is warned and nothing
is done.
@return [void]
=end
      def convert_block
        view = Ruber[:world].active_environment.active_editor
        return unless view.selection
        range = view.selection_range
        text = view.selection_text
        data = detect_block_data text
        if data
          if data.type == :do_block then repl = compute_brace_block data
          else repl = compute_do_block data
          end
          view.document.replace_text view.selection_range, repl
        else
          KDE::MessageBox.sorry view, "<p>The selected text is couldn't be recognized as either a <code>do/end</code> block or a brace block.</p>"
        end
      end
      slots :convert_block

      private

=begin rdoc
Attempts to find out information about a block contained in a string

This method assumes that the given string exactly contains a block (that is, that
the string starts with the @do@ keyword or the opening brace and ends with the
@end@ keyword or the closing brace. Leading and trailing whitespaces are accepted).

@param [String] str the string containing the block
@return [BlockInfo] the information about the block
@return [nil] if no block was recognized in the string
=end
      def detect_block_data str
        REGEXPS.each_pair do |t, r|
          m = str.match r
          if m
            content = m[2].sub(/\A\n+/m, '').sub(/\n+\Z/, '')
            one_line = content.split("\n").count < 2
            return BlockInfo.new :"#{t}_block", content, m[1], one_line
          end
        end
        nil
      end

=begin rdoc
Computes the code to use to replace a @do/end@ block with a brace block

If the body of the original block only had one line, the resulting block will
all be on one line, otherwise it'll be multiline.

@param [BlockInfo] data the data describing the block
@return [String] the code to replace the original block with
=end
      def compute_brace_block data
        res = '{'
        res << '|' << data.args << '|' if data.args
        res << "\n" unless data.one_line
        res << data.content
        res << "\n" unless data.one_line
        res << "}"
        res
      end

=begin rdoc
Computes the code to use to replace a brace block with a @do/end@ block

@param [BlockInfo] data the data describing the block
@return [String] the code to replace the original block with
=end
      def compute_do_block data
        res = 'do'
        res << ' |' << data.args << '|' if data.args
        res << "\n" << data.content << "\nend"
        res
      end

    end

  end

end
