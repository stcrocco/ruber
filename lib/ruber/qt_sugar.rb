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

require 'yaml'

module Qt
  
  NilObject = Object.new{self.object_name = 'nil object'}
  
  class Base
    
    def nil_object?
      # if the object doesn't inherit from Qt::Object, meta_object will raise
      # an exception
      self.meta_object
      self.equal? NilObject
    end

=begin rdoc
  :call-seq:
  obj.named_connect(sig, name){||...}
    
  It works as Qt::Base#connect, except for the fact that it associates a name
  with the connection. This way, you can use <tt>Qt::base#named_disconnect</tt>
  to disconnect the block from the signal.
    
  This is implemented by tracking the object internally created by Qt to manage
  the connection and assigning it a name, so that it can then be found using 
  <tt>find_child</tt>. 
    
  <b>Note:</b> this method assumes that only one object of class
  <tt>Qt::SignalBlockInvocation</tt> is created by +connect+. If it isn't so, 
  +RuntimeError+ will be raised.
=end
    def named_connect signal, name, &blk
      old_children = find_children(Qt::SignalBlockInvocation)
#       old_children = find_children(Qt::Object).select{|c| c.class == Qt::SignalBlockInvocation}
      res = self.connect(signal, &blk)
      return nil unless res
#       new_children = find_children(Qt::Object).select{|c| c.class == Qt::SignalBlockInvocation} - old_children
      new_children = find_children(Qt::SignalBlockInvocation) - old_children
      unless new_children.size == 1
        raise RuntimeError, "Wrong number of new children: #{new_children.size} instead of 1" 
      end
      new_children.first.object_name = name
      true
    end

=begin rdoc
  Breaks the connection with name _name_ (which should have been created using
  <tt>named_connect</tt>)
=end
    def named_disconnect name
      rec = find_child Qt::SignalBlockInvocation, name
      disconnect self, nil, rec, nil
    end
    
  end
  
  class Point
    
    yaml_as "tag:ruby.yaml.org,2002:Qt::Point"
    
    def self.yaml_new cls, tag, val
      x, y= val['x'], val['y']
      Qt::Point.new(x, y)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'x', self.x
          map.add 'y', self.y
        end
      end
    end
    
    def _dump _
      "#{x};#{self.y}"
    end
    
    def self._load str
      x, y = str.split ';'
      self.new x.to_i, y.to_i
    end
    
  end
  
  class PointF
    
    yaml_as "tag:ruby.yaml.org,2002:Qt::PointF"
    
    def self.yaml_new cls, tag, val
      x, y= val['x'], val['y']
      Qt::PointF.new(x.to_f, y.to_f)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          loc = Qt::Locale.c
          loc.number_options = Qt::Locale::OmitGroupSeparator
          map.add 'x', loc.to_string( self.x )
          map.add 'y', loc.to_string( self.y )
        end
      end
    end
    
    def _dump _
      loc = Qt::Locale.c
      loc.number_options = Qt::Locale::OmitGroupSeparator
      sx = loc.to_string( self.x )
      sy = loc.to_string( self.y )
      "#{sx};#{sy}"
    end
    
    def self._load str
      x, y = str.split ';'
      self.new x.to_f, y.to_f
    end
    
  end
  
  class Size
    
    yaml_as "tag:ruby.yaml.org,2002:Qt::Size"
    
    def self.yaml_new cls, tag, val
      width, height= val['width'], val['height']
      Qt::Size.new(width, height)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'width', width
          map.add 'height', height
        end
      end
    end
    
    def _dump _
      "#{width};#{height}"
    end
    
    def self._load str
      w, h = str.split ';'
      self.new w.to_i, h.to_i
    end
    
    
  end
  
  class SizeF
    
    yaml_as "tag:ruby.yaml.org,2002:Qt::SizeF"
    
    def self.yaml_new cls, tag, val
      width, height= val['width'], val['height']
      Qt::SizeF.new(width.to_f, height.to_f)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          loc = Qt::Locale.c
          loc.number_options = Qt::Locale::OmitGroupSeparator
          map.add 'width', loc.to_string(width)
          map.add 'height', loc.to_string(height)
        end
      end
    end
    
    def _dump _
      loc = Qt::Locale.c
      loc.number_options = Qt::Locale::OmitGroupSeparator
      sw = loc.to_string width
      sh = loc.to_string height
      "#{sw};#{sh}"
    end
    
    def self._load str
      w, h = str.split ';'
      self.new w.to_f, h.to_f
    end
    
  end
  
  class Rect
    
    yaml_as "tag:ruby.yaml.org,2002:Qt::Rect"
    
    def self.yaml_new cls, tag, val
      left, top, width, height= val['left'], val['top'], val['width'], 
          val['height']
      self.new(left, top, width, height)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'left', left
          map.add 'top', top
          map.add 'width', width
          map.add 'height', height
        end
      end
    end
    
    def _dump _
      "#{left};#{top};#{width};#{height}"
    end
    
    def self._load str
      l, t, w, h = str.split ';'
      self.new l.to_i, t.to_i, w.to_i, h.to_i
    end
    
  end
  
  class RectF
    
    yaml_as "tag:ruby.yaml.org,2002:Qt::RectF"
    
    def self.yaml_new cls, tag, val
      left, top, width, height= val['left'], val['top'], val['width'], 
          val['height']
      Qt::RectF.new(left.to_f, top.to_f, width.to_f, height.to_f)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          loc = Qt::Locale.c
          loc.number_options = Qt::Locale::OmitGroupSeparator
          map.add 'left', loc.to_string(left)
          map.add 'top', loc.to_string(top)
          map.add 'width', loc.to_string(width)
          map.add 'height', loc.to_string(height)
        end
      end
    end
    
    def _dump _
      loc = Qt::Locale.c
      loc.number_options = Qt::Locale::OmitGroupSeparator
      sl = loc.to_string left
      st = loc.to_string top
      sw = loc.to_string width
      sh = loc.to_string height
      "#{sl};#{st};#{sw};#{sh}"
    end
    
    def self._load str
      l, t, w, h = str.split ';'
      self.new l.to_f, t.to_f, w.to_f, h.to_f
    end
    
  end
  
  class Color
    yaml_as "tag:ruby.yaml.org,2002:Qt::Color"
    
    def self.yaml_new cls, tag, val
      r, g, b= val['red'], val['green'], val['blue']
      Qt::Color.new(r, g, b)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'red', red
          map.add 'green', green
          map.add 'blue', blue
        end
      end
    end
    
    def _dump _
      "#{red};#{green};#{blue}"
    end
    
    def self._load str
      r, g, b = str.split ';'
      self.new r.to_i, g.to_i, b.to_i
    end
    
  end
  
  class Date
    yaml_as "tag:ruby.yaml.org,2002:Qt::Date"
    
    def self.yaml_new cls, tag, val
      y, m, d = val['year'], val['month'], val['day']
      Qt::Date.new(y, m, d)
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'year', year
          map.add 'month', month
          map.add 'day', day
        end
      end
    end
    
    def _dump _
      "#{year};#{month};#{day}"
    end
    
    def self._load str
      y, m, d = str.split ';'
      self.new(y.to_i, m.to_i, d.to_i)
    end
    
  end
  
  class DateTime
    yaml_as "tag:ruby.yaml.org,2002:Qt::DateTime"
    
    def self.yaml_new cls, tag, val
      date, time, spec = val['date'], val['time'], val['time_spec']
      Qt::DateTime.new date, time, spec
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'date', date
          map.add 'time', time
          map.add 'time_spec', time_spec
        end
      end
    end
    
    def _dump _
      Marshal.dump [date, time, time_spec]
    end
    
    def self._load str
      date, time, time_spec = Marshal.load str
      self.new date, time, time_spec
    end
    
  end
  
  class Font
    yaml_as "tag:ruby.yaml.org,2002:Qt::Font"
    
    def self.yaml_new cls, tag, val
      res = Qt::Font.new
      res.from_string val
      res
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.scalar taguri, to_string, :plain
      end
    end
    
    def _dump _
      to_string
    end
    
    def self._load str
      res = Qt::Font.new
      res.from_string str
      res
    end
    
  end
  
  class Time
    yaml_as "tag:ruby.yaml.org,2002:Qt::Time"
    
    def self.yaml_new cls, tag, val
      if val['valid']
        Qt::Time.new val['hours'], val['minutes'], val['seconds'], val['msec']
      else Qt::Time.new
      end
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.add 'valid', valid?
          if valid?
            map.add 'hours', hour
            map.add 'minutes', minute
            map.add 'seconds', second
            map.add 'msec', msec
          end
        end
      end
    end
    
    def _dump _
      if valid? then "#{hour};#{minute};#{second};#{msec}"
      else ""
      end
    end
    
    def self._load str
      if str.empty? then self.new
      else
        h, m, s, ms = str.split ';'
        self.new h.to_i, m.to_i, s.to_i, ms.to_i
      end
    end
    
  end
  
  class Url
    yaml_as "tag:ruby.yaml.org,2002:Qt::Url"
    
    def self.yaml_new cls, tag, val
      Qt::Url.new val
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.scalar taguri, to_string, :plain
      end
    end
    
    def _dump _
      to_string
    end
    
    def self._load str
      self.new str
    end
    
  end
  
  class StandardItemModel

    include QtEnumerable

=begin rdoc
If given a block, calls it once for each top level item. This means that items
in the same row but in different columns will each cause a separate block execution.

If a block isn't given, returns an +Enumerator+ which does the same as above.
=end
    def each
      if block_given?
        rowCount.times do |i|
          columnCount.times do |j| 
            it = item(i,j)
            yield it if it
          end
        end
      else self.to_enum
      end
    end

=begin rdoc
If given a block, calls it once for each top level row, passing it an array containing
the items in the row. If the number of columns varies from row to row, the arrays
corresponding to the ones with less items will have *nil* instead of the missing
items.

If a block isn't given, returns an +Enumerator+ which does the same as above.
=end
    def each_row
      if block_given?
        rowCount.times do |r|
          a = [] 
          columnCount.times{|c| a << item(r, c)}
          yield a
        end
      else self.to_enum(:each_row)
      end
    end

  end

  class SortFilterProxyModel
    
    include QtEnumerable

=begin rdoc
 Calls the block for each top-level item
=end
    def each
      rowCount.times do |r|
        columnCount.times{|c| yield index(r,c)}
      end
    end

  end

  class StandardItem

    include QtEnumerable

=begin rdoc
 Iterates on all child items. If no block is given, returns an Enumerator

 <b>Note: </b>this method iterates only on those items which are directly child
 of +self+; it's not recursive.
=end
    def each
      if block_given?
        rowCount.times do |i|
          columnCount.times do |j|
            c = child i, j
            yield c if c
          end
        end
      else self.to_enum
      end
    end
    
=begin rdoc
Passes an array containing the items in each of the children rows. Returns an
Enumerator if called without a block
=end
    def each_row
      if block_given?
        rowCount.times do |i|
          a = []
          columnCount.times{|j| a << child( i,j)}
          yield a
        end
      else to_enum
      end
    end

    # Returns true if the check state is <tt>Qt::Checked</tt> or <tt>Qt::PartiallyChecked</tt>
    def checked?
      check_state != Qt::Unchecked
    end

# Returns *true* if the check_state is <tt>Qt::Checked</tt> and *false* otherwise
    def fully_checked?
      self.check_state == Qt::Checked
    end

=begin rdoc
 Sets the check state to <tt>Qt::Unchecked</tt> if _value_ is +false+ or +nil+
 and to <tt>Qt::Checked</tt> otherwise
=end
    def checked= value
      self.check_state = (value ? Qt::Checked : Qt::Unchecked)
    end

  end

  class Variant
    
    def to_sym
      to_string.to_sym
    end
    
=begin rdoc
Redefinition of <tt>to_bool</tt> it's needed because otherwise the Object#to_bool
method defined in <tt>facets/boolean</tt> is used, instead of calling method_missing.

By explicitly define a <tt>to_bool</method> and having it call <tt>method_missing</tt>,
the problem is solved
=end
    def to_bool
      method_missing :to_bool
    end
    
  end
  
  class MetaObject
    
    def each_signal
      if block_given?
        method_count.times do |i|
          m = method i
          yield m if m.method_type == Qt::MetaMethod::Signal
        end
      else self.enum_for(:each_signal)
      end
    end
    
    def each_slot
      if block_given?
        method_count.times do |i|
          m = method i
          yield m if m.method_type == Qt::MetaMethod::Slot
        end
      else self.enum_for(:each_slot)
      end
    end
    
    def each_method
      if block_given?
        method_count.times{|i| yield method i}
      else self.enum_for(:each_method)
      end
    end
    
  end
  
=begin rdoc
Module implementing the {#each} method used by all layout classes

Ideally, this method should be implemented in {Qt::Layout} and other classes should
inherit it. However, since QtRuby doesn't actually implements inheritance between
it's classes, that doesn't happen.

The {#each} method is then defined in this module which is included in all layout
classes
=end
  module LayoutEach
    
    include QtEnumerable
    
=begin rdoc
Iterates on all items in the layout

The iteration order is from top to bottom and from left to right. In case of widgets
which span multiple rows or columns (in case of a @Qt::GridLayout@), the widgets
will only be passed one time.

@yield [w] block to call for each widget in the layout
@yieldparam [Qt::Widget] w each widget
@return [Qt::Layout,Enumerator] if no block is given, returns an enumerator, otherwise
  returns *self*
=end
    def each
      return to_enum unless block_given?
      count.times do |i| 
        it = item_at i
        yield it.widget || it.layout
      end
      self
    end
    
  end
  
  class Layout
    include LayoutEach
  end
  
  class BoxLayout
    include LayoutEach
  end
  
  class VBoxLayout
    include LayoutEach
  end
  
  class HBoxLayout
    include LayoutEach
  end
  
  class StackedLayout
    include LayoutEach
  end
  
  class FormLayout
    include LayoutEach
  end
  
  class GridLayout
    include LayoutEach
  end
  
  class Qt::Splitter
    
    include QtEnumerable
  
=begin rdoc
Iterates on all items in the splitter

The iteration order is from top to bottom and from left to right.

@yield [w] block to call for each widget in the splitter
@yieldparam [Qt::Widget] w each widget
@return [Qt::Splitter,Enumerator] if no block is given, returns an enumerator, otherwise
  returns *self*
=end
    def each
      return to_enum unless block_given?
      count.times{|i| yield widget(i)}
      self
    end
    
  end
  
  
  class Qt::StackedWidget
   
    include QtEnumerable
    
=begin rdoc
Calls the block for each widget in the stack, or returns an enumerator if no block
is given
=end
    def each
      if block_given?
        count.times{|i| yield widget(i)}
      else to_enum
      end
    end
    
    def empty?
      self.count == 0
    end
    
  end
  
end

=begin rdoc
Qt::StandardItemModel-derived class which allow to set flags for all the items.
To do so, simply set the global_flags attribute to the desired flags.
=end
class GlobalFlagStandardItemModel < Qt::StandardItemModel
  
=begin rdoc
The flags which should be returned by every call to flags.
=end
  attr_accessor :global_flags
  
=begin rdoc
Creates a new GlobalFlagStandardItemModel. The global_flags attribute for the new
model will be set to nil. This means that the flags method will behave exactly as
the Qt::StandardItemModel#flags method.
=end
  def initialize parent = nil
    super
    @global_flags = nil
  end
  
=begin rdoc
Returns the flags associated with the index _idx_. If returns the value contained
in the global_flags attribute if it is not nil, otherwise it will call
Qt::StandardItemModel#flags and return that value
=end
  def flags idx
    @global_flags || super
  end
  
end