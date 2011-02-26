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

require 'pathname'

require 'ruber/gui_states_handler'

module Ruber
  
  
=begin rdoc
Widget meant to be used as tool widget to display the output of a program. It is
based on Qt Model/View classes and provides the following facitlities:
* an easy way to display in different colors items with different meaning (for
  example, error message are displayed in a different color from output messages)
* a centralized way in which the user can choose the colors for different types
  of items
* a context menu with some standard actions, which can be enhanced with custom
  ones and is automatically (under certain conditions) shown to the user
* autoscrolling (which means that whenever new text is added, the view scrolls so
  that the text becomes visible)
* a centralized way for the user to turn on and off word wrapping (which can be
  ignored by widgets for which it doesn't make sense)
* a mechanism which allows the user to click on an entry containing a file name
  in the widget to open the file in the editor. The mechanism can be customized
  by plugins to be better tailored to their needs (and can also be turned off)
* a model class, derived from <tt>Qt::StandardItemModel</tt>, which provides a
  couple of convenience methods to make text insertion even easier.

Note that OutputWidget is not (and doesn't derive from) one of the View classes.
Rather, it's a normal @Qt::Widget@ which has the view as its only child.
You can add other widgets to the OutputWidget as you would with any other widget:
create the widget with the OutputWidget as parent and add it to the OutputWidget's
layout (which is a @Qt::GridLayout@ where the view is at position 0,0).
  
*Note:* this class defines two new roles (@OutputTypeRole@ and @IsTitleRole@),
which correspond to @Qt::UserRole@ and @Qt::UserRole+1@. Therefore,
if you need to define other custom roles, please have them start from
@Ruber::OutputWidget::IsTitleRole+1@.
  
h3. Output types

The @output_type@ of an entry in the model can be set using the {#set_output_type}
method. This has two effects: first, the item will be displayed using the color
chosen by the user for that output type; second, the name of the output type will
be stored in that item under the custom role @OutputTypeRole@.
  
There are several predefined output types: @message@, @message_good@,
@message_bad@, @output@,
@output1@, @output2@, @warning@, @warning1@, @warning2@, @error@, @error1@ and @error2@.
The types ending with a number
can be used when you need different types with similar meaning.
  
The @message@ type
(and its variations) are meant to display messages which don't come from the external
program but from Ruber itself (for example, a message telling that the external
problem exited successfully or exited with an error). Its good and bad version are
meant to display messages with good news and bad news respectively (for example:
"the program exited successfully" could be displayed using the @message_good@
type, while "the program crashed" could be displayed using the @message_bad@
type).
  
The @output@ type is meant
to be used to show the text written by the external program on standard output,
while the @error@ type is used to display the text written on standard error. If
you can distinguish between warning and errors, you can use the @warning@ type
for the latter.

The colors for the default output types are chosen by the user from the configuration
dialog and are used whenever those output types are requested.

New output types (and their associated colors) can be make known to the output
widget by using the @set_color_for@ method. There's no need to remove the
color, for example when the plugin is unloaded (indeed, there's no way to do so).

h3. The context menu

This widget automatically creates a context menu containing three actions: Copy,
Copy Selected and Clear. Copy and Copy Selected copy the text contained respectively
in all the items and in the selected items to the clipboard. The clear action 
removes all the entries from the model.

You can add other actions to the menu by performing the following steps:
* add an entry in the appropriate position of {#action_list}. Note
  that this is an instance of ActionList, so it provides the {ActionList#insert_after insert_after}
  and {ActionList#insert_before insert_before} methods which allow to easily put the actions in the
  correct place. {#action_list} contains the @object_name@ of
  the actions (and *nil* for the separators), not the action themselves
* create the actions (setting their @object_name@ to the values inserted
  in {#action_list}) and put them into the {#actions} hash, using the @object_name@
  as keys. Of course, you also need to define the appropriate slots and connect
  them to the actions' signals.
  
Note that actions can only be added _before_ the menu is first shown (usually, you
do that in the widget's constructor). The {#about_to_fill_menu} signal is
emitted just before the menu is built: this is the last time you can add entries
to it.

{OutputWidget} mixes in the {GuiStatesHandler} module, which means you can define states
to enable and disable actions as usual. By default, two states are defined: @no_text@
and @no_selection@. As the names imply, the former is *true* when the model
is empty and *false* when there's at least one item; the second is *true* when no
item is selected and *false* when there are selected items.

For the menu to be displayed automatically, the view should have a @context_menu_requested(QPoint)@
signal. The menu will be displayed in response to that signal, at the point given
as argument. For convenience, there are three classes {OutputWidget::ListView},
{OutputWidget::TreeView} and {OutputWidget::TableView}, derived 
respectively from @Qt::ListView@, @Qt::TreeView@ and @Qt::TableView@
which emit that signal from their @contextMenuEvent@ method. If you use
one of these classes as view, the menu will work automatically.

h3. Autoscrolling

Whenever an item is added to the list, the view will be scrolled so that the added
item is visible. Plugins which don't want this feature can disable it by setting
{#auto_scroll} to *false*. Note that auto scrolling won't happen if an item
is modified or removed

h3. Word wrapping

If the user has enabled word wrapping for output widgets in the config dialog 
(the @general/wrap_output@ option), word wrapping will be automatically enabled for
all output widgets. If the user has disabled it, it will be disabled for all
widgets.

Subclasses can avoid the automatic behaviour by setting the {#ignore_word_wrap_option}
attribute to *true* and managing word wrap by themselves. This is mostly useful
for output widgets for which word wrap is undesirable or meaningless.

h3. Opening files in the editor

Whenever the user activates an item, the text of the item is searched for a filename
(and optionally for a line number). If it's found, a new editor view is opened
and the file is displayed in it. The editor can be an already existing editor
or a new one created by splitting the current editor or in a new tab, according to
the @general/tool_open_files@ option.

This process uses four methods:

- {#maybe_open_file}:=
  the method connected to the view's @activated(QModelIndex)@ signal. It
  starts the search for the filename and, if successful, opens the editor view =:
- {#find_filename_in_index}:=
  performs the search of the filename. By default, it uses {#find_filename_in_string},
  but subclasses can override it to change the behaviour=:
- {#find_filename_in_string}:=
  the method used by default by {#find_filename_in_index} to find the
  filename.=:
- {#display_file}:= opens the file in an editor. By default uses the @general/tool_open_files@
  to decide how the editor should be created, but this behaviour can be overridden
  by subclasses.
  
If a relative filename is found, it's considered relative to the directory contained
in the {#working_dir} attribute.

h3. {OutputWidget::Model}

The {OutputWidget::Model} class behaves as a standard @Qt::StandardItemModel@, but
provides two methods, {OutputWidget::Model#insert insert} and
{OutputWidget::Model#insert_lines insert_lines} which make easier adding items. You
aren't forced to use this model, however: if you want to use another class,
pass it to the constructor.
=end
  class OutputWidget < Qt::Widget
    
    include GuiStatesHandler

=begin rdoc
Signal emitted immediately before the menu is created
    
You should connect to this
signal if you want to add actions to the menu at the last possible time. Usually,
however, you don't need it, as actions are usually created in the constructor.
=end
    signals :about_to_fill_menu
    
    slots 'show_menu(QPoint)', 'selection_changed(QItemSelection, QItemSelection)',
        :rows_changed, 'do_auto_scroll(QModelIndex, int, int)', :copy, :copy_selected,
        :clear_output, 'maybe_open_file(QModelIndex)', :load_settings
    
=begin rdoc
The role which contains a string with the output type of the index
=end
    OutputTypeRole = Qt::UserRole
    
=begin rdoc
The role which contains whether an item is or not the title
=end
    IsTitleRole = OutputTypeRole + 1
    
=begin rdoc
@return [Boolean ] whether auto scrolling should be enabled or not (default: *true*)
=end
    attr_accessor :auto_scroll
        
=begin rdoc
@return [Boolean] whether or not word wrapping should respect the @general/wrap_output@ option (default: *false*)
=end
     attr_accessor :ignore_word_wrap_option

=begin rdoc
@return [String] the directory used to resolve relative paths when opening a file (default *nil*)
=end
    attr_accessor :working_dir
    alias :working_directory :working_dir
    alias :working_directory= :working_dir=
    
=begin rdoc
@return [Boolean] whether or not to {#find_filename_in_index} should skip the first
  file name in the title
=end
    attr_accessor :skip_first_file_in_title
       
=begin rdoc
@return [ActionList] the names of the action to use to build the menu
    
    Separators are represented by *nil* entries. The default is
    @['copy', 'copy_selected', nil, 'clear']@.
=end
    attr_reader :action_list
    
=begin rdoc
@return [Hash{String => KDE::Action}] the actions to insert in the menu

  Each action is inserted using its @object_name@ as key. By default, the hash
  contains the 'copy', 'copy_selected' and 'clear' actions.
=end
    attr_reader :actions
    
=begin rdoc
@return [Qt::AbstractItemModel] the model used by the {OutputWidget}
=end
    attr_reader :model
    
=begin rdoc
@return [Qt::AbstractItemView] the view used by the OutputWidget
=end
    attr_reader :view
    
    private :action_list, :actions
    
=begin rdoc
@param [Qt::Widget,nil] the parent widget
@param [Hash] opts fine-tune the new widget
@option opts [Qt::AbstractItemView, Symbol] :view (:list) the view to use for
  the widget. If it is an instance of a subclass of @Qt::AbstractItemView@, it'll
  be used as it is (and the new widget will become a child of the output widget).
  If it is a symbol, it can be either @:list@, @:tree@ or @:table@. In this case,
  a new instance respectively of {ListView}, {TreeView} or {TableView} will be
  created
@option opts [Qt::AbstractItemModel,nil] :model (nil) the model the output widget
  should use. If *nil*, a new instance of {Model} will be used
@option opts [Boolean] :use_default_font (false) whether or not the application's
  default font should by used for the output widget. By default, the font used
  is the one the user set in the @general/output_font@ option
=end
    def initialize parent = nil, opts = {}

      @ignore_word_wrap_option = false
      @working_dir = nil
      @skip_first_file_in_title = true
      @use_default_font = opts[:use_default_font]
      
      super parent
      initialize_states_handler
      create_widgets(opts[:view] || :list)
      setup_model opts[:model]
      connect @view.selection_model, SIGNAL('selectionChanged(QItemSelection, QItemSelection)'), self, SLOT('selection_changed(QItemSelection, QItemSelection)')
      connect @view, SIGNAL('activated(QModelIndex)'), self, SLOT('maybe_open_file(QModelIndex)')
      @auto_scroll = true
      
      @colors = {}
      @action_list = ActionList.new 
      @action_list << 'copy' << 'copy_selected' << nil << 'clear'
      @actions = {}
      
      connect @view, SIGNAL('context_menu_requested(QPoint)'), self, SLOT('show_menu(QPoint)')
      
      @menu = Qt::Menu.new self
      
      create_standard_actions
      change_state 'no_text', true
      change_state 'no_selection', true
    end
    
=begin rdoc
Associates a color with an output type

If a color had already been associated with the given output type, it'll be overwritten.

This method is useful to define new output types.
@param [Symbol] name the name of the output type
@param [Qt::Color] color the color to associate with the given output type
@return [nil]
=end
    def set_color_for name, color
      @colors[name] = color
      nil
    end
    
=begin rdoc
Scrolls the view so that the item corresponding the given index is visible

@param [Qt::ModelIndex,Integer,nil] idx the item to make visible. If it's a
  @Qt::ModelIndex@, it's the index to make visible. If it is a positive integer.
  the view will be scrolled so that the first toplevel item in the row _idx_ is
  visible; if it's a negative integer, the rows are counted from the end. If *nil*
  the first toplevel item of the last row will become visible
@return [nil]
=end
    def scroll_to idx
      case idx
      when Numeric
        rc = @model.row_count
        if idx >= rc then idx = rc -1
        elsif idx < 0 and idx.abs < rc then idx = rc + idx
        elsif idx < 0 then idx = 0
        end
        mod_idx = @model.index idx, 0
        @view.scroll_to mod_idx, Qt::AbstractItemView::PositionAtBottom
      when Qt::ModelIndex
        idx = @model.index(@model.row_count - 1, 0) unless idx.valid?
        @view.scroll_to idx, Qt::AbstractItemView::PositionAtBottom
      when nil
        @view.scroll_to @model.index(@model.row_count - 1, 0), 
            Qt::AbstractItemView::PositionAtBottom
      end
      nil
    end
    
=begin rdoc
Changes the output type of a given index

If a color has been associated with that output type, the foreground role and the
output type role of that index are updated accordingly.

If no color has been associated with the output type, nothing is done
@param [Qt::ModelIndex] idx the index to set the output type for
@param [Symbol] type the new output type to associate with the index
@return [Symbol,nil] _type_ if a color was associated with it and *nil* otherwise
=end
    def set_output_type idx, type
      color = @colors[type]
      if color
        @model.set_data idx, Qt::Variant.from_value(color), Qt::ForegroundRole
        @model.set_data idx, Qt::Variant.new(type.to_s), OutputTypeRole
        type
      end
    end
    
=begin rdoc
Executes a block while temporarily turning autoscrolling on or off

After the block has been executed, autoscrolling returns to the original state.

@param [Boolean] val whether to turn autoscrolling on or off
@yield the block to execute with autoscroll turned on or off
@return [Object] the value returned by the block
=end
    def with_auto_scrolling val
      old = @auto_scroll
      @auto_scroll = val
      begin yield
      ensure @auto_scroll = old
      end
    end
    
=begin rdoc
Gives a title to the widget.
    
A title is a toplevel entry at position 0, 0 with output type @:message@ and has 
the @IsTitleRole@ set to *true*. Of course, there can be only one item which is
a title.

If the item in position 0, 0 is not a title, a new row with title role and the
given text is inserted.

If the item in position 0,0 is a title, then its display role is replaced with 
the given text.

Usually, the title is created when the external program is started and changed
later if needed.

@param [String] text the text of title
@return [nil]
=end
    def title= text
      idx = @model.index 0, 0
      if idx.data(IsTitleRole).to_bool
        @model.set_data idx, Qt::Variant.new(text)
      else
        @model.insert_column 0 if @model.column_count == 0
        @model.insert_row 0
        idx = @model.index 0, 0
        @model.set_data idx, Qt::Variant.new(text)
        @model.set_data idx, Qt::Variant.new(true), IsTitleRole
      end
      set_output_type idx, :message
      nil
    end
    
=begin rdoc
Whether or not the output widget has a title

See {#title=} for what is meant here by title
@return [Boolean] whether or not the output widget has a title
=end
    def has_title?
      @model.index(0,0).data(IsTitleRole).to_bool
    end
    
=begin rdoc
Loads the settings from the configuration file.

@return [nil]
=end
    def load_settings
      cfg = Ruber[:config]
      colors = [:message, :message_good, :message_bad, :output, :output1, :output2, :error, :error1, :error2, :warning, :warning1, :warning2]
      colors.each{|c| set_color_for c, cfg[:output_colors, c]}
      @model.row_count.times do |r|
        @model.column_count.times do |c|
          update_index_color @model.index(r, c)
        end
      end
      @view.font = cfg[:general, :output_font] unless @use_default_font
      unless @ignore_word_wrap_option
        # Not all the views support word wrapping
        begin @view.word_wrap = cfg[:general, :wrap_output] 
        rescue NoMethodError
        end
      end
      nil
    end
    
=begin rdoc
Removes all the entries from the model

@return [nil]
=end
    def clear_output
      @model.remove_rows 0, @model.row_count
      nil
    end
    
    def pinned_down?
      @pin_button.checked?
    end

    private
    
=begin rdoc
Updates the color of an index and its children so that it matches their output types
@param [Qt::ModelIndex] idx the index whose foreground color should be updated.
  Its children will also be updated
@return [nil]
=end
    def update_index_color idx
      type = idx.data(OutputTypeRole).to_string.to_sym rescue nil
      color = @colors[type]
      if color
        @model.set_data idx, Qt::Variant.from_value(color), Qt::ForegroundRole
      end
      if @model.has_children idx
        @model.row_count(idx).times do |r|
          @model.column_count(idx).times do |c|
            update_index_color idx.child(r, c)
          end
        end
      end
      nil
    end
    
=begin rdoc
Prepares the model to use

After a call to this method, the model will become a child of the {OutputWidget}

@param [Qt::AbstractItemModel,nil] mod the model to use. If *nil*, a new instance
  of {Model} will be used
@return [nil]
=end
    def setup_model mod
      @model = mod || Model.new(self)
      @model.insert_column 0 if @model.column_count < 1
      @model.parent = @view
      @view.model = @model
      connect @model, SIGNAL('rowsInserted(QModelIndex, int, int)'), self, SLOT(:rows_changed)
      connect @model, SIGNAL('rowsRemoved(QModelIndex, int, int)'), self, SLOT(:rows_changed)
      connect @model, SIGNAL('rowsInserted(QModelIndex, int, int)'), self, SLOT('do_auto_scroll(QModelIndex, int, int)')
      nil
    end
    
=begin rdoc
Slot called whenever rows are inserted in the model

If autoscrolling is enabled, it scrolls so that the last row inserted is at the
bottom of the widget. It does nothing if autoscrolling is disabled.

If the scrollbar slider is not at the bottom of the scroll bar, autoscrolling
isn't done, regardless of the option. This is because it's likely that the user
moved the slider, which may mean he's looking at some particular lines of output
and he wouldn't like them to scroll away.

@param [Qt::ModelIndex] parent the parent index of the inserted rows
@param [Qt::ModelIndex] start_idx the index corresponding to the first inserted
  row (unused)
@param [Qt::ModelIndex] end_idx the index correspodnding to the last inserted row

@note all indexes are considered relative to the model associated with the view,
  not to the model returned by {#model}. This doesn' matter for {OutputWidget} itself,
  but makes a difference in sublclasses where the two models are different (for
  example, {FilteredOutputWidget})
@return [nil]
=end
    def do_auto_scroll parent, start_idx, end_idx
      if @auto_scroll
        scroll_bar = @view.vertical_scroll_bar
        scroll_to @view.model.index(end_idx, 0, parent) if scroll_bar.value == scroll_bar.maximum
      end
      nil
    end

=begin rdoc
Creates the context menu

The menu is created using the values returned by {#action_list} and {#actions}.

Before creating the menu, the {#about_to_fill_menu} signal is emitted. Connecting
to this signal allows to do some last-minute changes to the actions which will
be inserted in the menu.
@return [nil]
=end
    def fill_menu
      emit about_to_fill_menu
      @action_list.each do |a|
        if a then @menu.add_action @actions[a]
        else @menu.add_separator
        end
      end
    end
    
=begin rdoc
Shows the menu

If the menu hasn't as yet been created, it creates it.

The menu is shown asynchronously. This means that this method doesn't wait for
the user to choose an action but returns immediately.

@param [Qt::Point] the point where the menu should be shown
@return [ni;]
=end
    def show_menu pt
      fill_menu if @menu.empty?
      @menu.popup pt
      nil
    end
    
=begin rdoc
Creates the layout and the view

@param [AbstractItemView,Symbol] view the view to use. Has the same meaning as the
  @:view@ option to {#initialize}
@return [nil]
=end
    def create_widgets view
      self.layout = Qt::GridLayout.new(self)
      if view.is_a?(Qt::Widget)
        @view = view
        @view.parent = self
      else @view = self.class.const_get(view.to_s.capitalize + 'View').new self
      end
      @view.selection_mode = Qt::AbstractItemView::ExtendedSelection
      @pin_button = Qt::ToolButton.new self
      @pin_button.tool_tip = i18n("Don't hide the tool widget when clicking on a file name")
      @pin_button.auto_raise = true
      @pin_button.icon = Qt::Icon.new KDE::Global.dirs.find_resource('icon', 'pin.png')
      @pin_button.checkable = true
      layout.add_widget @view, 1, 0
      layout.add_widget @pin_button, 0, 0, 1, -1, Qt::AlignRight | Qt::AlignVCenter
      nil
    end
    
=begin rdoc
Creates the default actions for the context menu

It also sets up the gui state handlers for them
@return [nil]
=end
    def create_standard_actions
      @actions['copy'] = KDE::Action.new(self){|a| a.text = '&Copy'}
      @actions['copy_selected'] = KDE::Action.new(self){|a| a.text = '&Copy Selection'}
      @actions['clear'] = KDE::Action.new(self){|a| a.text = 'C&lear'}
      register_action_handler @actions['copy'], '!no_text'
      register_action_handler @actions['copy_selected'], ['no_text', 'no_selection'] do |s|
        !(s['no_text'] || s['no_selection'])
      end
      register_action_handler  @actions['clear'], '!no_text'
      connect @actions['copy'], SIGNAL(:triggered), self, SLOT(:copy)
      connect @actions['copy_selected'], SIGNAL(:triggered), self, SLOT(:copy_selected)
      connect @actions['clear'], SIGNAL(:triggered), self, SLOT(:clear_output)
      nil
    end
    
=begin rdoc
Slot connected to the 'Copy' action.

It copies the content of all the items to the clipboard. The text is obtained
from the items by calling {#text_for_clipboard}.
@return [nil]
=end
    def copy
      items = []
      stack = []
      @model.row_count.times do |r|
        @model.column_count.times{|c| stack << @model.index(r, c)}
      end
      until stack.empty?
        it =  stack.shift
        items << it
        (@model.row_count(it)-1).downto(0) do |r|
          (@model.column_count(it)-1).downto(0){|c| stack.unshift it.child(r, c)}
        end
      end
      clp = KDE::Application.clipboard
      clp.text = text_for_clipboard items
      nil
    end

=begin rdoc
Slot connected to the 'Copy Selection' action.

It copies the content of all the items to the clipboard. The text is obtained
from the items by calling {#text_for_clipboard}.
@return [nil]
=end
    def copy_selected
      clp = KDE::Application.clipboard
      clp.text = text_for_clipboard @view.selection_model.selected_indexes
    end
    
=begin rdoc
Retrieves the text to copy to the clipboard from the given indexes

The string is created by joining the text of toplevel items on the same row and
different columns using tabs as separators. Different rows are separated with
newlines. Child items are ignored.

Derived class can override this method (and, if they plan to put child items in
the view, they're advised to do so).

The reason the default behaviour ignores child items is that their meaning (and
therefore the way their contents should be inserted into the string) depends
very much on the specific content, so there's no way to have a sensible default
behaviour.

@param [Array<Qt::ModelIndex>] indexes the indexes to use to create the text
@return [String] the text which should be put in the clipboard
=end
    def text_for_clipboard indexes
      indexes = indexes.select{|i| !i.parent.valid?}
      rows = indexes.group_by{|idx| idx.row}
      rows = rows.sort
      text = rows.inject("") do |res, r|
        idxs = r[1].sort_by{|i| i.column}
        idxs.each{|i| res << i.data.to_string << "\t"}
        # The above line gives \t as last character, while a \n is needed
        res[-1] = "\n"
        res
      end
      # The above block leaves a \n at the end of the string which shouldn't be
      # there
      text[0..-2]
    end
        
=begin rdoc
Slot connected to the view's selection model's @selectionChanged@ signal

Turns the @no_selection@ gui state on or off according to whether the selection
is empty or not.

@return [nil]
=end
    def selection_changed sel, desel
      change_state 'no_selection', !@view.selection_model.has_selection
      nil
    end
    
=begin rdoc
Slot called whenever rows are added to or removed from the model

Turns the @no_text@ gui state on or off depending on whether the model
is empty or not
@return [nil]
=end
    def rows_changed
      change_state 'no_text', @model.row_count == 0
      nil
    end
    
=begin rdoc
Attempts to display the file whose name is contained in the given index

Searches for a filename in the DisplayRole of the index using the {#find_filename_in_index}
method. If a filename is found, an editor for it is displayed.

The behaviour of this method (which usually is only called via a signal-slot connection
to the views' @activated(QModelindex)@ signal) changes according to the active 
keyboard modifiers and to whether the Pinned tool button is on or off:
* if Ctrl or Shift are pressed and the view allows selection (that is, its selection
mode is not +NoSelection+), then this method does nothing. The reason for this
behaviour is that Ctrl and Shift are used to select items, so the user is most
likely doing that, not requesting to open a file
* if the Pinned button is pressed, then the tool widget won't be closed (but the
  focus will be moved to the editor)
* if Meta is pressed, then the file will be opened in a new editor, regardless
  of whether an editor for that file already exists

If a new editor should be created (either because the Meta key is pressed or because
no editor exists for the given file), the hints returned by {#hints} are used.
Unless the {#hints} method has been overloaded, this means that the @general/tool_open_files@
option is used.
@param [Qt::ModelIndex] idx the index which could contain the file name
@return [EditorView,nil] the editor for the filename contained in the index or
  *nil* if no file name was found or if either the Shift or Control modifiers were
  active
@see #find_filename_in_index
@see #hints
=end
    def maybe_open_file idx
      modifiers = Application.keyboard_modifiers
      if @view.selection_mode != Qt::AbstractItemView::NoSelection
        return if Qt::ControlModifier & modifiers != 0 or Qt::ShiftModifier & modifiers != 0
      end
      file, line = find_filename_in_index idx
      return unless file
      line -= 1 unless line == 0
      existing = (Qt::MetaModifier & modifiers) == 0 ? :always : :never
      display_hints = hints.merge(:line =>  line, :existing => existing)
      ed = Ruber[:main_window].display_document file, display_hints
      Ruber[:main_window].hide_tool self unless pinned_down?
      ed
    end
    
=begin rdoc
The hints to pass to {MainWindow#display_document}

This method determines the hints to use according to the @general/tool_open_files@
option. Derived classes may override this method to provide different hints. The
values which can be used are the ones described for {MainWindow#editor_for!}. Note,
however, that the @:existing@ entry won't be used.
@return [Hash] see the description for the _hints_ argument of {MainWindow#editor_for!}
=end
    def hints
      case Ruber[:config][:general, :tool_open_files]
      when :split_horizontally then {:new => :current_tab, :split => :horizontal}
      when :split_vertically then {:new => :current_tab, :split => :vertical}
      else {:new => :new_tab}
      end
    end
    
=begin rdoc
Searches in the display role of the given index for a file name

This method is used by {#maybe_open_file} to find out the name of the file to open
(if any) when an item is activated.

The actual search for the file name is done by {#find_filename_in_string}. If it
reports a success, this method makes sure the file actually exists, expanding it
relative to {#working_dir} if it's not an absolute path. If {#working_dir} is
not set, the current directory will be used. However, you're advised not to relay
on this behaviour and always set the working directory.

If the given index is the title of the widget (see {#title=}) and {#skip_first_file_in_title}
is *true*, all the text from the beginning of the title up to the first whitespace
or colon is ignored. Since often the first word of the title is the name of the
program being run (which may as well be compiled), it doesn't make sense to attempt
to open it. This behaviour allows the user to activate on a title like
@/usr/bin/ruby /path/to/script.rb@ and see the file @/path/to/script.rb@ in the
editor. Without it, @/usr/bin/ruby@ would be opened instead.

Subclasses can override this method to extend or change its functionality. They
have two choices on how to do this. The simplest is useful if they want to alter
the string. In this case they can retrieve the text from the index, change it
then call *super* passing the modified string as argument. The other way is to
reimplement this method from scratch.

A subclass can also decide to completely disallow opening a file by activating the
corresponding item by overriding this method to always return *nil*.

@param [Qt::ModelIndex,String] idx the index or string to search a file name in.
  The form which takes a string is usually used by subclasses which want to alter
  the string without reimplementing all the functionality. Note that if _idx_
  is a string, there's no way to know whether it refers to the title or not, so
  {#skip_first_file_in_title} is ignored
@return [Array(String,Integer),nil] if a file name is found (and the corresponding
  file exists) an array containing the filename and the line number (or 0 if no
  line number was found). If no suitable file is found, *nil* is returned
=end
    def find_filename_in_index idx
      str = if idx.is_a?(String) then idx
      elsif @skip_first_file_in_title and idx.data(IsTitleRole).to_bool
          idx.data.to_string.sub(/^[^\s:]+/, '')
      else idx.data.to_string
      end
      res = find_filename_in_string str
      return unless res
      res = Array res
      res << 0 if res.size == 1
      #if res[0] is an url with scheme file:, transform it into a regular file
      #name by removing the scheme and the two following slash
      res[0].sub! %r{^file://}, ''
      if KDE::Url.file_url?(res[0]) then res
      else
        res[0] = File.join (@working_dir || Dir.pwd), res[0] unless Pathname.new(res[0]).absolute?
        if File.exist?(res[0]) and !File.directory?(res[0])
          res
        else nil
        end
      end
    end
    
=begin rdoc
Searches the given string for the first occurrence of a file name

The file name can optionally be followed by a colon and a line number.
    
What is a file name and what isn't is a bit arbitrary. Here's what this method
recognizes as a filename:
* an absolute path not containing spaces and colons starting with '/'
* an absolute path not containing spaces and colons starting with '~' or '~user'
  (they're expanded using @File.expand_path@)
* a relative path starting with @./@ or @../@ (either followed by a slash or not)
* a relative path of the form @.filename@ or @.dirname/dir/file@
* absolute URLs with an authority component
* any string not containing spaces or colons followed by a colon and a line number
  (in this case, the line number is required)

File names enclosed in quotes or parentheses are recognized.
@return [Array(String,Integer), Array(String),nil] an array whose first element
  is the file name and whose second element is the line number (if found) or
  *nil* if no file name was found. Note that the file name can be relative
=end
    def find_filename_in_string str
      #This ensures that file names inside quotes or brackets are found. It's
      #easier replacing quotes and brackets with spaces than to modify the main
      #regexp to take them into account
      str = str.gsub %r|['"`<>\(\)\[\]\{\}]|, ' '
      matches = []
      attempts = [
        %r{(?:^|\s)([\w+.-]+:/{1,2}(?:/[^/:\s]+)+)(?::(\d+))?(?:$|[,.;:\s])}, #URLS
        %r{(?:^|\s)((?:/[^/\s:]+)+)(?::(\d+))?(?:$|[,.;:\s])}, #absolute files
        #absolute files referring to user home directory: ~/xyz or ~user/xyz
        %r{(?:^|\s)(~[\w_-]*(?:/[^/\s:]+)+)(?::(\d+))?(?:$|[,.;:\s])},
        #relative files starting with ./ and ../
        %r{(?:^|\s)(\.{1,2}(?:/[^/\s:]+)+)(?::(\d+))?(?:$|[,.;:\s])},
        #hidden files or directories (.filename or .dir/filename)
        %r{(?:^|\s)(\.[^/\s:]+(?:/[^/\s:]+)*)(?::(\d+))?(?:$|[,.;:\s])},
        #relative files containing, but not ending with a slash
        %r{(?:^|\s)([^/\s:]+/[^\s:]*[^\s/:])(?::(\d+))?(?:$|[,.;:\s])},
        #relative files not containing slashes but ending with the line number
        %r{(?:^|\s)([^/\s:]+):(\d+)(?:$|[,.;:\s])}
      ]
      attempts.each do |a|
        m = str.match a
        matches << [m.begin(0),[$1,$2]] if m
      end
      match = matches.sort_by{|i| i[0]}[0]
      return unless match
      file, line = *match[1]
      file = File.expand_path(file) if file.start_with? '~'
      res = [file]
      res << line.to_i if line
      res
    end
    
=begin rdoc
Convenience class to use instead of <tt>Qt::StandardItem</tt> as model for OutputWidget.

It provides three methods which make easier to insert items in the widget: +insert+, 
<tt>insert_lines</tt> and +set+. Besides, it allows to set the item flags globally,
using the <tt>global_flags</tt> attribute.
=end
    class Model < Qt::StandardItemModel
      
=begin rdoc
The flags to use for all valid indexes (always converted to an integer). If this
is *nil*, then +flags+ will revert to <tt>Qt::StandardModel</tt> behaviour. The
default value is <tt>Qt::ItemIsEnabled|Qt::ItemIsSelectable</tt>
=end
      attr_reader :global_flags
      
=begin rdoc
Creates a new instance. _widget_ is the output widget which will use the model.
_parent_ is the parent object
=end
      def initialize widget, parent = nil
        super parent
        @output_widget = widget
        @global_flags = (Qt::ItemIsEnabled | Qt::ItemIsSelectable).to_i
      end

=begin rdoc
Sets the global flags to use. If _val_ is not *nil*, it will be converted to an
integer and will become the value the +flags+ method return for all valid indexes.
If _value_ is *nil*, +flags+ will behave as it does in <tt>Qt::StandardModel</tt>
=end
      def global_flags= val
        @global_flags = val.nil? ? nil : val.to_i
      end
      
=begin rdoc
Override of <tt>Qt::StandardModel#flags</tt>.

If the <tt>global_flags</tt> attribute is not *nil*, returns its value if _idx_
is valid and <tt>Qt::NoItemFlags</tt> if it isn't vaid.

If <tt>global_flags</tt> is *nil*, this method behaves as <tt>Qt::StandardModel#flags</tt>.
=end
#       def flags idx
#         super
#         if @global_flags
#           idx.valid? ? @global_flags : Qt::NoItemFlags
#         else super
#         end
#       end
      
=begin rdoc
Changes content of the given element. 

It creates a new Qt::StandardItem containing the text _text_, inserts it in the model,
sets the output type of the corresponding index to _type_ and changes its flags
to make it enabled and selectabled.

_row_ is an integer corresponding to the row where the item should be put. If _opts_
contains the +:col+ entry, it represents the colun of the new item (if this option
is missing, the column is 0). If _opts_ contains
the +:parent+ entry, it is the parent item (not index) of the new one. If _row_
and/or the +:col+ entry are negative, they're counted from backwards.

Note that, if an item with the given row, column and parent already exist, it is
replaced by the new item.

Returns the new item.
=end
      def set text, type, row, opts = {}
        col = opts[:col] || 0
        parent = opts[:parent]
        it = Qt::StandardItem.new(text)
        row = (parent || self).row_count + row if row < 0
        col = (parent || self).column_count + col if col < 0
        if parent then parent.set_child row, col, it
        else set_item row, col, it
        end
        @output_widget.set_output_type it.index, type
        it
      end
      
=begin rdoc
Inserts a new row in the model and sets the output type of its elements.

_opts_ can contain two keys: 
+:parent+:: the <tt>Qt::StandardItem</tt> the new row should be child of. If not
            given, the new row will be a top-level row
+:col+:: the column where to put the text (default: 0). It has effect only if
         _text_ is a string (see below)

_text_ represents the contents of the new row and can be either a string or an
array containing strings and <b>nil</b>s.
      
If _text_ is an array, each entry of the array will become a column in the new row.
with a text, while *nil* entries will produce empty items (that is items 
without text. Calling <tt>item.text</tt> on these items will give *nil*. The
associated indexes, however, are valid).
      
If _text_ is a string, the resulting row will have all the elements
from column 0 to the one before the +:col+ entry set to empty element (as described
above). The column +:col+ has text _text_. Of course, if +:col+ is 0 (or is missing)
no empty items are created.

_type_ is the output type to give to the items in the new row. It can be either
a symbol or an array of symbols. If it is a symbol, it will be the output type
of all elements in the new row. If it is an array, each entry will be the type
of the corresponding non-empty item (that is of the item in _text_ which has the
same index after removing all *nil* elements from _text_). If _type_ is longer
than the _text_ array, the entries in excess are ignored (if _text_ is a string,
it behaves as an array of size 1 in this regard). If _type_ is shorter than the
_text_ array, the entries in excess won't have their output type set.

_row_ is the index where the new row should be put. If *nil*, the new row will
be appended to the model.

If _row_ or +:col+ are negative, they're counted from the end. That is, the actual
row index if _row_ is negative is <tt>row_count+row</tt>. The same happens with
+:col+.

If _row_ is greater than <tt>row_count</tt> (or negative and its absolute value
is greater than <tt>row_count</tt>), +IndexError+ is raised. This is because
<tt>Qt::StandardItemModel</tt> doesn't allow for a row to be inserted after the
last one. This doesn't happen for the columns, which are added automatically.

This method returns an array containing all the non-empty items of the new row.
=end
      def insert text, type, row, opts = {}
        parent = opts[:parent] || self
        rc = parent.row_count
        row ||= rc
        row =  rc + row if row < 0
        col = opts[:col] || 0
        cc = parent.column_count
        col = cc + col if col < 0
        if row < 0 or row > rc 
          raise IndexError, "Row index #{row} is out of range. The allowed values are from 0 to #{rc}"
        end
        text = Array.new(col) << text unless text.is_a? Array
        items = text.map do |i| 
          it = i ? Qt::StandardItem.new(i) : Qt::StandardItem.new
          it.flags = @global_flags if @global_flags
          it
        end
        parent.insert_row row, items
        items.delete_if{|i| i.text.nil?}
        type = Array.new(items.size, type) unless type.is_a? Array
        items.each_with_index do |it, i|
          @output_widget.set_output_type it.index, type[i]
        end
        items
      end
      
=begin rdoc
Similar to +insert+, but inserts each line of _text_ in a different item, one
below the other, starting at the position given by the _row_ and _opts_ argument.

_row_ and _opts_ have the same meaning as in +insert+.

_text_ can be either a string or an array of strings. If it is a string, it will
be split into lines, while if it is an array, each entry of the array will be considered
a single line (even if it contains newlines). In both cases, a single string is
passed to +insert+ for each line.

_type_ is the output type to assign to each item and should be a symbol. The
same type is used for all lines.
=end
      def insert_lines text, type, row, opts = {}
        lines = text.is_a?(Array) ? text : text.split("\n")
        lines.each do |l|
          insert l, type, row, opts
          row += 1 if row
        end
      end
      
    end
    
=begin rdoc
Convenience class to be used instead of @Qt::ListView@ in an {OutputWidget}.

The only difference from @Qt::ListVew@ is that it defines a @context_menu_requested(QPoint)@
signal and emits it from its {#contextMenuEvent} method
=end
    class ListView < Qt::ListView
      
=begin rdoc
Signal emitted when the user right-clicks on the view
@param [Qt::Point] pt the point where the user clicked
=end
      signals 'context_menu_requested(QPoint)'
      
=begin rdoc
Override of @Qt::ListView#contextMenuEvent@

It emits the {#context_menu_requested} signal
=end
      def contextMenuEvent e
        super e
        emit context_menu_requested(e.global_pos)
      end
      
    end

=begin rdoc
Convenience class to be used instead of @Qt::TreeView@ in an {OutputWidget}.

The only difference from @Qt::TreeVew@ is that it defines a {#context_menu_requested}
signal and emits it from its {#contextMenuEvent} method
=end
    class TreeView < Qt::TreeView

=begin rdoc
Signal emitted when the user right-clicks on the view
@param [Qt::Point] pt the point where the user clicked
=end
      signals 'context_menu_requested(QPoint)'

=begin rdoc
Override of @Qt::TreeView#contextMenuEvent@

It emits the {#context_menu_requested} signal
=end
      def contextMenuEvent e
        super e
        emit context_menu_requested(e.global_pos)
      end
      
    end

=begin rdoc
Convenience class to be used instead of @Qt::TableView@ in an {OutputWidget}.

The only difference from @Qt::TableVew@ is that it defines a {#context_menu_requested}
signal and emits it from its {#contextMenuEvent} method
=end
    class TableView < Qt::TableView
    
=begin rdoc
Signal emitted when the user right-clicks on the view
@param [Qt::Point] pt the point where the user clicked
=end
      signals 'context_menu_requested(QPoint)'

=begin rdoc
Override of @Qt::TableView#contextMenuEvent@

It emits the {#context_menu_requested} signal
=end
      def contextMenuEvent e
        super e
        emit context_menu_requested(e.global_pos)
      end
      
    end
        
=begin rdoc
 Array of actions and separators (represented by nil) which allows to easily
 insert an entry before or after another one
=end
    class ActionList < Array

=begin rdoc
Inserts one or more actions before a given one

@param [String,Integer] entry the entry before which the new action(s) should
  be inserted. If it's a string, the actions will be inserted before the action
  with that name. If it's an integer, the new actions will be inserted before
  the action at position _entry_. If the given entry doesn't exist (or it's a number
  larger than the size of the array), the new actions will be appended at the  end
@param [Array<String,nil>] names the names of the actions to insert. *nil* entries
  represent separator
@return [self]
=end
      def insert_before entry, *names
        insert_after_or_before entry, :before, names
      end

=begin rdoc
Inserts one or more actions after a given one

@param [String,Integer] entry the entry after which the new action(s) should
  be inserted. If it's a string, the actions will be inserted after the action
  with that name. If it's an integer, the new actions will be inserted after
  the action at position _entry_. If the given entry doesn't exist (or it's a number
  larger than the size of the array), the new actions will be appended at the  end
@param [Array<String,nil>] names the names of the actions to insert. *nil* entries
  represent separator
@return [self]
=end
      def insert_after entry, *names
        insert_after_or_before entry, :after, names
      end
      
      private 

=begin rdoc
Helper method used by {#insert_after} and {#insert_before}

This is the method which performs the actual insertion of elements

@param entry (see #insert_after)
@param [Symbol] where whether the new actions should be inserted before or after
  _entry_. It can be either @:before@ or @:after@
@param names (see #insert_after)
@return [self]
=end
      def insert_after_or_before entry, where, names
        idx = if entry.is_a? Integer
        # The - 1 is needed because entry is the number of separators, but indexes start
        # at 0
          (self.each_with_index.find_all{|a, i| a.nil?}[entry - 1] || [])[1]
        else self.index(entry)
        end
        if idx and where == :after then idx += 1
        elsif !idx then idx = size
        end
        #Using reverse_each, we don't need to care increasing idx as we add items (the 
        #first item should be at position idx, the second at idx+1 and so on. With reverse_each)
        #this happens automatically. The +1 is needed to insert the items after idx
        names.reverse_each{|n| insert idx, n}
        self
      end
      
    end

  end
  
end
