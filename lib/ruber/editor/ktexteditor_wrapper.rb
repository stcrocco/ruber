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

require 'facets/string/camelcase'

module Ruber

=begin rdoc
Module which abstracts some common functionality of Document and EditorView due
to the fact that both are mostly simply wrappers around two +KTextEditor+ classes.

Throught this documentation, the KTextEditor::Document or KTextEditor::View corresponding
to the object will be referred to as the <i>wrapped object</i>.

In particular, this class:
* provide a way to access methods provided by the different interfaces implemented
  by the wrapped object without directly accessing it (using InterfaceProxy)
* redirect to the wrapped object any method call the object itself doesn't respond
  to
* provide a (private) method to access the wrapped object
* provide some automatization in the process having the object emit an appropriate
  signal when the wrapped object emits a signal.
=end
  module KTextEditorWrapper
    
=begin rdoc
Helper class which, given a Qt::Object implementing different interfaces, allows
to access method provided by one interface without exposing the object itself.
=end
    class InterfaceProxy
      
=begin rdoc
Creates a new InterfaceProxy. _obj_ is the <tt>Qt::Object</tt> to cast to the
appropriate interface
=end
      def initialize obj
        @obj = obj
        @interface = nil
      end
      
=begin rdoc
Sets the interface to which the object is going to be cast. _iface_ can be either
the name of an interface, as symbol or string, both in camelcase or snakecase
(withouth the +KTextEditor+ namespace) or the class itself. After a call to this
method (and until the next one) <tt>method_missing</tt> will redirect all unknown
method calls to this interface.
=end
      def interface= iface
        cls = if iface.is_a? Class then iface
        else
          name = iface.to_s.split('_').map(&:capitalize).join ''
          KTextEditor.const_get(name)
        end
        @interface = @obj.qobject_cast cls
      end
      
=begin rdoc
Passes the method call to the object cast to the current interface. If the argument
list contains instances of classes which mix-in KTextEditorWrapper, they're replaced
with the object they wrap before being passed to the interface.
=end
      def method_missing name, *args, &blk
        args.map!{|a| a.is_a?(KTextEditorWrapper) ? a.send(:internal) : a}
        @interface.send name, *args, &blk
      end
      
    end
    
=begin rdoc
Makes easier having the object emit a signal in corrispondence with
signals emitted by the wrapped object. In particular, this method does the following
(for each signal given in the arguments):
* creates a signal for the object based on the name of the signal in the wrapped
  object
* creates a slot for the object with a name obtained from the name of the signal, which takes
  the same arguments as the signal in the wrapped object and emits the associated
  signal of the object. The arguments of the emitted signal are taken from those
  passed to the slot, but they can be reordered. Also, *self* can be specified
* returns a hash suitable to be passed as second argument to <tt>initialize_wrapper</tt>.
Usually, this method is called when the class is created and the returned hash
is stored in a class instance variable. The class's +initialize+ method then passes
it as second argument to <tt>initialize_wrapper</tt>.

_cls_ is the class for which signals and slots will be defined. _data_ is a hash
containing the information for the signal and slot to create.
* its keys are the names of the signals converted to snakecase. This name will be
  converted to camelcase to obtain the name of the signal of the wrapped object,
  while will be used as is for the signal of the object.
* its values are arrays. The first element is the signature of the signal of the
  wrapped object. The second element is an array of integers and *nil*s. An integer
  _i_ in the position _n_ of the array means that the _n_th argument of the new
  signal will be the _i_th argument of the signal of the wrapped object (both 
  indexes start from 0). If the array contains *nil* in position _n_, the _n_th
  argument of the new signal will be *self* (in the signature of the new signal,
  this will mean <tt>QWidget*</tt> if _cls_ derives from <tt>Qt::Widget</tt> and
  <tt>QObject*</tt> otherwise).
=end
    def self.prepare_wrapper_connections cls, data
      res = {}
      data.each_pair do |name, d|
        old_args = d[0].split(/,\s*/)
        new_args = d[1].map do |i| 
          if i then old_args[i]
          elsif cls.ancestors.include?(Qt::Widget) then 'QWidget*'
          else 'QObject*'
          end
        end
        new_args = new_args.join ', '
        new_signal = "#{name}(#{new_args})"
        old_signal = "#{name.camelcase :lower}(#{d[0]})"
        slot_name = "__emit_#{name}_signal(#{d[0]})"
        cls.send :signals, new_signal
        cls.send :slots, slot_name
        res[old_signal] = slot_name
        method_def = <<-EOS
def __emit_#{name}_signal(#{old_args.size.times.map{|i| "a#{i}"}.join ', '})
  emit #{name}(#{d[1].map{|i| i ? "a#{i}" : 'self'}.join ', '})
end
EOS
        cls.class_eval method_def
      end
      res
    end
    
=begin rdoc
Returns an InterfaceProxy set to the interface _name_. See <tt>InterfaceProxy#interface=</tt>
for the possible values for _name_. It is meant to be used this way (supposing
_doc_ is an object which wraps <tt>KTextEditor::Document</tt>)
  doc.interface(:modification_interface).modified_on_disk_warning = true
=end
    def interface name
      @_interface.interface = name
      @_interface
    end
    
=begin rdoc
Forwards the method call to the wrapped object
=end
    def method_missing name, *args, &blk
      begin super
      rescue NoMethodError, NameError, NotImplementedError
        @_wrapped.send name, *args, &blk
      end
    end
  
    private
    
=begin rdoc
Method which needs to be called before using any of the functionality provided by
the module (usually, it's called from +initialize+). _obj_ is the wrapped object,
while _signals_ is a hash as described in <tt>connect_wrapped_signals</tt>.

It creates an InterfaceProxy for the wrapped object and calls <tt>connect_wrapped_signals</tt>
passing _signals_ as argument.
=end
    def initialize_wrapper obj, signals
      @_interface = InterfaceProxy.new obj
      @_wrapped = obj
      connect_wrapped_signals signals
    end
    
=begin rdoc
Returns the wrapped object (this method is mainly for internal use)
=end
    def internal
      @_wrapped
    end
   
=begin rdoc
Makes a connections between a series of signals and of slots. _signals_ is a hash
whose keys are the names of the signals and whose entries are the slots each signal
should be connected to (only one slot can be connected to each signal). You can't
connect a signal to another signal with this method.

This method is mainly meant to be used in conjunction with <tt>prepare_wrapper_connections</tt>.
=end
    def connect_wrapped_signals signals
      signals.each_pair do |k, v|
        connect @_wrapped, SIGNAL(k), self, SLOT(v)
      end
    end
    
  end
  
end