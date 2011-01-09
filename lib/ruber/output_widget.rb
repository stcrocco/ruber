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
Rather, it's a normal <tt>Qt::Widget</tt> which has the view as its only child.
You can add other widgets to the OutputWidget as you would with any other widget:
create the widget with the OutputWidget as parent and add it to the OutputWidget's
layout (which is a <tt>Qt::GridLayout</tt> where the view is at position 0,0).
  
<b>Note:</b> this class defines two new roles (<tt>OutputTypeRole</tt> and <tt>IsTitleRole</tt>),
which correspond to <tt>Qt::UserRole</tt> and <tt>Qt::UserRole+1</tt>. Therefore,
if you need to define other custom roles, please have them start from
<tt>Ruber::OutputWidget::IsTitleRole+1</tt>.
  
===Colors
The <i>output_type</i> of an entry in the model can be set using the <tt>set_output_type</tt>
method. This has two effects: first, the item will be displayed using the color
chosen by the user for that output type; second, the name of the output type will
be stored in that item under the custom role <tt>OutputTypeRole</tt>.
  
There are several predefined output types: +message+, <tt>message_good</tt>,
<tt>message_bad</tt>, +output+,
+output1+, +output2+, +warning+, +warning1+, +warning2+, +error+, +error1+ and +error2+.
The types ending with a number
can be used when you need different types with similar meaning. The +message+ type
(and its variations) are meant to display messages which don't come from the external
program but from Ruber itself (for example, a message telling that the external
problem exited successfully or exited with an error) Its good and bad version are
meant to display messages with good news and bad news respectively (for example:
"the program exited successfully" could be displayed using the <tt>message_good</tt>
type, while "the program crashed" could be displayed using the <tt>message_bad</tt>
type). The +output+ type is meant
to be used to show the text written by the external program on standard output,
while the +error+ type is used to display the text written on standard error. If
you can distinguish between warning and errors, you can use the +warning+ type
for the latter.

The colors for the default output types are chosen by the user from the configuration
dialog and are used whenever those output types are requested.

New output types (and their associated colors) can be make known to the output
widget by using the <tt>set_color_for</tt> method. There's no need to remove the
color, for example when the plugin is unloaded (indeed, there's no way to do so).

===The context menu
This widget automatically creates a context menu containing three actions: copy,
copy selected and clear. Copy and copy selected copy the text contained respectively
in all the items and in the selected items to the clipboard. The clear action 
removes all the entries from the model.

You can add other actions to the menu by performing the following steps:
* add an entry in the appropriate position of the <tt>action_list</tt> array. Note
  that it actually is an instance of ActionList, so it provides the <tt>insert_after</tt>
  and <tt>insert_before</tt> methods which allow to easily put the actions in the
  correct place. <tt>action_list</tt> should contain the <tt>object_name</tt> of
  the actions (and *nil* for the separators), not the action themselves
* create the actions (setting their <tt>object_name</tt> to the values inserted
  in <tt>action_list</tt>) and put them into the +actions+ hash, using the <tt>object_name</tt>
  as keys. Of course, you also need to define the appropriate slots and connect
  them to the actions' signals.
  
Note that actions can only be added _before_ the menu is first shown (usually, you
do that in the widget's constructor). The signal <tt>about_to_fill_menu</tt> is
emitted just before the menu is built: this is the last time you can add entries
to it.

OutputWidget mixes in the GuiStatesHandler module, which means you can define states
to enable and disable actions as usual. By default, two states are defined: <tt>no_text</tt>
and <tt>no_selection</tt>. As the names imply, the former is *true* when the model
is empty and *false* when there's at least one item; the second is *true* when no
item is selected and *false* when there are selected items.

For the menu to be displayed automatically, the view should have a <tt>context_menu_requested(QPoint)</tt>
signal. The menu will be displayed in response to that signal, at the point given
as argument. For convenience, there are three classes <tt>OutputWidget::ListView</tt>,
<tt>OutputWidget::TreeView</tt> and <tt>OutputWidget::TableView</tt>, derived 
respectively from <tt>Qt::ListView</tt>, <tt>Qt::TreeView</tt> and <tt>Qt::TableView</tt>
which emit that signal from their <tt>contextMenuEvent</tt> method. If you use
one of these classes as view, the menu will work automatically.

===Autoscrolling
Whenever an item is added to the list, the view will be scrolled so that the added
item is visible. Plugins which don't want this feature can disable it using the
<tt>auto_scroll</tt> accessor. Note that auto scrolling won't happen if an item
is modified or removed

===Word Wrapping
If the user has enabled word wrapping for output widgets in the config dialog (
the general/wrap_output option), word wrapping will be automatically enabled for
all output widgets. If the user has disabled it, it will be disabled for all
widgets.

Subclasses can avoid the automatic behaviour by setting the <tt>ignore_word_wrap_option</tt>
attribute to *true* and managing word wrap by themselves. This is mostly useful
for output widgets for which word wrap is undesirable or meaningless.

===Opening files in the editor
Whenever the user activates an item, the text of the item is searched for a filename
(and optionally for a line number). If it's found, a new editor view is opened
and the file is displayed in it. This process uses three methods:
<tt>maybe_open_file</tt>::
  the method connected to the view's <tt>activated(QModelIndex)</tt> signal. It
  starts the search for the filename and, if successful, opens the editor view
<tt>find_filename_in_index</tt>::
  performs the search of the filename. By default, it uses <tt>find_filename_in_string</tt>,
  but subclasses can override it to change the behaviour
<tt>find_filename_in_string</tt>::
  the method used by default  by <tt>find_filename_in_index</tt> to find the
  filename.
  
If a relative filename is found, it's considered relative to the directory contained
in the <tt>working_dir</tt> attribute.

===The <tt>OutputWidget::Model</tt> class
It behaves as a standard <tt>Qt::StandardItemModel</tt>, but it provides an +insert+
method and an <tt>insert_lines</tt> method which make easier adding items. You
don't need to use this model. If you don't, simply pass another one to the OutputWidget
constructor

===Signals
=====<tt>about_to_fill_menu()</tt>
Signal emitted immediately before the menu is created. You should connect to this
signal if you want to add actions to the menu at the last possible time. Usually,
however, you don't need it, as actions are usually created in the constructor.
===Slots
* <tt>show_menu(QPoint)</tt>
* <tt>selection_changed(QItemSelection, QItemSelection)</tt>
* <tt>rows_changed()</tt>
* <tt>do_auto_scroll(QModelIndex, int, int)</tt>
* <tt>copy()</tt>
* <tt>copy_selected()</tt>
* <tt>clear_output()</tt>
* <tt>maybe_open_file()</tt>
=end
  class OutputWidget < Qt::Widget
    
    include GuiStatesHandler
    
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
Whether auto scrolling should be enabled or not (default: *true*)
=end
    attr_accessor :auto_scroll
        
=begin rdoc
Whether word wrapping should be enabled and disabled automatically according to
the general/wrap_output setting or not (default: *false*)
=end
     attr_accessor :ignore_word_wrap_option

=begin rdoc
The directory used to resolve relative paths when opening a file (default *nil*)
=end
    attr_accessor :working_dir
    alias :working_directory :working_dir
    alias :working_directory= :working_dir=
    
=begin rdoc
Whether or not to skip the first file name in the title if the user activates it
(see <tt>find_filename_in_index</tt>)
=end
    attr_accessor :skip_first_file_in_title
       
=begin rdoc
An ActionList containing the names of the actions and the separators (represented
by *nil*) to use to build the menu. The default is ['copy', 'copy_selected', nil, 'clear'].

<b>Note:</b> this is private
=end
    attr_reader :action_list
    
=begin rdoc
A hash having the names of actions to be inserted in the menu as keys and the actions
themselves as values. By default, it contains the 'copy', 'copy_selected' and
'clear' actions.

<b>Note:</b> this is private
=end
    attr_reader :actions
    
=begin rdoc
The model used by the OutputWidget
=end
    attr_reader :model
    
=begin rdoc
The view used by the OutputWidget
=end
    attr_reader :view
    
    
    private :action_list, :actions
    
=begin rdoc
Creates a new OutputWidget. _parent_ is the parent widget. _opts_ can contain
the following keys:
+:view+:: the view to use. It can be either a widget derived from <tt>Qt::AbstractItemView</tt>,
          which will be used as view, or one of the symbols +:list+, +:tree+ or
          +:table+. If it's a symbol, then the view will be a new instance of
          OutputWidget::ListView, OutputWidget::TreeView or OutputWidget::TableView
          respectively. Defaults to +:list+.
+:model+:: the model to use. If this option isn't given, then a new instance of
           OutputWidget::Model will be used
<tt>use_default_font</tt>::
  whether or not to use the application\'s default font in the view. If *false*
  (the default), then the font chosen by the user for the general/output_font
  option will be used.

<b>Note:</b> if a widget is specified as value of the +:view+ option, it will become
a child of the new OutputWidget.
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
Instructs the OutputWidget to use the <tt>Qt::Color</tt> _color_ to display items
whose output type is _name_. _name_ should be a symbol.

If a color had already been set for _name_, it will be overwritten
=end
    def set_color_for name, color
      @colors[name] = color
    end
    
=begin rdoc
Scrolls the view so that the item corresponding to the index _idx_ is visible.

_idx_ can be:
* a <tt>Qt::ModelIndex</tt>
* a positive integer. In this case, the view will be scrolled so that the first
item toplevel item in the row _idx_ is visible.
* a negative integer. It works as for a positive integer except that the rows are
counted from the end (the same as passing a negative integer to <tt>Array#[]</tt>)
* *nil*. In this case, the view will be scrolled so that the first toplevel item
of the last row is visible.
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
    end
    
=begin rdoc
Sets the output type associated with the <tt>Qt::ModelIndex</tt> _idx_ to _type_
(a symbol). 

If a color has been associated with _type_ (either because _type_ is one of the
standard types or because it's been set with <tt>set_color_for</tt>), the foreground
role of the index will be changed to that color and the +OutputTypeRole+ of the
index will be set to a string version of _type_. In this case, _type_ is returned.

If no color has been associated with _type_, this method does nothing and returns
*nil*.
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
Executes the block with autoscrolling turned on or off according to _val_, without
permanently changing the autoscrolling setting.
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
    
A title is a toplevel entry at position 0,0 with output type +:message+ and has 
the +IsTitleRole+ set to *true*. Of course, there can be only one item which is
a title.

If the item in position 0,0 is not a title, a new row is inserted at position 0,
its first element's DisplayRole is set to _text_ and its IsTitleRole is set to
true.

If the item in position 0,0 is a title, then its DisplayRole value is replaced
with _text_.

Usually, the title is created when the external program is started and changed
later if needed
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
    end
    
=begin rdoc
Tells whether the toplevel 0,0 element is the title or not. See <tt>title=</tt>
for the meaning of the title
=end
    def has_title?
      @model.index(0,0).data(IsTitleRole).to_bool
    end
    
=begin rdoc
Loads the settings from the configuration file.
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
    end
    
=begin rdoc
Removes all the entries from the model
=end
    def clear_output
      @model.remove_rows 0, @model.row_count
    end

    protected
    
#     def keyReleaseEvent e
#       ed = Ruber[:main_window].active_editor
#       return super unless ed 
#       Ruber[:main_window].activate_editor ed
#       ed.set_focus
# #       mod = e.modifiers
# #       if mod == Qt::NoModifier or mod == Qt::ShiftModifier
# #         ed.insert_text e.text
# #       end
#       nil
#     end
    
    private
    
=begin rdoc
Changes the foreground color of the Qt::ModelIndex _idx_ and of its children so
that it matches the color set for its output type.
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
    end
    
=begin rdoc
Creates the model (if needed) and makes some signal-slot connections
=end
    def setup_model mod
      @model = mod || Model.new(self)
      @model.insert_column 0 if @model.column_count < 1
      @model.parent = @view
      @view.model = @model
      connect @model, SIGNAL('rowsInserted(QModelIndex, int, int)'), self, SLOT(:rows_changed)
      connect @model, SIGNAL('rowsRemoved(QModelIndex, int, int)'), self, SLOT(:rows_changed)
      connect @model, SIGNAL('rowsInserted(QModelIndex, int, int)'), self, SLOT('do_auto_scroll(QModelIndex, int, int)')
    end
    
=begin rdoc
Automatically scrolls to the first row of <i>end_idx</i> if auto scrolling is enabled.

Note: all parameters are considered relative to the model associated with the view,
not with the @model@ attribute (of course, this only matters in subclasses where
the two differ, such as {FilteredOutputWidget}).
=end
    def do_auto_scroll parent, start_idx, end_idx
      scroll_to @view.model.index(end_idx, 0, parent) if @auto_scroll
    end

=begin rdoc
Creates the menu, according to the contents of the <tt>@action_list</tt> and
<tt>@actions</tt> instance variables.

Before creating the menu, it emits the <tt>about_to_fill_menu()</tt> signal. Connecting
to this signal allows to do some last-minute changes to the actions which will
be inserted in the menu.
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
Shows the menu (asynchronously) at the point _pt_.

If the menu hasn't as yet been created, it creates it.
=end
    def show_menu pt
      fill_menu if @menu.empty?
      @menu.popup pt
    end
    
=begin rdoc
Creates the layout and the view. _view_ has the same meaning as the <tt>:view</tt>
option in the constructor
=end
    def create_widgets view
      self.layout = Qt::GridLayout.new(self)
      if view.is_a?(Qt::Widget)
        @view = view
        @view.parent = self
      else @view = self.class.const_get(view.to_s.capitalize + 'View').new self
      end
      @view.selection_mode = Qt::AbstractItemView::ExtendedSelection
      layout.add_widget  @view, 0, 0
    end
    
=begin rdoc
Creates the 'Copy', 'Copy selected' and 'Clear' actions and the correspongind 
state handlers
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
    end
    
=begin rdoc
Slot connected to the 'Copy' action.

It copies the content of all the items to the clipboard. The text is obtained
from the items by calling <tt>text_for_clipboard</tt> passing it all the items.
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
    end

=begin rdoc
Slot connected to the 'Copy Selection' action.

It copies the content of all the items to the clipboard. The text is obtained
from the items by calling <tt>text_for_clipboard</tt> passing it the selected items.
=end
    def copy_selected
      clp = KDE::Application.clipboard
      clp.text = text_for_clipboard @view.selection_model.selected_indexes
    end
    
=begin rdoc
Method used by the +copy+ and <tt>copy_selected</tt> methods to obtain the text
to put in the clipboard from the indexes.

The default behaviour is to create a string which contains the content of all the
toplevel items on the same row separated by tabs and separate different rows by
newlines. Child items are ignored.

Derived class can override this method (and, if they plan to put child items in
the view, they're advised to do so). The method must accept an array of <tt>Qt::ModelIndex</tt>
as argument and return a string with the text to put in the clipboard.

The reason the default behaviour ignores child items is that their meaning (and
therefore the way their contents should be inserted into the string) depends
very much on the specific content.
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
Slot connected to the view's selection model's selectionChanged signal.

Turns the <tt>no_selection</tt> state on or off depending on whether the selection
is empty or not
=end
    def selection_changed sel, desel
      change_state 'no_selection', !@view.selection_model.has_selection
    end
    
=begin rdoc
Turns the <tt>no_text</tt> state on or off depending on whether the model
is empty or not
=end
    def rows_changed
      change_state 'no_text', @model.row_count == 0
    end
    
=begin rdoc
Searches for a filename in the DisplayRole of the <tt>Qt::ModelIndex</tt> idx (
using the <tt>find_filename_in_index</tt> method). If a filename is found, opens
a new editor view containing the file, scrolls it to the appropriate line and
hides the tool widget (*self*).

The behaviour of this method (which usually is only called via a signal-slot connection
to the views' <tt>activated(QModelindex) signal) changes according to the active 
keyboard modifiers:
* if Ctrl or Shift are pressed and the view allows selection (that is, its selection
mode is not +NoSelection+), then this method does nothing. The reason for this
behaviour is that Ctrl and Shift are used to select items, so the user is most
likely doing that, not requesting to open a file
* if Meta is pressed, then the tool widget won't be closed
=end
    def maybe_open_file idx
      modifiers = Application.keyboard_modifiers
      if @view.selection_mode != Qt::AbstractItemView::NoSelection
        return if Qt::ControlModifier & modifiers != 0 or Qt::ShiftModifier & modifiers != 0
      end
      file = find_filename_in_index idx
      return unless file
      line = file[1]
      line -= 1 if line > 0
      Ruber[:main_window].display_document file[0], line, 0
      Ruber[:main_window].hide_tool self if (Qt::MetaModifier & modifiers) == 0
    end
    
=begin rdoc
Method used by <tt>maybe_open_file</tt> to find out the name of the file to open
(if any) when an item is activated.

_idx_ can be either the <tt>Qt::ModelIndex</tt> corresponding to the activated
item or a string. The first form is used when this method is called from the
<tt>activated(QModelIndex)</tt> signal of the view; the string form is usually
called by overriding methods using *super*.

The actual work is done by <tt>find_filename_in_string</tt>, which returns the
first occurrence of what it considers a filename (possibly followed by a line
number).

If <tt>find_filename_in_string</tt> finds a filename, this method makes sure it
actually corresponds to an existing file and, if it's a relative path, expands
it, considering it relative to the <tt>working_dir</tt> attribute. If that
attribute is not set, the behaviour is undefined (most likely, an exception will
be raised).

If _idx_ is the title (see <tt>title=</tt>) and <tt>skip_first_file_in_title</tt>
is *true*, all the text from the beginning to the first space or colon is removed
from it before being passed to <tt>find_filename_in_string</tt>. The reason is
that often the title contains the command line of a program, for example:

 /usr/bin/ruby /path/to/script.rb

In this case, when the user activates the title, he will most likely want to
open <tt>/path/to/script.rb</tt> rather than <tt>/usr/bin/ruby</tt> (which, being
an executable, couldn't even be correctly displayed). Nothing like this will
ever happen if _idx_ is a string.

Subclasses can override this method to extend or change its functionality. They
have two choices on how to do this. The simplest is useful if they want to alter
the string. In this case they can retrieve the text from the index, change it
then call *super* passing the modified string as argument. Otherwise, they should
reimplement all the functionality. In this case, the method should:
* take a <tt>Qt::ModelIndex</tt> or a string as argument
* return a string with the name of the file or an array containing a string and
the associated line number (if found) if a file name is found
* return *nil* if no file name is found
* convert relative file names to absolute (either using the <tt>working_dir</tt>
attribute or any other way they see fit)

A subclass can decide to completely disable this functionality by overriding this
method with one which always returns *nil*.
=end
    def find_filename_in_index idx
      str = if idx.is_a?(String) then idx
      elsif @skip_first_file_in_title and idx.data(IsTitleRole).to_bool
          idx.data.to_string.sub(/^[^\s:]+/, '')
      else idx.data.to_string
      end
      res = find_filename_in_string str
      d res
      return unless res
      res = Array res
      res << 0 if res.size == 1
      #if res[0] is an url with scheme file:, transform it into a regular file
      #name by removing the scheme and the two following slash
      res[0].sub! %r{^file://}, ''
      if KDE::Url.file_url?(res[0]) then res
      else
        res[0] = File.join @working_dir, res[0] unless Pathname.new(res[0]).absolute?
        if File.exist?(res[0]) and !File.directory?(res[0])
          res
        else nil
        end
      end
    end
    
=begin rdoc
Searches the given string for the first occurrence of a file name (possibly followed by a colon and a line
number). If a file name is found, returns an array containing the file name and
the corresponding line number (if present). Returns *nil* if no file name was found.

What is a file name and what isn't is a bit arbitrary. Here's what this method
recognizes as a filename:
* an absolute path not containing spaces and colons starting with '/'
* an absolute path not containing spaces and colons starting with '~' or '~user'
(they're expanded using @File.expand_path@)
* a relative path starting with @./@ or @../@ (either followed by a slash or not)
* a relative path of the form @.filename@ or @.dirname/dir/file@
* any string not containing spaces or colons followed by a colon and a line number
* absolute URLs with an authority component

File names enclosed in quotes or parentheses are recognized.

The first three entries of the previous list can be followed by a colon and a line
number; for the last one they're mandatory
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
      d str
      d matches
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
      def flags idx
        if @global_flags
          idx.valid? ? @global_flags : Qt::NoItemFlags
        else super
        end
      end
      
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
          i ? Qt::StandardItem.new(i) : Qt::StandardItem.new
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
Convenience class to be used instead of <tt>Qt::ListView</tt> in an OutputWidget.

The only difference from Qt::ListVew is that it defines a <tt>context_menu_requested(QPoint)</tt>
signal and emits it from its +contextMenuEvent+ method
=end
    class ListView < Qt::ListView
      
      signals 'context_menu_requested(QPoint)'
      
=begin rdoc
Works as in the superclass but also emits the <tt>context_menu_requested(QPoint)</tt>
signal
=end
      def contextMenuEvent e
        super e
        emit context_menu_requested(e.global_pos)
      end
      
    end

=begin rdoc
Convenience class to be used instead of <tt>Qt::TreeView</tt> in an OutputWidget.

The only difference from Qt::TreeVew is that it defines a <tt>context_menu_requested(QPoint)</tt>
signal and emits it from its +contextMenuEvent+ method
=end
    class TreeView < Qt::TreeView
      
      signals 'context_menu_requested(QPoint)'

=begin rdoc
Works as in the superclass but also emits the <tt>context_menu_requested(QPoint)</tt>
signal
=end
      def contextMenuEvent e
        super e
        emit context_menu_requested(e.global_pos)
      end
      
    end

=begin rdoc
Convenience class to be used instead of <tt>Qt::TableView</tt> in an OutputWidget.

The only difference from Qt::TableVew is that it defines a <tt>context_menu_requested(QPoint)</tt>
signal and emits it from its +contextMenuEvent+ method
=end
    class TableView < Qt::TableView
      
      signals 'context_menu_requested(QPoint)'

=begin rdoc
Works as in the superclass but also emits the <tt>context_menu_requested(QPoint)</tt>
signal
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
 :call-seq: list.insert_before entry, name1 [, name2, ...]

 Adds one or more actions before a given one
 =====Arguments
 _entry_:: the name of the action before which to insert the new ones. If this
           an integer _n_, then the actions will be added before the _n_th
           separator. If the entry doesn't exist, or the number of separators is
           less than _n_, the new entries will be added at the end of the list
 _namei_:: the names of the actions to add (or +nil+ for separators)
=end
      def insert_before entry, *names
        insert_after_or_before entry, :before, names
      end

=begin rdoc
 :call-seq: list.insert_after entry, name1 [, name2, ...]

 Adds one or more actions after a given one
 =====Arguments
 _entry_:: the name of the action after which to insert the new ones. If this
           an integer _n_, then the actions will be added after the _n_th
           separator. If the entry doesn't exist, or the number of separators is
           less than _n_, the new entries will be added at the end of the list
 _namei_:: the names of the actions to add (or +nil+ for separators)
=end
      def insert_after entry, *names
        insert_after_or_before entry, :after, names
      end
      
      private 

=begin rdoc
Helper method used by <tt>insert_after</tt> and <tt>insert_before</tt> which performs
the actual insertion of the elements.

_entry_ has the same meaning as in <tt>insert_after</tt> and <i>insert_before</tt>,
while _names_ has the same meaning as the optional arguments of those methods.
_where_ can be +:after+ or +:before+ and tells whether the new elements should be
inserted after or before the position.
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
      end
      
    end

  end
  
end
