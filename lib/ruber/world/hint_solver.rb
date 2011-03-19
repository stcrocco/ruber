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

require 'ruber/pane'
require 'ruber/editor/editor_view'

module Ruber
  
  module World

=begin rdoc
Helper class used by {MainWindow#editor_for} and friends to find out which editor
should use or where the new editor should be placed according to the hints given
them
=end
    class HintSolver

=begin rdoc
@param [KDE::TabWidget] tabs the tab widget which contains the tabs
@param [KParts::PartManager] manager the part manager used by the main window
@param [Array<EditorView>] view_order an array specifying the order in which views
  were activated. Most recently activated views corresponds to lower indexes. It's
  assumed that the main window will keep a reference to this array and update it
  whenever a view becomes activated
=end
      def initialize tabs, manager, view_order
        @tabs = tabs
        @part_manager = manager
        @view_order = view_order
      end
      
=begin rdoc
Finds the editor to use for a document according to the given hints

If no editor associated with the document and respecting the given hints exists,
*nil* is returned. This always happens if the @:existing@ hint is @:never@.
@param [Document] doc the document to retrieve the editor for
@param hints (see MainWindow#editor_for). See {#MainWindow#editor_for} for the
  values it can contain. Only the @:existing@ and @:strategy@ entries are used
@return [EditorView,nil] a view associated with the document which respects the
  hints or *nil* if such a view doesn't exist
=end
      def find_editor doc, hints
        views = []
        case hints[:existing]
        when :never then return nil
        when :current_tab
          views = @tabs.current_widget.select{|v| v.document == doc}
        else @tabs.each{|t| views += t.select{|v| v.document == doc} }
        end
        choose_editor doc, views, hints
      end
      
=begin rdoc
Finds out where a new editor should respect the given hints

The return value tells where the new editor should be placed. If the return value
is *nil* then the editor should be placed in a new tab; if it's an {EditorView} then
the editor should be placed in the pane containing the view, splitting it at the
view
@param hints (see MainWindow#editor_for). See {#MainWindow#editor_for} for the
values it can contain. Only the @:newand entry is used
@return [EditorView, nil] an {EditorView} if the new editor should be placed inside
  an existing pane. The returned view is the view where it's parent should be split
  at. If *nil* is returned, the editor should be put in a new tab
=end
      def place_editor hints
        case hints[:new]
        when :new_tab then nil
        when :current then @view_order[0]
        when :current_tab
          current = @tabs.current_widget
          current.each_view.to_a[0] if current
        when Integer
          pane = @tabs.widget hints[:new]
          pane.each_view.to_a[0] if pane
        when EditorView then 
          view = hints[:new]
          view.parent.is_a?(Pane) ? view : nil
        end
      end
      
      private
      
=begin rdoc
Chooses an editor according to the value of the :strategy hint

For each strategy specified in the hint, this method calls a method called @choose_editor_*_strategy@,
where the @*@ stands for the strategy name.

If there's no editor satsifying the given strategy, then the @:next@ strategy, which
always gives a result, is used.
@param [Document] doc the document associated with the editor
@param [Array<EditorView>] editors a list of the editors to choose among. They should
  be ordered by tab and, within the same tab, from left to right and top to bottom
@param hints (see MainWindow#editor_for)
@return [EditorView,nil] an editor view according to the @:strategy@ hint or *nil*
  if _editors_ is empty
=end
      def choose_editor doc, editors, hints
        case editors.size
        when 0 then nil
        when 1 then editors.first
        else
          editor = nil
          (Array(hints[:strategy]) + [:next]).each do |s|
            editor = send "choose_editor_#{s}_strategy", doc, editors, hints
            break if editor
          end
          editor
        end
      end

      
=begin rdoc
A list of all the editors associated with the given document in a pane
@param [Document] doc the document
@param [Pane] tab the pane where to look for editors
@return [Array<EditorView>] the editor views associated with _doc_ in the pane
  _pane_, in order
=end
      def editors_in_tab doc, tab
        tab.select{|v| v.document == doc}
      end

=begin rdoc
Chooses an editor according to the @current@ strategy

@param (see #choose_editor)
@return [EditorView,nil] the current editor if it is associated with _doc_
  and *nil* otherwise
=end
      def choose_editor_current_strategy doc, editors, hints
        current = @view_order[0]
        if current and current.document == doc then current
        else nil
        end
      end

=begin rdoc
Chooses an editor according to the @current_tab@ strategy

@param (see #choose_editor)
@return [EditorView,nil] the first editor in the current tab associated with _doc_
  or *nil* if the current tab doesn't contain any editor associated with _doc_
=end
      def choose_editor_current_tab_strategy doc, editors, hints
        tab = @tabs.current_widget
        views = tab.find_children(EditorView).select do |c| 
          c.is_a?(EditorView) and c.document == doc
        end
        (views & editors).first
      end

=begin rdoc
Chooses an editor according to the @last_current_tab@ strategy

@param (see #choose_editor)
@return [EditorView,nil] the last editor in the current tab associated with _doc_
  or *nil* if the current tab doesn't contain any editor associated with _doc_
=end

      def choose_editor_last_current_tab_strategy doc, editors, hints
        tab = @tabs.current_widget
        views = tab.find_children(EditorView).select do |c| 
          c.is_a?(EditorView) and c.document == doc
        end
        (views & editors).last
      end
      
=begin rdoc
Chooses an editor according to the @next@ strategy

@param (see #choose_editor)
@return [EditorView] the first editor associated with _doc_ starting from
  the current tab
=end

      def choose_editor_next_strategy doc, editors, hints
        current_index = @tabs.current_index
        editor = editors.find do |e|
          pane = e.parent
          pane = pane.parent_pane while pane.parent_pane
          @tabs.index_of(pane) >= current_index
        end
        editor || editors.first
      end

=begin rdoc
Chooses an editor according to the @previous@ strategy

@param (see #choose_editor)
@return [EditorView] the first editor associated with _doc_ starting from
  the current tab and going backwards
=end
      def choose_editor_previous_strategy doc, editors, hints
        current_index = @tabs.current_index
        editor = editors.reverse_each.find do |e|
          pane = e.parent
          pane = pane.parent_pane while pane.parent_pane
          @tabs.index_of(pane) < current_index
        end
        editor || editors.last
      end

=begin rdoc
Chooses an editor according to the @first@ strategy

@param (see #choose_editor)
@return [EditorView] the first editor associated with _doc_ starting from
  the first tab
=end

      def choose_editor_first_strategy doc, editors, hints
        editors.first
      end

=begin rdoc
Chooses an editor according to the @last@ strategy

@param (see #choose_editor)
@return [EditorView] the last editor associated with _doc_ starting from
  the first tab
=end
      def choose_editor_last_strategy doc, editors, hints
        editors.last
      end
      
=begin rdoc
Chooses an editor according to the @last_used@ strategy

@param (see #choose_editor)
@return [EditorView] the last activated editor associated with _doc_
=end
      def choose_editor_last_used_strategy doc, editors, hints
        # The || part is there in case there\'s a view in editors which doesn't
        # appears in the view order. In this case, it's given a fake index which
        # is greater than all the other possible
        editors.sort_by{|e| @view_order.index(e) || (@view_order.count + 1)}.first
      end
      
    end
    
  end
  
end