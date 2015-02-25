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

require 'facets/enumerable/sum'

module Ruber
  
=begin rdoc
Widget representing the main area of Ruber's main window. It contains the space
for the main widget (that is, the tab widget where the editors are located) and
the tool widgets, together with their tab bars.

To allow for several main widgets existing (but not being visible) at the same time
(one main widget for each environment) the space for the main widget is given by
a single @Qt::StackedWidget@, where the different main widgets are placed using
{#add_widget}. {#main_widget=} is then used to bring one of the main widgets to
the foreground; {#remove_widget} removes a widget from the stacked widget (to be
used when a project is closed).

The workspace provides three _tool widgets containers_, one on each side of the
main widget except above it. The container on each side is indipendent from the
others. The containers have buttons for their tool widgets and a @Qt::StackedWidget@
for the widget themselves. Each container is indipendent from the other ones

A tool widget can be in several different states:
* _raised_ or _lowered_: a tool widget is _raised_ when it's on the top of its container
  stacked widget. There can be only one raised tool widget for side. All tool widgets
  which aren't raised are said to be _lowered_
* _visible_ or _hidden_: each tool widget container can be visible or hidden. The
  raised tool widget in a visible container is said to be _visible_. Widgets in
  an hidden container are said to be _hidden_.
* _active_ or _inactive_: the _active_ tool widget is the one which has keyboard
  focus; all others are _inactive_. Of course there can be at most one active tool
  widget across the whole workspace. If the focus is not in one of the tool widgets
  (most likely meaning one of the editors has focus), all tool widgets will be
  inactive.
=end
  class Workspace < Qt::Widget
    
=begin rdoc
 Class used by +ToolManager+ to display the currently selected widget. It's a
 <tt>Qt::WidgetStack</tt> which handles the +keyPressEvent+ when the key is either 
 Esc or Shift+Esc. In the former case, the tool widget is hidden; in the latter
 the focus is given back to the editor.

 ===TODO
 See whether this can somehow managed using shortcuts
=end
    class StackedWidget < Qt::StackedWidget
      
#       protected
      
=begin rdoc
Handles the key press event. First, it calls the method of the parent class,
then if the event hasn't been accepted, activates the editor if the key was
<tt>Shift + Esc</tt> or hides the current tool (thus activating the editor) if
the key was +Esc+ with no modifiers.
=====Arguments
_e_:: the event (<tt>Qt::KeyEvent</tt>)
=end
      def keyPressEvent e
        super e
        return if e.accepted?
        if e.key == Qt::Key_Q and e.modifiers == Qt::ShiftModifier.to_i
          Ruber[:main_window].activate_editor
        elsif e.key == Qt::Key_Q and e.modifiers == Qt::NoModifier.to_i
          Ruber[:main_window].hide_tool current_widget
        else e.ignore
        end
      end

    end
    
=begin rdoc
Internal class used to store information about the position of a tool widget
=end
    ToolData = Struct.new(:side, :id)
    
##
# :method: tool_raised(tool)
# 
# <b>Signal</b>
# 
# <b>Signature:</b> <tt>tool_raised(QWidget*)</tt>
# 
# Signal emitted when a tool widget is raised. _tool_ is the widget which
# has been raised
    signals 'tool_raised(QWidget*)'
    
##
# :method: removing_tool(tool)
# 
# *Signal*
# 
# <b>Signature:</b> <tt>removing_tool(QWidget*)</tt>
# 
# Signal emitted just before the tool widget _tool_ is removed
    signals 'removing_tool(QWidget*)'
    
##
# :method: tool_shown
# <b>Signal: <tt>tool_shown(QWidget*)</tt></b>
# 
# Signal emitted when a tool widget is shown programmaticaly.
    signals 'tool_shown(QWidget*)'
    
    slots 'toggle_tool(int)'
       
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
    def initialize parent = nil
      super parent
      @button_bars = {}
      @splitters = {}
      @stacks = {}
      @widgets = {}
      @next_id = 0
      @tool_sizes = {}
      @sizes = Ruber[:config][:workspace, :tools_sizes].dup
      create_skeleton
    end
    
    def add_widget w
      @main_widget.add_widget w
    end
    
    def remove_widget w
      @main_widget.remove_widget w
    end
    
    def main_widget
      @main_widget.current_widget
    end
    
    def main_widget= w
      unless @main_widget.include? w
        Kernel.raise ArgumentError, "a widget which has not been added to the workspace can\'t become the main widget"
      end
      @main_widget.current_widget = w
    end

=begin rdoc
Adds a tool widget to the workspace

@param [Symbol] side the side where the tool widget should be put. It can be
  @:left@, @:right@ or @:bottom@
@param [Qt::Widget] widget the widget to add
@param [Qt::Pixmap] icon the icon to show on the button associated with the tool
  widget
@param [String] caption the text to show on the button associated with the tool
  widget
@raise [ArgumentError] if the same tool widget had already been added to the workspace
  (either on the same side or on another side)
@return [nil]
=end
    def add_tool_widget side, widget, icon, caption
      if @stacks.values.include? widget.parent
        Kernel.raise ArgumentError, "This widget has already been added as tool widget"
      end
      bar = @button_bars[side]
      id = @next_id
      bar.append_tab icon, id, caption
      @widgets[widget] = ToolData.new side, id
      @stacks[side].add_widget widget
      connect bar.tab(id), SIGNAL('clicked(int)'), self, SLOT('toggle_tool(int)')
      @next_id += 1
      nil
    end
    
=begin rdoc
Removes a tool widget. _arg_ can be either the widget itself or its <tt>object_name</tt>,
either as a string or as a symbol. If the widget isn't a tool widget, nothing
happens.
=end
    def remove_tool_widget arg
      widget, data = if arg.is_a? String or arg.is_a? Symbol
        @widgets.find{|k, v| k.object_name == arg.to_s}
      else [arg, @widgets[arg]]
      end
      return unless widget and data
      emit removing_tool(widget)
      stack = @stacks[data.side]
      raised = stack.current_widget.equal?(widget)
      stack.remove_widget widget
      if stack.empty? then stack.hide
      else raise_tool stack.current_widget
      end
      @button_bars[data.side].remove_tab data.id
    end
    
=begin rdoc
Raises the tool widget _tool_, which can be either the tool widget itself or its
<tt>object_name</tt>, either as a string or symbol. If _tool_ is not a tool widget
(or if no tool widget with that <tt>object_name</tt> exists), nothing is done. If
_tool_ is a string or symbol and more than one tool widget exist with that <tt>object_name</tt>,
which one is raised is undefined.

<b>Note:</b> this method doesn't make the container of _tool_ visible if it's hidden
=end
    def raise_tool tool
      tool, data = tool_and_data tool
      return unless tool
      bar = @button_bars[data.side]
      stack = @stacks[data.side]
      old = stack.current_widget
      if old and old.visible?
        store_tool_size old
        old_data = @widgets[old]
        bar.set_tab old_data.id, false
      end
      bar.set_tab data.id, true
      if old != tool
        stack.current_widget = tool
        emit tool_raised(tool)
        emit tool_shown(tool) if stack.visible?
      end
      resize_tool tool
    end

=begin rdoc
Shows the tool widget _tool_. This means that _tool_ will become the current widget
in its stack and that the stack will become visible (if it's not already visible).
_tool_ won't receive focus, unless the previously current widget of its stack had
focus.

_tool_ can be either the tool widget itself or its <tt>object_name</tt>, either as
string or as symbol. In the latter cases, it there's more than one tool widget with
the same <tt>object_name</tt>, it's undefined which one will be shown.

If _tool_ isn't a tool widget, nothing happens.
=end
    def show_tool tool
      tool, data = tool_and_data tool
      return unless tool
      data = @widgets[tool]
      stack = @stacks[data.side]
      visible = tool.visible?
      give_focus = stack.find_children(Qt::Widget).any?{|w| w.has_focus}
      raise_tool tool
      stack.show unless stack.visible?
      emit tool_shown(tool) unless visible
      tool.set_focus if give_focus
    end
    
=begin rdoc
Gives focus to the tool widget _tool_ (raising and showing it if necessary). _tool_
can be either the tool widget itself or its <tt>object_name</tt> (as either a string
or symbol). If _tool_ doesn't represent a valid tool widget, nothing happens. If
_tool_ is a string or symbol and more than one tool widget with the same name exists,
which one will obtain focus is undefined.
=end
    def activate_tool tool
      tool, data = tool_and_data tool
      return unless tool
      show_tool tool unless tool.visible?
      tool.set_focus
    end
    
=begin rdoc
<b>Slot</b>

Activates the tool _tool_ if it's not visibile and hides its stack if instead it's
visible.

_tool_ can be either the tool widget itself or its <tt>object_name</tt> (as either a string
or symbol) or the id of the tab associated with the tool widget. If _tool_ doesn't
represent a valid tool widget, nothing happens. If
_tool_ is a string or symbol and more than one tool widget with the same name exists,
which one will obtain focus is undefined.

<b>Note:</b> the use of the id of the tab as argument is only for internal use.
=end
    def toggle_tool tool
      tool, data = tool_and_data tool
      return unless tool
      if !tool.visible? then activate_tool tool
      else hide_tool tool
      end
    end
    
=begin rdoc
Hides the stack containing the tool widget _tool_, giving focus to the active editor,
if _tool_ is raised (that is, if it is the current widget of its stack).

_tool_ can be either the tool widget itself or its <tt>object_name</tt> (as
either a string or symbol). If _tool_ doesn't represent a valid tool widget,
nothing happens. If _tool_ is a string or symbol and more than one tool widget
with the same name exists, which one will be used is undefined.
=end
    def hide_tool tool
      tool, data = tool_and_data tool
      return unless tool
      store_tool_size tool if tool.visible?
      stack = tool.parent
      if stack.current_widget == tool
        @button_bars[data.side].set_tab data.id, false
        if stack.visible?
          stack.hide 
          Ruber[:main_window].focus_on_editor
        end
      end
    end

    
=begin rdoc
Stores the tool widgets size in the configuration manager. It reads the sizes of
the splitters for the tool widgets which are visible and uses the values stored
previously for the others.
=end
    def store_sizes
      @stacks.each_value do |s|
        w = s.current_widget
        next unless w
        store_tool_size w if w.visible?
      end
      Ruber[:config][:workspace, :tools_sizes] = @sizes
    end
    
=begin rdoc
Returns a hash having all the tool widgets as keys and the side each of them is
(<tt>:left</tt>, <tt>:right</tt>, <tt>:bottom</tt>) as values.
=end
    def tool_widgets
      res = {}
      @widgets.each_pair{|w, data| res[w] = data.side}
      res
    end
    
    def current_widget side
      @stacks[side].current_widget
    end
    
=begin
Returns the active tool widget, or *nil* if there's no active tool widget.
=end
    def active_tool
      fw = KDE::Application.focus_widget
      if @widgets.include? fw then fw
      else @widgets.keys.find{|w| w.find_children(Qt::Widget).include? fw}
      end
    end
    
    private
    
=begin rdoc
Helper method which creates the structure of the workspace (layout, button bars,
splitters and tab view)
=end
    def create_skeleton
      self.layout = Qt::GridLayout.new self
      layout.set_contents_margins 0,0,0,0
      layout.vertical_spacing = 0
      %w[left right bottom].each do |side|
        @button_bars[side.to_sym] = 
            KDE::MultiTabBar.new(KDE::MultiTabBar.const_get(side.capitalize), self) 
      end
      layout.add_widget @button_bars[:left], 0, 0
      layout.add_widget @button_bars[:right], 0, 2
      layout.add_widget @button_bars[:bottom], 1, 0, 1, -1
      v = Qt::Splitter.new Qt::Vertical, self
      h = Qt::Splitter.new Qt::Horizontal, v
      layout.add_widget v, 0,1
      @splitters[:vertical] = v
      @splitters[:horizontal] = h
      [:left, :right, :bottom].each do |s| 
        stack = StackedWidget.new{|w| w.hide}
        @stacks[s] = stack
      end
      v.add_widget h
      v.add_widget @stacks[:bottom]
      h.add_widget @stacks[:left]
      @main_widget = Qt::StackedWidget.new self
      h.add_widget @main_widget
      h.add_widget @stacks[:right]
    end
    
=begin rdoc
Resizes the splitter where the tool widget _tool_ is so that the size of _tool_
matches that of the last time it was used. The space needed to do so is taken
from the editor.

If no size is recorded for _tool_, nothing is done.
=end
    def resize_tool tool
      data = @widgets[tool]
      side = data.side
      caption = @button_bars[side].tab(data.id).text
      size = @sizes[caption] #|| 150
      return unless size
      case side
      when :bottom
        splitter = @splitters[:vertical]
        total = splitter.sizes.sum
        new_sizes = [[total - size, 0].max, size]
        splitter.sizes = new_sizes
      when :left
        splitter = @splitters[:horizontal]
        old_sizes = splitter.sizes
        total = old_sizes[0..1].sum
        new_sizes = [size, [total - size, 0].max, old_sizes[-1]]
        splitter.sizes = new_sizes
      when :right
        splitter = @splitters[:horizontal]
        old_sizes = splitter.sizes
        total = old_sizes[1..-1].sum
        new_sizes = [old_sizes[0], [total - size, 0].max, size]
        splitter.sizes = new_sizes
      end
    end
    
=begin rdoc
Stores the size of the splitter slot where the tool widget _tool_ is in the
<tt>@sizes</tt> instance variable.
=end
    def store_tool_size tool
      data = @widgets[tool]
      side = data.side
      caption = @button_bars[side].tab(data.id).text
      splitter, pos = case side
      when :bottom then [@splitters[:vertical], 1]
      when :left then [@splitters[:horizontal], 0]
      when :right then [@splitters[:horizontal], 2]
      end
      @sizes[caption] = splitter.sizes[pos]
    end

=begin rdoc
Returns an array containing the tool widget corresponding to _arg_ and its data
(that is, the entry in the <tt>@widgets</tt> hash corresponding to the tool widget).
_arg_ can be:
* the tool widget itself
* a string or symbol containing the <tt>object_name</tt> of the widget
* an +Integer+ containing the id of the tab associated with the tool widget.
If a suitable tool widget can't be found (or if _arg_ is of another class), *nil*
is returned.
=end
    def tool_and_data arg
      case arg
      when String, Symbol
        name = arg.to_s
        @widgets.find{|w, data| w.object_name == name} 
      when Integer
        @widgets.find{|w, data| data.id == arg}
      else
        if arg.is_a? Qt::Widget 
          data = @widgets[arg]
          [arg, data] if data
        end
      end
    end
    
  end
  
end
