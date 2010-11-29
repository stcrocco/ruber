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
  
  class Pane < Qt::Widget
    
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
        view.named_connect(SIGNAL(:closing), 'parent_pane_remove_view'){remove_view sender}
        #, self, SLOT(:view_closing)
      when 3..4
        super args[3]
        self.layout = Qt::VBoxLayout.new self
        orientation, pane1, pane2 = args[0..3]
        @splitter = Qt::Splitter.new orientation, self
        layout.add_widget @splitter
        @splitter.add_widget pane1
        @splitter.add_widget pane2
        @view = nil
      end
    end
    
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
      if @splitter then idx = @splitter.find_index{|w| w.view == view}
      elsif @view == view then idx = 0
      else return nil
      end
      unless idx
        @splitter.each do |w| 
          res = w.split view, new_view, orientation, pos
          return res if res
        end
        return nil
      end
      new_pane = Pane.new(new_view)
      unless @splitter
        layout.remove_widget(@view)
#         @view.disconnect SIGNAL(:closing), self, SLOT(:view_closing)
        @view.named_disconnect 'parent_pane_remove_view'
        @splitter = Qt::Splitter.new orientation, self
        layout.add_widget @splitter
        pane = Pane.new @view, @splitter
        @splitter.add_widget pane
        @view = nil
      end
      old_pane = @splitter.widget idx
      if @splitter.orientation == orientation
        idx += 1 if pos == :after
        @splitter.insert_widget idx, new_pane
      else
        if pos == :after 
          splitter_pane = Pane.new orientation, old_pane, new_pane, @splitter
        else
          splitter_pane = Pane.new orientation, new_pane, old_pane, @splitter
        end
        @splitter.insert_widget idx, splitter_pane
      end
      [old_pane, new_pane]
    end
    
    private
    
    def remove_view view
    end
    slots 'remove_view(QWidget*)'
   
=begin rdoc
Slot called when a view associ
=end
    def view_closing
      view = sender
      remove_view 
    end
    slots :view_closing
    
  end
  
end