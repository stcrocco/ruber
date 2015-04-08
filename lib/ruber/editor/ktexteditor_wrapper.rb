=begin 
    Copyright (C) 2010-2012 by Stefano Crocco   
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
Module which abstracts some common functionality of {Document} and {EditorView} due
to the fact that both are mostly simply wrappers around two @KTextEditor@ classes.

Throught this documentation, the @KTextEditor::Document@ or @KTextEditor::View@
corresponding to the object will be called the _wrapped object_.

In particular, this class:
* provide a way to access methods provided by the different interfaces implemented
  by the wrapped object without directly accessing it (using {InterfaceProxy})
* redirect to the wrapped object any method call the object itself doesn't respond
  to
* provide a (private) method to access the wrapped object
* provide some automatization in the process having the object emit an appropriate
  signal when the wrapped object emits a signal.
=end
  module KTextEditorWrapper
    
=begin rdoc
Helper class which, given a @Qt::Object@ implementing different interfaces, allows
to access method provided by one interface without exposing the object itself.

@example
  proxy = Proxy.new doc #doc is an instance of KTextEditor::Document
  proxy.interface = KTextEditor::ModificationInterface
  proxy.modified_on_disk_warning = true
=end
    class InterfaceProxy
      
=begin rdoc
@param [Qt::Object] obj the @Qt::Object@ to cast to the various interfaces
=end
      def initialize obj
        @obj = obj
        @interface = nil
      end
      
=begin rdoc
Sets the interface to which the object is going to be cast
@param [Class,String,Symbol] iface the name of the interface to cast the object
  to. If a string or symbol, it must be the name of one of the interfaces contained
  in the @KTextEditor@ namespace (without the @KTextEditor@). They can be given
  either in snakecase or camelcase format
@raise [NameError] if a string or symbol is given as argument but it doesn't
  correspond to a constant in the @KTextEditor@ namespace
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
Forwards the method call to the interface object

Any argument which is a @KTextEditorWrapper@ is replaced by the value returned
by its {#internal} method before being used as argument.

@param [String,Symbol] name the name of the method to be called
@param [<Object>] args the arguments passed to the original method
@param [Proc,nil] blk any block passed to the original method
@return [Object] the value returned by the method called on the interface
=end
      def method_missing name, *args, &blk
        args.map!{|a| a.is_a?(KTextEditorWrapper) ? a.send(:internal) : a}
        @interface.send name, *args, &blk
      end
      
    end
    
=begin rdoc
Makes easier having the object emit a signal in response to
signals emitted by the wrapped object.
    
For each signal passed as argument, this method does the following:
* creates a signal for the object based on the name of the signal in the wrapped
  object
* creates a slot for the object with a name obtained from the name of the signal, which takes
  the same arguments as the signal in the wrapped object and emits the associated
  signal of the object. The arguments of the emitted signal are taken from those
  passed to the slot, but they can be reordered. Also, *self* can be specified
* returns a hash suitable to be passed as second argument to {#initialize_wrapper}.

Usually, this method is called when the class is created and the returned hash
is stored in a class instance variable. The class's @#initialize@ method then passes
it as second argument to {#initialize_wrapper}.

@param [Class] cls the class signals and slot will be defined in
@param [{String => (String, <Integer,nil>)}] data a hash matching the signals
  of the wrapped class with those to define for the wrapper class. The keys are
  the names of the signals in the wrapped class converted to snakecase (which
  will be used as names for the signals in the wrapper class).
  
  The first element in each value is the signature of the signal in the wraped
  class. The second element is an array describing the arguments of the signal
  in the wrapper class. If this array has the number _i_ in position _n_, it
  means that the _n_th argument of the signal of the wrapper object is the
  _i_th argument of the wrapped object. A value of *nil* at position _n_ means
  that the _n_th argument of the wrapper signal is *self* (this means that in the
  signature, @QWidget*@ or @QObject*@ will be used for this argument, according
  to whether the class is a widget or not).
@return [Hash] a hash to be passed as second argument to {#initialize_wrapper}
@note calling this method won't define any signal on the wrapper class. You'll
  have to do that yourself. It does, however, define slots which will emit those
  signals
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
Casts the wrapped object to an interface

@param (see InterfaceProxy#interface=)
@return [InterfaceProxy] a proxy interface for the wrapped object cast to the
  given interface
@example
  # assume that doc is an instance of Ruber::Document
  doc.interface(:modification_interface).modified_on_disk_warning = true
  
=end
    def interface name
      @_interface.interface = name
      @_interface
    end
    
=begin rdoc
Forwards the method call to the wrapped object

@param [String,Symbol] name the name of the method to be called
@param [<Object>] args the arguments passed to the original method
@param [Proc,nil] blk any block passed to the original method
@return [Object] the value returned by the method of the wrapped object
=end
    def method_missing name, *args, &blk
      begin super
      rescue NoMethodError, NameError, NotImplementedError
        @_wrapped.send name, *args, &blk
      end
    end
  
    private
    
=begin rdoc
Initializes the variables needed by the module

This method needs to be called before using any of the instance methods provided
by the module (usually, it's called from the @#initialize@ method of the wrapper
object, after calling @super@ and creating the wrapped object).
@param [Qt::Object] obj the wrapped object
@param signals (see KTextEditorWrapper#connect_wrapped_signals)
@return nil
=end
    def initialize_wrapper obj, signals
      @_interface = InterfaceProxy.new obj
      @_wrapped = obj
      connect_wrapped_signals signals
      nil
    end
    
=begin rdoc
@return [Qt::Object] the wrapped object
=end
    def internal
      @_wrapped
    end
   
=begin rdoc
Automatically connects signals of the wrapped object to slots in the wrapper
object

This method is mainly meant to be used in conjunction with <tt>prepare_wrapper_connections</tt>.

@param [{String => String}] signals a hash matching signals of the wrapped object
  (the keys) to slots of the wrapper objects (the values). Each signal can be
  connected only to one slot
@return [nil]
=end
    def connect_wrapped_signals signals
      signals.each_pair do |k, v|
        connect @_wrapped, SIGNAL(k), self, SLOT(v)
      end
      nil
    end
    
  end
  
end