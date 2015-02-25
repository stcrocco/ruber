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

require 'ruber/output_widget'

module Ruber
  
=begin rdoc
OutputWidget which allows the user to filter the contents, displaying only the
items which match a given regexp.

This widget provides a line edit to enter the regexp, which is shown using a 
'Create filter' action from the context menu. When the user presses the Return
key from within the line edit, a filter is created from the current text and applied
(if the line edit is empty, any existing filter is removed). If the user doesn't
want to create the filter, the line edit is hidden by pressing ESC while within it.

The filter is implemented using a FilteredOutputWidget::FilterModel, which is a
slightly modified <tt>Qt::SortFilterProxyModel</tt>. Most of the times, however,
you don't need to worry about this, as all the methods provided by this class
still use indexes referred to the source model. This means that, most of the times,
adding filtering capability to an output widget is as simple as having it inherit
from FilteredOutputWidget rather than from OutputWidget.

Besides the 'Create Filter', this class adds two other entries to the context menu:
'Clear Filter', which removes the existring filter, and a 'Ignore Filter' toggle
action, which allows to temporarily disable the filter without removing it. Also,
a new UI state, called 'no_filter' is defined: it's true if no filter is applied
and false otherwise

===Slots
* <tt>create_filter_from_editor</tt>
* <tt>clear_filter</tt>
* <tt>ignore_filter(bool)</tt>
* <tt>show_editor</tt>
=end
  class FilteredOutputWidget < OutputWidget
    
=begin rdoc
The model used to filter the contents of the output widget
=end
    attr_reader :filter_model
    alias :filter :filter_model
    alias :source_model :model
    
    slots :create_filter_from_editor, :clear_filter, 'ignore_filter(bool)',
        :show_editor
    
=begin rdoc
Creates a new FilteredOutputWidget.

The arguments have the same meaning as in <tt>OutputWidget.new</tt>. The only
difference is that _opts_ can also contain a +:filter+ entry. If given, it is the
filter model to use (which should be derived from FilteredOutputWidget::FilterModel
or provide the same api); if this entry is missing, a new FilteredOutputWidget::FilterModel
will be used
=end
    def initialize parent = nil, opts = {}
      super parent, opts
      @filter_model = opts[:filter] || FilterModel.new
      @filter_model.parent = self
      @filter_model.dynamic_sort_filter = true
      @filter_model.source_model = model
      view.model = @filter_model
      disconnect @model, SIGNAL('rowsInserted(QModelIndex, int, int)'), self, SLOT('do_auto_scroll(QModelIndex, int, int)')
      connect @filter_model, SIGNAL('rowsInserted(QModelIndex, int, int)'), self, SLOT('do_auto_scroll(QModelIndex, int, int)')
      connect view.selection_model, SIGNAL('selectionChanged(QItemSelection, QItemSelection)'), self, SLOT('selection_changed(QItemSelection, QItemSelection)')
      @editor = KDE::LineEdit.new self
      connect @editor, SIGNAL('returnPressed(QString)'), self, SLOT(:create_filter_from_editor)
      layout.add_widget @editor, 2, 0
      def @editor.keyReleaseEvent e
        super
        hide if e.key == Qt::Key_Escape and e.modifiers == 0
      end
      @editor.hide
      @editor.completion_object = KDE::Completion.new
      @action_list.insert_before 1, nil, 'create_filter', 'ignore_filter', 'clear_filter'
      create_standard_actions
      set_state 'no_filter', true
    end
    
=begin rdoc
Shows the line edit where the user can enter the filter regexp and gives it focus
=end
    def show_editor
      @editor.show
      @editor.set_focus
    end
    
=begin rdoc
Removes the existing filter (if any).

This means that, after calling this method, all items will be accepted
=end
    def clear_filter
      @filter_model.filter_reg_exp = ''
      set_state 'no_filter', true
    end
    
    def scroll_to idx
      case idx
      when Numeric
        rc = @filter_model.row_count
        if idx >= rc then idx = rc -1
        elsif idx < 0 and idx.abs < rc then idx = rc + idx
        elsif idx < 0 then idx = 0
        end
        mod_idx = @filter_model.index idx, 0
        @view.scroll_to mod_idx
      when Qt::ModelIndex
        idx = @filter_model.map_from_source idx unless idx.model == @filter_model
        idx = @filter_model.index(@filter_model.row_count - 1, 0) unless idx.valid?
        @view.scroll_to idx
      when nil
        @view.scroll_to @filter_model.index(@filter_model.row_count - 1, 0)
      end
    end
    
    private
    
=begin rdoc
Creates the 'Create Filter', 'Ignore Filter' and 'Clear Filter' actions, their
state handlers and makes the necessary signal-slot connections
=end
    def create_standard_actions
      super
      acts = []
      acts << KDE::Action.new('Create Filter', self){self.object_name = 'create_filter'}
      acts << KDE::Action.new('Clear Filter', self){self.object_name = 'clear_filter'}
      acts << KDE::ToggleAction.new('Ignore Filter', self){self.object_name = 'ignore_filter'}
      acts.each{|a| actions[a.object_name] = a}
      connect actions['create_filter'], SIGNAL(:triggered), self, SLOT(:show_editor)
      connect actions['clear_filter'], SIGNAL(:triggered), self, SLOT(:clear_filter)
      connect actions['ignore_filter'], SIGNAL('toggled(bool)'), self, SLOT('ignore_filter(bool)')
      register_action_handler actions['clear_filter'], '!no_filter'
      register_action_handler actions['ignore_filter'], '!no_filter'
    end
    
=begin rdoc
Instructs the filter model to ignore or not the filter according to _val_.
=end
    def ignore_filter val
      @filter_model.ignore_filter = val
    end
    
=begin rdoc
Changes the filter accordig to the text in the line edit.

If the line edit is empty, the filter will be removed. Otherwise, it will be set
to the regexp corresponding to the text in the editor
=end
    def create_filter_from_editor
      text = @editor.text
      if !text.empty?
        mod = @editor.completion_object.add_item text
        @filter_model.filter_reg_exp = text
        set_state 'no_filter', false
      else clear_filter
      end
      @editor.hide
    end
    
=begin rdoc
Override of OutputWidget#copy which takes into account the filter. This means that
only the items in the filter model will be taken into account.

<b>Note:</b> the indexes passed to <tt>text_for_clipboard</tt> refer to the source
model, as in OutputWidget, not to the filter model.
=end
    def copy
      items = []
      stack = []
      @filter_model.row_count.times do |r|
        @filter_model.column_count.times do |c|
          stack << @filter_model.index(r, c)
        end
      end
      until stack.empty?
        it =  stack.shift
        items << @filter_model.map_to_source(it)
        (@filter_model.row_count(it)-1).downto(0) do |r|
          (@filter_model.column_count(it)-1).downto(0) do |c|
            stack.unshift it.child(r, c)
          end
        end
      end
      clp = KDE::Application.clipboard
      clp.text = text_for_clipboard items
    end

=begin rdoc
Override of OutputWidget#copy_selected.

<b>Note:</b> the indexes passed to <tt>text_for_clipboard</tt> refer to the source
model, as in OutputWidget, not to the filter model.
=end
    def copy_selected
      clp = KDE::Application.clipboard
      indexes = @view.selection_model.selected_indexes.map{|i| @filter_model.map_to_source i}
      clp.text = text_for_clipboard indexes
    end
    
=begin rdoc
Override of OutputWidget#maybe_open_file.

It converts the index _idx_ to the source model before passing it to *super*.
If _idx_ already refers to the source model, it is passed as it is to *super*.
=end
    def maybe_open_file idx
      idx = @filter_model.map_to_source idx if idx.model.same? @filter_model
      super idx
    end

=begin rdoc
Filter model derived from <tt>Qt::SortFilterProxyModel</tt> which better integrate
with FilteredOutputWidget.

The differences between this class and <tt>Qt::SortFilterProxyModel</tt> are the
following
* it has the ability to ignore the filter (see FilteredOutputWidget)
* it provides an easy way to always accept some kind of items (see +exclude+ and
<tt>exclude_from_filtering?</tt>)
* it emits a signal when the filter reg exp is changed

<b>Note:</b> this class is meant to be used with a regexp filter, not with a string
filter.

===Signals
=====<tt>filter_changed(QString reg)</tt>
Signal emitted when the regexp used for filtering changes (including when the
filter is removed). _reg_ is a string containing the source of the regexp.
=end
    class FilterModel < Qt::SortFilterProxyModel
      
      signals 'filter_changed(QString)'

=begin rdoc
The kind of items to exclude from filtering. See <tt>exclude_from_filtering?</tt>
=end
      attr_reader :exclude
      
=begin rdoc
Creates a new FilterModel.

_parent_ is the parent object, while _exclude_ is the initial value of the +exclude+
attribute (which can be changed later).
=end
      def initialize parent = nil, exclude = nil
        super parent
        @exclude = exclude
        @ignore_filter = false
      end
      
=begin rdoc
Tells whether the object has been instructed to ignore the filter
=end
      def filter_ignored?
        @ignore_filter
      end
      
=begin rdoc
Instructs the model to ignore or not the filter, according to _val_. This method
always invalidate the model
=end
      def ignore_filter= val
        @ignore_filter = val
        invalidate
      end
      
=begin rdoc
Override of <tt>Qt::SortFilterProxyModel#filter_reg_exp=</tt> which, after changing the regexp (
and invalidating the model) emits the <tt>filter_changed(QString)</tt> signal
=end
      def filter_reg_exp= str
        super
        emit filter_changed(str)
      end
      
      def exclude= val
        @exclude = val
        invalidate_filter
      end
      
#       protected
      
=begin rdoc
Override of <tt>Qt::SortFilterProxyModel#filterAcceptsRow</tt> which also takes
into account the setting for <tt>filter_ignored?</tt> and +exclude+. In particular,
if <tt>filter_ignored?</tt> is *true* or if <tt>exclude_from_filtering?</tt> returns
*true* for the given row and parent, then it will always return *true*. Otherwise,
it behaves like <tt>Qt::SortFilterProxyModel#filterAcceptsRow</tt>
=end
      def filterAcceptsRow r, parent
        return true if @ignore_filter
        return true if exclude_from_filtering? r, parent
        super
      end
      
=begin rdoc
Tells the filter whether the filter should be applied to the given row and parent
or whether it should always be accepted, according to the value of +exclude+. In
particular:
* if +exclude+ is +:toplevel+, then the filter will be applied only to child items
(toplevel items will always be accepted)
* if +exclude+ is +:children+, then the filter will be applied only to toplevel items
(child items will always be accepted)
* any other value will cause the filter to be applied to all items

Derived classes can modify this behaviour by overriding this method. The arguments
have the same meaning as sin +filterAcceptsRow+
=end
      def exclude_from_filtering? r, parent
        case @exclude
        when :toplevel then !parent.valid?
        when :children then parent.valid?
        else false
        end
      end
      
    end
    
  end
  
  
end
