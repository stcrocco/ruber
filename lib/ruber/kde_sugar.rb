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
require 'facets/boolean'

require_relative 'qt_enumerable'

module KDE
  
  class Url
    
    yaml_as "tag:ruby.yaml.org,2002:KDE::Url"
    
    def self.yaml_new cls, tag, val
      KDE::Url.new val
    end
    
=begin rdoc
Tells whether a string looks like an url pointing to a file

An url is considered to _look like_ an url pointing to a file if it contains a
scheme part and an authority part, that is, if it starts with a scheme followed
by two slashes.

If _abs_only_ is *true*, this method returns *true* only if the file path is absolute,
that is if the scheme is followed by three slashes. If _abs_only_ is *false*, it'll
return *true* for both absolute and relative paths.
@param [String] str the string to test
@param [Boolean] abs_only whether this method should return *true* only if the path
  is absolute or also for relative paths
@return [Boolean] *true* if _str_ looks like an URL pointing to a file (or pointing
  to an absolute file if _abs_only_ is *true*) and *false* otherwise
=end
    def self.file_url? str, abs_only = false
      slash_number = abs_only ? 3 : 2
      str.match(%r|[\w+.-]+:/{#{slash_number},3}|).to_b
    end
    
    def to_yaml opts = {}
      YAML.quick_emit(self, opts) do |out|
        out.scalar taguri, to_encoded.to_s, :plain
      end
    end
    
    def _dump _
      to_encoded.to_s
    end
    
    def self._load str
      self.new str
    end
    
    def local_file?
      scheme == "file"
    end
    
    def remote_file?
      !(local_file? or relative?)
    end
    
=begin rdoc
@return [Boolean] *true* if the two URLs are equal according to @==@ and *false*
  otherwise
=end
    def eql? other
      self == other
    end
    
=begin rdoc
Override of Object#hash
@return [Integer] the hash value of the path associated with the URL
=end
    def hash
      path.hash
    end
    
  end

  class TabWidget

    include QtEnumerable

    def empty?
      count == 0
    end

    def each
      count.times{|i| yield widget( i )}
    end
    alias_method :each_widget, :each

    alias_method :tabs, :to_a

  end

  class ConfigGroup

    include QtEnumerable
  
    def each_key
      key_list.each{|k| yield k}
    end
    alias_method :each, :each_key

  end

  class IconLoader
    
    def self.load_pixmap name, hash = {}
      args = {:null_icon => true, :group => Small, :size => 0, :state => DefaultState, :overlays => []}
      args.merge! hash
      pix = global.load_icon name, args[:group], args[:size], args[:state],
args[:overlays], nil, args[:null_icon]
    end

    def self.load_mime_type_pixmap name, hash = {}
      args = {:group => Small, :size => 0, :state => DefaultState, :overlays => []}
      args.merge! hash
      pix = global.load_mime_type_icon name, args[:group], args[:size], args[:state],
args[:overlays], nil
    end

    def self.load_icon name, hash = {}
      pix = load_pixmap name, hash
      Qt::Icon.new pix
    end

    def self.pixmap_path name, group = Small, allow_null = true
      global.icon_path name, group, allow_null
    end

  end

  class ListWidget

    include QtEnumerable
    
    def each
      count.times{|i| yield item(i)}
    end

  end
  
  class CmdLineArgs

    def files
      res = []
      count.times{|i| res << ::File.expand_path(arg(i))}
      res
    end
    
    def urls
      count.times.inject([]) do |res, i|
        u = arg i
        url = KDE::Url.new u
        url.path = File.expand_path(u) if url.protocol.empty?
        res << url
      end
    end
    
  end
  
  class InputDialog
    
    DEFAULT = {:value => '', :parent => nil, :validator => nil, :mask => '',
               :whats_this => '', :completion_list => []}
    
    def self.get_text caption = '', label = '', args = {}
      args = DEFAULT.merge args
      getText caption, label, args[:value], nil, args[:parent], args[:validator],
          args[:mask], args[:whats_this], args[:completion_list]
    end
    
  end
  
  class XMLGUIClient
    
=begin rdoc
  Changes the GUI state _state_, by calling KDE::XMLGUIClient#stateChanged. If
  _value_ is a true value, stateChanged will be called with KDE::XMLGUIClient::StateNoReverse,
  if it is *false* or *nil*, it will be called with KDE::XMLGUIClient::StateReverse.
  
  Returns KDE::XMLGUIClient::StateNoReverse or KDE::XMLGUIClient::StateReverse,
  depending on which argument was passed to stateChanged
=end
    def change_state state, value
      value = value ? StateNoReverse : StateReverse
      stateChanged(state, value)
      value
    end
    
=begin rdoc
  Changes the GUI state _state_, by calling KDE::XMLGUIClient#stateChanged. If
  _value_ is a true value, stateChanged will be called with KDE::XMLGUIClient::StateNoReverse,
  if it is *false* or *nil*, it will be called with KDE::XMLGUIClient::StateReverse.
  
  Unlike change_state, this method recursively changes the state of child clients,
  calling their global_change_state method, if defined, or their stateChanged method
  otherwise.
=end
    def global_change_state state, value
      res = change_state state, value
      child_clients.each do |c| 
        if c.respond_to? :global_change_state then c.global_change_state state, value
        else c.send :stateChanged, state, res
        end
      end
      res
    end
    
  end
  
  class MimeType
    
=begin rdoc
Compares *self* with the string _str_. The comparison works as follows:
* if _str_ doesn't start with <tt>!</tt> or <tt>=</tt>, it works as
  <tt>KDE::MimeType#is</tt>
* if _str_ starts with <tt>!</tt>, returns the oppsite of <tt>KDE::MimeType#is</tt>
* if _str_ starts with <tt>=</tt>, makes an exact match between _str_ and <tt>self.name</tt>
* if _str_ starts with <tt>!=</tt> or <tt>=!</tt>, makes an exact match and inverts
  it
=end
    def =~ str
      str = str.sub(/^([!=]{0,2})/, '')
      case $1
      when '!' then !(self.is str)
      when '=' then self.name == str
      when '!=', '=!' then !(self.name == str)
      else self.is str
      end
    end
    
  end
  
  class Application
    
=begin rdoc
Executes the block between calls to <tt>set_override_cursor</tt> and 
<tt>restore_override_cursor</tt>. The override cursor used is _cursor_.

This method returns the value returned by the block
=end
    def self.with_override_cursor cursor = Qt::Cursor.new(Qt::WaitCursor)
      begin
      set_override_cursor cursor
      res = yield
      ensure restore_override_cursor
      end
      res
    end
    
=begin rdoc
The same as KDE::Application.with_override_cursor
=end
    def with_override_cursor cursor = Qt::Cursor.new(Qt::WaitCursor), &blk
      KDE::Application.with_override_cursor cursor, &blk
    end
    
  end
  
  class ComboBox
    
    include QtEnumerable
    
=begin rdoc
Returns an array containing the text of all items in the combo box
=end
    def items
      count.times.map{|i| item_text(i)}
    end
    
=begin rdoc
Calls the block for each item. If no block is given, returns an +Enumerator+ which
does the same
=end
    def each &blk
      blk ? items.each(&blk) : items.each
    end
    
  end

end

