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

require_relative 'ui/tool_widget'

require 'rdoc/ri/driver'
require 'rdoc/ri/store'
require 'open3'
require 'yaml'

module Ruber

=begin rdoc
Namespace for the @RI@ plugin
=end
  module RI

    SearchResult = Struct.new :query, :success, :entries, :error
=begin rdoc
The result of a @RI@ search

@!attribute query
  @return [String] what was searched for
@!attribute  success
  @return [Boolean] whether the search was carried on successfully or not

    That a search is carried out successfully doesn't necesssarily mean that
    something has been found; it only means that no errors occurred.

@!attribute  entries
  @return [<RIEntry>, nil] a list of all the entries in the @RI@ database corresponding
    to the query

    This is @nil@ if an error occurred in the search

@!attribute error
  @return [String, nil] the error message if an error occurred and @nil@ otherwise

@!method initialize query, success, entries, error
  Returns a new instance of SearchResult
  @param [String] query the query
  @param [Boolean] success whether the query was executed correctly or an error occurred
  @param [<RIEntry>, nil] a list of found entries (see {#entries})
  @param [String, nil] error the error message (see {#error})
  @return [SearchResult]
=end
    class SearchResult < Struct;end

    RIEntry = Struct.new :type, :store, :friendly_store, :store_type, :name

=begin rdoc
Class representing a single entry from the @RI@ database

@!attribute type
  @return [String] the type of entry. Can be either @class@ or @method@

@!attribute store
  @return [String] the path to the store file

@!attribute friendly_store
  @return [String] a friendly name for the store. Can be equal to {#store}

@!attribute store_type
  @return [String] the store type

@!attribute name
  @return [String] the name of the object

@!method initialize type=nil, store=nil, friendly_store = nil, store_type = nil, name = nil
  Returns a new instance of RIEntry

  @param [String] type
  @param [String] store
  @param [String] friendly_store
  @param [String] store_type
  @param [String] name

  @return [RIEntry] a new instance of RIEntry
=end
    class RIEntry;end

=begin rdoc
Class implementing the searching and formatting capabilities of the plugin
=end
    class Plugin < Ruber::Plugin

=begin rdoc
Searches the @RI@ database for the given text

The search is performed by the external script @search.rb@
located in the plugin directory.

@param [String] text the text to look up in the database
@return [SearchResult] an object containing the results of the search
=end
      def search text
        cmd = [ruby, File.join(File.dirname(__FILE__), 'search.rb'), text]
        list = nil
        err = nil
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          list = stdout.read
          err = stderr.read
          status = thr.value
        end
        search_result = SearchResult.new text, status.success?
        if status.success?
          result = YAML.load list
          search_result.entries = result[:list].map do |r|
            RIEntry.new result[:type], r[:store], r[:friendly_store],
                r[:store_type].to_s, r[:name]
          end
        else search_result.error = err
        end
        search_result
      end

=begin rdoc
Encodes all the information needed to create an {RIEntry entry} in an URL

@note Users of this method should not try to manually decode the entry from the URL,
  as the way the encoding is done can change; rather they should use the provided
  {#entry_for_url} method.

@param [RIEntry] e the entry to encode to an URL
@return [KDE::Url] the URL corresponding to _e_
=end
      def url_for_entry e
        encoded_name = Qt::Url.to_percent_encoding e.name
        KDE::Url.new "#{e.type}//#{e.store}$#{e.store_type}$#{encoded_name}"
      end

=begin rdoc
Creates an {RIEntry entry} from the information contained in an URL.

@param [KDE::Url] url the URL containing the information to create the {RIEntry}
  from. It must be an URL returned by {#url_for_entry}
@return [RIEntry] an entry created from the information stored in _url_
@raise [ArgumentError] if _url_ hasn't been created by {#url_for_entry}
=end
      def entry_for_url url
        type = url.scheme.to_sym
        store, store_type, name = url.path.split('$', 3)
        raise ArgumentError unless store and store_type and name
        RIEntry.new type, store, store, store_type, name
      end

=begin rdoc
Creates an HTML page from a search result

If the search result contains a single entry, the page will contain the description
of the class or method; if it contains more than one entry the page will contain
a list of links to the various entries; if an error occurred or the search produced
no result, the page will tell what happened.

@param [SearchResult] result the result to create the HTML page for
@return [String] the HTML code describing the contents of _result_
@see #error_msg
@see #format_nothing_found
@see #format_list
@see #format_entry
=end
      def format_result result
        if result.error
          error_msg "An error occurred while accessing the <code>RI</code> database:", result.error
        elsif result.entries.count == 0 then format_nothing_found result.query
        elsif result.entries.count > 1 then format_list result.entries
        else format_entry result.entries[0]
        end
      end

=begin rdoc
Creates an HTML page from an {RIEntry entry}

The page contains the information from the @RI@ database about a class or method.
The creation of the page is made by two external scripts, @class_formatter.rb@
and @method_formatter.rb@, located in the plugin directory.

@param [RIEntry] entry the entry to create the HTML page for
@return [String] the HTML code describing _entry_
=end
      def format_entry entry
        type, name, store, store_type = entry.type, entry.name, entry.store, entry.store_type
        meth = type == :method ? :format_method : :format_class
        method(meth).call name, store, store_type
      end

      private

=begin rdoc
@return [String] the ruby interpreter for the active document
=end
      def ruby
        Ruber[:ruby_development].interpreter_for Ruber[:world].active_document
      end

=begin rdoc
Creates an HTML page telling an error occurred

The page contains a paragraph describing what happened and the error message
(usually a backtrace)

@param [String] intro the description of what happened
@param [String] error the error message
@return [String] the HTML code of a page describing the error
=end
      def error_msg intro, error
        <<-EOS
<h1>Error</h1>
<p>#{intro}</p>
<pre>
#{err}
</pre>
        EOS
      end

=begin rdoc
Creates an HTML page telling that the search produced no result

@param [String] query the text looked up in the @RI@ database
@return [String] the HTML code of the page
=end
      def format_nothing_found query
        <<-EOS
<h1>Nothing found</h1>
<p>Nothing found about <code>#{query}</code> in the RI database</p>
        EOS
      end

=begin rdoc
Creates an HTML page containing links to the given {RIEntry entries}

This method simply calls {#format_class_list} or {#format_method_list} according
to the type of entries.

@param [<RIEntry>] entries the entries to create the list for. They must all be
  of the same type (either all classes or all methods)
@return [String] the HTML code of the page containing links to the given entries
=end
      def format_list entries
        mth = entries[0].type == :class ? :format_class_list : :format_method_list
        method(mth).call entries
      end

=begin rdoc
Creates an HTML page containing links to the given {RIEntry entries} representing
classes

@param [<RIEntry>] classes the entries to create the list for. They are assumed
  to be all entries of type @class@ (which includes modules)
@return [String] the HTML code of the page containing links to the given entries
=end
      def format_class_list classes
        res = "<h1>Results from RI</h1>"
        classes.each do |data|
          encoded_name = Qt::Url.to_percent_encoding data[:name]
          url = "class://#{data.store}$#{data.store_type}$#{encoded_name}"
          res << %[<p><a href="#{url}">#{data.name} &ndash; from #{data.friendly_store}</a></p>]
        end
        res
      end

=begin rdoc
Creates an HTML page containing links to the given {RIEntry entries} representing
methods

@param [<RIEntry>] methods the entries to create the list for. They are assumed
  to be all entries of type @method@
@return [String] the HTML code of the page containing links to the given entries
=end
      def format_method_list methods
        res = "<h1>Results from RI</h1>"
        methods.each do |data|
          d data
          encoded_name = Qt::Url.to_percent_encoding(data[:name])
          url = "method://#{data.store}$#{data.store_type}$#{encoded_name}"
          res << %[<p><a href="#{url}">#{data.name} &ndash; from #{data.friendly_store}</a></p>]
        end
        res
      end

=begin rdoc
Creates an HTML page containing the @RI@ documentation for a class

The page is created by an external script, @class_formatter.rb@, located in the
plugin directory.

@param [String] cls the name of the class (or module)
@param [String] store the path of the store file containing the information about
  the class
@param [String] store_type the type of store (as contained in a {RIEntry})
@return [String] the HTML code of the page. If an error occurs, the page will
  describe it
=end
      def format_class cls, store, store_type
        cmd = [ruby, File.join(File.dirname(__FILE__), 'class_formatter.rb'), cls, store, store_type]
        html = nil
        err = nil
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          html = stdout.read
          err = stderr.read
          status = thr.value
        end
        html
        if status.success? then html
        else
          error_msg "An error occurred while looking #{cls} up in the <code>RI</code> database:", err
        end

      end

=begin rdoc
Creates an HTML page containing the @RI@ documentation for a method

The page is created by an external script, @method_formatter.rb@, located in the
plugin directory.

@param [String] method the name of the method
@param [String] store the path of the store file containing the information about
  the method
@param [String] store_type the type of store (as contained in a {RIEntry})
@return [String] the HTML code of the page. If an error occurs, the page will
  describe it
=end
      def format_method method, store, store_type
        cmd = [ruby, File.join(File.dirname(__FILE__), 'method_formatter.rb'), method, store, store_type.to_s]
        html = nil
        err = nil
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          html = stdout.read
          err = stderr.read
          status = thr.value
        end
        if status.success? then html
        else
          error_msg "An error occurred while looking #{method} up in the <code>RI</code> database:", err
        end
      end

    end

=begin rdoc
The tool widget for the RI plugin

It contains a line edit for entering the text to look up with RI, back and
forward buttons and a @Qt::TextBrowser@ to display pages from @RI@.
=end
    class ToolWidget < Qt::Widget

=begin rdoc
Class to manage history

This class stores history items in an array, with the most recent items in the
last position. An index keeps track of the current item (the index counts from
-1 and all items have negative indexes, with -1 being the most recent item).

Entries are added with the {#<<} method. Currently there's no way to remove an
element
=end
      class History

        def initialize
          @entries = []
          @current = -1
        end

=begin rdoc
@return [Object,nil] the current element or @nil@ if the history is empty
=end
        def current
          @entries[@current]
        end

=begin rdoc
@return [Integer] the index corresponding to the position of the current entry
  in the history

  The index starts from -1 for the last entry and decreases for older ones.

@note You should avoid using this method, as the way indexing history works should
  be an internal detail
=end
        def current_index
          @current
        end

=begin rdoc
Whether or not there are entries in the history
@return [Boolean] @true@ if there are no elements in the history and @false@
  otherwise
=end
        def empty?
          @entries.empty?
        end

=begin rdoc
Whehter the current element is also the most recent

@return [Boolean] @true@ whether the current element is also the last (the most
  recent) and @false@ otherwise
=end
        def at_end?
          @current == -1
        end

=begin rdoc
Whehter the current element is also the least recent

@return [Boolean] @true@ whether the current element is also the first (the least
  recent) and @false@ otherwise
=end
        def at_beginning?
          @entries.empty? || @current == -@entries.count
        end

=begin rdoc
Adds an entry at the end of the history

If the current entry is the most recent, the new entry will simply be added at
the end of the history and will become the new current one.

If the current entry is not the most recent, all entries more recent than the
current one will be removed, the new one will be added at the end of the history
and become the current one.

@param [Object] entry the new entry
@return [History] self
=end
        def << entry
          if at_end? then @entries << entry
          else
            start = @current + 1
            @entries.slice! start, start.abs
            @entries << entry
            @current = -1
          end
          self
        end

=begin rdoc
The entry at a given index

@param [Integer] idx the index of the object. The index goes from -1 for the most
  recent item and decreases for less recent items
@return [Object, nil] the entry at position or @nil@ if no such entry exists
@note You should avoid using this method, as the way indexing history works should
  be an internal detail
=end
        def entry idx
          @entries[idx]
        end
        alias_method :[], :entry

=begin rdoc
A list of all the entries less recent than the current one

@return [<Object>] a list of all the entries less recent than the current one,
  sorted from the less recent to the most recent
=end
        def previous_entries
          @entries[-@entries.count, (-@entries.count - @current).abs] || []
        end

=begin rdoc
A list of all the entries more recent than the current one

@return [<Object>] a list of all the entries more recent than the current one,
  sorted from the less recent to the most recent
=end
        def following_entries
          @entries[@current + 1, -1 - @current] || []
        end

=begin rdoc
Moves history back

The current item becomes the one _n_ steps less recent than the current one
the new current element. If there are less than _n_ steps until the beginning of
history, history is moved to the beginning.

@param [Integer] n the number of steps to go back in history
@return [Integer, nil] the index of the new current element or @nil@ if the
  history was already at the beginning
=end
        def move_back n = 1
          @current = [@current - n, -@entries.count].max unless at_beginning?
        end

=begin rdoc
Moves history forward

The current item becomes the one _n_ steps more recent than the current one
the new current element. If there are less than _n_ steps to the end of history,
history is moved to the end.

@param [Integer] n the number of steps to go forward in history
@return [Integer, nil] the index of the new current element or @nil@ if the
  history was already at the end
=end
        def move_forward n = 1
          @current = [@current + n, -1].min unless at_end?
        end

      end

=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ruber::Ui::RIToolWidget.new
        @ui.setup_ui self
        @history = History.new
        @ui.content.open_links = false
        connect @ui.search_term, SIGNAL(:returnPressed), @ui.search, SIGNAL(:clicked)
        @ui.search.connect(SIGNAL(:clicked)){search}
        @ui.content.connect(SIGNAL('anchorClicked(QUrl)')){|u| display_url u }
        @ui.prev_btn.icon = KDE::IconLoader.load_icon 'go-previous'
        @ui.prev_btn.popup_mode = Qt::ToolButton::MenuButtonPopup
        @ui.prev_btn.connect(SIGNAL(:clicked)){go_back}
        @ui.next_btn.icon = KDE::IconLoader.load_icon 'go-next'
        @ui.next_btn.popup_mode = Qt::ToolButton::MenuButtonPopup
        @ui.next_btn.connect(SIGNAL(:clicked)){go_forward}
        @history_menus = {:back => Qt::Menu.new(self), :next => Qt::Menu.new(self)}
        @ui.prev_btn.menu = @history_menus[:back]
        @ui.next_btn.menu = @history_menus[:next]
        @history_menus[:back].connect(SIGNAL('triggered(QAction*)')){|a| back_action_triggered a}
        @history_menus[:next].connect(SIGNAL('triggered(QAction*)')){|a| next_action_triggered a}
        @history_menus[:back].connect(SIGNAL(:aboutToShow)){update_back_menu}
        @history_menus[:next].connect(SIGNAL(:aboutToShow)){update_next_menu}
        update_history_btns
      end

=begin rdoc
Ensures that whenever the widget gets focus, the focus is given to the input
widget

@param [Qt::FocusReason] reason the reason the widget got focus for
@return [void]
=end
      def set_focus reason = Qt::OtherFocusReason
        super
        @ui.search_term.set_focus
      end

      private

=begin rdoc
Searches the @RI@ database for the contents of the line edit, then displays the
results

This method uses {Plugin#search} to search the @RI@ database and {Plugin#format_result}
to get the HTML page to display.

@return [void]
=end
      def search
        text = @ui.search_term.text
        return if text.empty?
        result = Ruber[:ruberri].search text
        @ui.content.text = Ruber[:ruberri].format_result result
        @history << result
        update_history_btns
      end

=begin rdoc
Displays the @RI@ entry associated with the given URL

This method assumes that the URL has a format like that produced by
{Plugin#url_for_entry}.

@param [Qt::Url] url an URL like that produced by {Plugin#url_for_entry}
@return [void]
=end
      def display_url url
        entry = Ruber[:ruberri].entry_for_url url
        result = SearchResult.new entry.name, true, [entry]
        @ui.content.text = Ruber[:ruberri].format_entry entry
        @history << result
        update_history_btns
      end

=begin rdoc
Displays the entry _n_ steps back in history

@param (see History#move_back)
@return [void]
=end
      def go_back n = 1
        if @history.move_back n
          @ui.content.text = Ruber[:ruberri].format_result @history.current
          update_history_btns
        end
      end

=begin rdoc
Displays the entry _n_ steps forward in history

@param (see History#move_forward)
@return [void]
=end
      def go_forward n = 1
        if @history.move_forward n
          @ui.content.text = Ruber[:ruberri].format_result @history.current
          update_history_btns
        end
      end

=begin rdoc
Updates the enabled/disabled status of the back and forward buttons

This method ensures that the back button is disabled when at the beginning of
history and the forward button is disabled when at the end of history.

@return [void]
=end
      def update_history_btns
        @ui.prev_btn.enabled = !@history.at_beginning?
        @ui.next_btn.enabled = !@history.at_end?
      end

=begin rdoc
Adds actions corresponding to history entries less recent than the current one
  to the menu associated with the back button
@return [void]
=end
      def update_back_menu
        update_history_menus @history_menus[:back], @history.previous_entries.reverse
      end

=begin rdoc
Adds actions corresponding to history entries more recent than the current one
  to the menu associated with the forward button
@return [void]
=end
      def update_next_menu
        update_history_menus @history_menus[:next], @history.following_entries
      end

=begin rdoc
Adds action corresponding to a list of entries to the back or to the forward menu

The menu is cleared, all its actions are deleted, then the new actions are added.
To each action is associated the index in the list of entries using its @set_data@
method. This integer corresponds to the number of steps - 1 to move from the current
entry to the one corresponding to the action.

@param [Qt::Menu] menu the menu to add the actions to
@param [<SearchResult>] entries the entries corresponding to the actions to add
@return [void]
=end
      def update_history_menus menu, entries
        rri = Ruber[:ruberri]
        old = menu.find_children Qt::Action
        menu.clear
        old.each{|a| a.delete_later}
        entries.each_with_index do |e, i|
          name = e.entries.count == 1 ? e.entries[0].name : e.query + '(Disambiguation)'
          a = menu.add_action name
          a.data = Qt::Variant.new i
        end
      end

=begin rdoc
Slot called when one of the actions in the back menu is triggered

Moves the history to the entry corresponding to the action.
@return [void]
=end
      def back_action_triggered a
        go_back a.data.to_i + 1
      end

=begin rdoc
Slot called when one of the actions in the forward menu is triggered

Moves the history to the entry corresponding to the action.
@return [void]
=end     
      def next_action_triggered a
        go_forward a.data.to_i + 1
      end

    end

  end

end
