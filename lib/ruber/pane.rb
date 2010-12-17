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

require 'facets/boolean'

module Ruber
  
=begin rdoc
Container used to organize multiple editor views in a tab

A pane can either contain a single non-{Pane} widget (usually an {EditorView})
or multiple {Pane}s in a @Qt::Splitter@. In the first case, the {Pane} is said
to be in _single view mode_, while in the second it's said to be in _multiple view
mode_.

A {Pane} is said to be a direct child of (or directly contained in) another {Pane}
if it is one of the widgets contained in the second {Pane}'s splitter. A non-{Pane}
widget is said to be a direct child of (or directly contained in) a {Pane} if the
pane is in single view mode and contains that widget or if it is in multiple view
mode and one of the widgets in the splitter is in single view mode and contains
that widget.

The most important method provided by this class is {#split}, which allows a view
to be split either horizontally or vertically.

Whenever a view is closed, it is automatically removed from the pane, and panes
are automatically rearranged. The only situation you should care for this is when
the last view of a top-level pane is closed. In this case, the pane emits the {#closing_last_view}
signal.

*Note*: the pane containing a given view (or pane) can change without warning, so
never store them. To access the pane directly containing another pane, use {#parent_pane}
on the child pane; to access the pane directly containing another widget, call
the widget's @parent@ method.

*Note:* this class allows to access the splitter widget. This is only meant to
allow to resize it. It *must not* be used to add or remove widgets to or from it.
=end
  class Pane < Qt::Widget
    
    include QtEnumerable
    
=begin rdoc
@overload initialize(view, parent = nil)
  Creates a {Pane} containing a single view
  @param [EditorView] view the view to insert in the pane
  @param [Qt::Widget,nil] parent the parent widget
  @return [Pane]
@overload initialize(orientation, pane1, pane2, parent = nil)
  Creates a {Pane} containing two other panes in a splitter widget
  @param [Integer] orientation the orientation of the splitter. It can be @Qt::Horizontal@
    or @Qt::Vertical@
  @param [Pane] pane1 the pane to put in the first sector of the splitter
  @param [Pane] pane2 the pane to put in the second sector of the splitter
  @param [Qt::Widget,nil] parent the parent widget
  @return [Pane]
=end
    def initialize *args
      case args.size
      when 1..2
        super args[1]
        @view = args[0]
        @view.parent = self
        self.layout = Qt::VBoxLayout.new self
        layout.add_widget @view
        @splitter = nil
        connect view, SIGNAL('closing(QWidget*)'), self, SLOT('remove_view(QWidget*)')
      when 3..4
        super args[3]
        self.layout = Qt::VBoxLayout.new self
        orientation, pane1, pane2 = args[0..3]
        @splitter = Qt::Splitter.new orientation, self
        layout.add_widget @splitter
        insert_widget 0, pane1
        insert_widget 1, pane2
        @view = nil
      end
    end
    
=begin rdoc
@return [Pane] this pane's containing pane
=end
    def parent_pane
      if parent.is_a?(Qt::Splitter)
        pane = parent.parent
        pane.is_a?(Pane) ? pane : nil
      end
    end
    
=begin rdoc
Whether the pane contains another pane or widget

@overload contain? widget
  Whether the pane contains, directly or indirectly, another pane or widget
  @param [Pane,Qt::Widget] widget the {Pane} or widget to look for
  @return [Boolean] *true* if _widget_ is directly or indirectly contained in this
    pane and *false* if it isn't contained in it

@overload contain? widget, :directly
  Whether the pane directly contains another pane or widget
  @param [Pane,Qt::Widget] widget the {Pane} or widget to look for
  @return [Boolean] *true* if _widget_ is directly contained in this
    pane and *false* if it isn't contained in it or it's contained indirectly
=end
    def contain? widget, mode = nil
      if mode
        if @splitter then @splitter.any?{|w| w == widget}
        else @view == widget
        end
      else find_children(Pane).include? widget
      end
    end
    
=begin rdoc
Signal emitted whenever the single view associated with the paned is about to be closed
@param [Pane] pane the pane which emitted the signal
=end
    signals 'closing_last_view(QWidget*)'
    
=begin rdoc
@return [Qt::Splitter,nil] the splitter used by the pane or *nil* if the pane
  contains a single view
=end
    attr_reader :splitter
   
=begin rdoc
Whether the pane contains a single view or not

@return [Boolean] *true* if the pane contains a single view an *false* if it contains
  a splitter with multiple panes
=end
    def single_view?
      @view.to_b
    end
    
=begin rdoc
The view contained in the pane
@return [EditorView, nil] the view contained in the pane or *nil* if the pane contains
  multiple panes
=end
    def view
      @view
    end
    
=begin rdoc
The orientation in which the pane is split
@return [Integer,nil] @Qt::Horizontal@ or @Qt::Vertical@ according to the orientation
  of the splitter or *nil* if the pane contains a single view
=end
    def orientation
      @splitter ? @splitter.orientation : nil
    end
    
=begin rdoc
Splits the pane in two in correspondence to the given view

The place previously occupated by the view is divided bewtween it and another view,
_new_view_. If needed, other panes are created to accomodate them.

The view to split must already be contained in the pane. It can be contained directly,
as the only view of the pane or inserted in the splitter contained in the pane,
or indirectly, contained in one of the panes contained by this pane.

If _view_ is contained indirectly, the method call will be redirected to the correct
pane (not the one associated with the view but the pane containing the latter).

If _view_ is not contained in this pane, nothing is done.

_new_view_ must not be associated with a pane. When this method returns, a new
pane for it will have been created.

*Note:* after calling this method, the pane associated with _view_ may be changed.
@param [Ruber::EditorView] view the view to split
@param [Ruber::EditorView] new_view the view to insert alongside _view_
@param [Integer] orientation whether the view should be split horizontally or
  vertically. It can be @Qt::Horizontal@ or @Qt::Vertical@
@param [Symbol] pos whether _new_view_ should be put after or before _view_. It
  can be @:after@ or @:before@
@return [Array(Pane, Pane), nil] an array containing the panes associated with _view_
  and with _new_view_. If _view_ wasn't contained in the pane, *nil* is returned
=end
    def split view, new_view, orientation, pos = :after
      idx = index_of_contained_view view
      return split_recursive view, new_view, orientation, pos unless idx
      new_pane = Pane.new(new_view)
      multiple_view_mode orientation
      old_pane = @splitter.widget idx
      if @splitter.orientation == orientation
        idx += 1 if pos == :after
        insert_widget idx, new_pane
      else
        pane = old_pane.multiple_view_mode orientation
        new_idx = pos == :after ? 1 : 0
        old_pane.insert_widget new_idx, new_pane
        old_pane = pane
      end
      [old_pane, new_pane]
    end
    
=begin rdoc
Iterates on child panes

@overload each_pane
  Iterates only on panes which are directly contained in this pane. Does nothing
  if the pane is in single view mode.
  @yieldparam [Pane] pane a child pane
@overload each_pane(:recursive)
  Iterates on all contained panes (recursively). Does nothing if the pane is in
  single view mode.
  @yieldparam [Pane] pane a child pane
@return [Pane,Enumerator] if called with a block returns *self*, otherwise an Enumerator
  which iterates on the contained panes, acting recursively or not according to
  which of the two forms is called
=end
    def each_pane mode = :flat, &blk
      return to_enum(:each_pane, mode) unless block_given?
      return self unless @splitter
      if mode == :flat then @splitter.each{|w| yield w}
      else
        @splitter.each do |w|
          yield w
          w.each_pane :recursive, &blk
        end
      end
      self
    end
    
=begin rdoc
Iterates on all views contained in the pane

This method always acts recursively, meaning that views indirectly contained in
the pane are returned. 

If the pane is in single view mode, that only view is passed to the block.

@yieldparam [EditorView] view a view contained (directly) in the pane
@return [Pane,Enumerator] if a block is given then *self*, otherwise an Enumerator
  which iterates on all the views
=end
    def each_view &blk
      return to_enum(:each_view) unless block_given?
      if single_view? then yield @view
      else
        each_pane(:recursive) do |pn|
          yield pn.view if pn.single_view?
        end
      end
      self
    end
    alias_method :each, :each_view
    
    protected
    
=begin rdoc
Prepares the pane for a contained pane to be moved elsewhere

In practice, this makes the pane to remove parentless and disconnects the {#closing_last_view}
signal from *self*.
@param [Pane] the pane which will be removed
@return [nil]
=end
    def take_pane pane
      pane.parent = nil
      pane.disconnect SIGNAL('closing_last_view(QWidget*)'), self, SLOT('remove_pane(QWidget*)')
      nil
    end
    
=begin rdoc
Inserts a widget in the splitter

If the widget is not a pane, it'll be enclosed in the pane (and become a child of
it). The {#closing_last_view} signal of the pane will be connected with the {#remove_pane}
slot of *self*.

This method assumes that the pane is not in single view mode
@param [Integer] idx the index to insert the widget at
@param [Qt::Widget] widget the widget to insert. If it's not a {Pane}, it'll be
  enclosed in a new pane
@return [Pane] the pane inserted in the splitter. It'll be _widget_ if it's already
  a {Pane} or the new pane enclosing it if it isn't
=end
    def insert_widget idx, widget
      widget = Pane.new widget, @splitter unless widget.is_a? Pane
      @splitter.insert_widget idx, widget
      connect widget, SIGNAL('closing_last_view(QWidget*)'), self, SLOT('remove_pane(QWidget*)')
      widget
    end
    
=begin rdoc
Switches the pane to multiple view mode

It disconnects the view's {#closing} signal from *self*, creates a new splitter
and inserts a new pane for the view in it.

It does nothing if the pane is already in multiple view mode
@param [Integer] orientation the orientation of the new splitter. It can be
  @Qt::Vertical@ or @Qt::Horizontal@
@return [Pane] the new pane associated with the view
=end
    def multiple_view_mode orientation
      return if @splitter
      layout.remove_widget @view
      @view.disconnect SIGNAL('closing(QWidget*)'), self, SLOT('remove_view(QWidget*)')
      @splitter = Qt::Splitter.new orientation, self
      layout.add_widget @splitter
      pane = insert_widget 0, @view
      @view = nil
      pane
    end

=begin rdoc
Switches the pane to single view mode

It disconnects the {#closing_last_view} signal of each pane in the splitter from
self, deletes the splitter then sets the given view as single view for *self*.

It does nothing if the splitter is already in single view mode
@param [EditorView] view the single view to insert in the pane
@return [Pane] self
=end
    def single_view_mode view
      return unless @splitter
      @view = view
      @splitter.each{|w| w.disconnect SIGNAL('closing_last_view(QWidget*)'), self, SLOT('remove_pane(QWidget*)')}
      layout.remove_widget @splitter
      layout.add_widget @view
      connect @view, SIGNAL('closing(QWidget*)'), self, SLOT('remove_view(QWidget*)')
      self
    end

    
    private
    
=begin rdoc
Returns the index of the pane containing given view in the splitter

If the pane is in single view mode, it returns 0 if the single view is _view_
and *nil* otherwise.

If the pane is in multiple view mode, it returns the index of the pane directly
containing the view in the splitter or *nil* none of the panes in the splitter
directly contain _view_.

*Note:* this method is not recursive. This means that if the splitter of *self*
contains the pane @A@, whose splitter contains the pane @B@ which contains _view_,
this method returns *nil*.

@param [EditorView] view the view whose index should be returned
@return [Integer,nil] the index in the splitter corresponding to the pane containing
  _view_ or *nil* if none of the panes contain it
=end
    def index_of_contained_view view
      if @splitter then @splitter.find_index{|w| w.view == view}
      elsif @view == view then 0
      else nil
      end
    end
    
=begin rdoc
Redirects the call to {#split} to the pane which actually contains the pane
containing the given view

It calls {#split} with the arguments passed to it to all panes contained in the splitter
until one of them returns non-nil, then stops
@param (see #split)
@return [Array(Pane, Pane),nil] an array containing the panes associated with _view_
and with _new_view_. If _view_ wasn't contained in any of the children panes, *nil*
is returned
=end
    def split_recursive view, new_view, orientation, pos
      return nil unless @splitter
      @splitter.each do |w|
        res = w.split view, new_view, orientation, pos
        return res if res
      end
      nil
    end
    
=begin rdoc
Slot called when the single view contained in the pane is closed

It emis the {#closing_last_view} signal passing *self* as argument, makes the
view parentless and schedules *self* for deletion.

*Note:* this method assumes the {Pane} is in single view mode
@param [EditorView] view the view which is being closed
@return [nil]
=end
    def remove_view view
      emit closing_last_view(self)
      @view.parent = nil
      delete_later
      nil
    end
    slots 'remove_view(QWidget*)'
   
=begin rdoc
Removes the given pane from the pane

Depending on the situation, removing a pane causes different steps to be taken:
* the pane is always removed from the splitter
* if only one pane remains and it's in single view mode, it'll be deleted and the
  widget it contain will be displayed in this pane, which will be switched to single
  view mode
* if only one pane remains and it's in multiple view mode, the pane it contains
  will be moved to this pane instead. The remaining one will be removed
*Note:* this method is usually called in response to the {#closing_last_view} signal
emitted by a chid pane, so it assumes the pane is in single view mode.
@param [Pane] the pane to remove
@return [nil]
=end
    def remove_pane pane
      pane.parent = nil
      if @splitter.count == 1
        remaining_pane = @splitter.widget(0)
        if remaining_pane.single_view?
          single_view_mode remaining_pane.view
        else
          take_pane remaining_pane
          remaining_pane.splitter.to_a.each_with_index do |w, i|
            remaining_pane.take_pane w
            insert_widget i, w
          end
        end
        remaining_pane.delete_later
      end
      nil
    end
    slots 'remove_pane(QWidget*)'
    
  end
  
end