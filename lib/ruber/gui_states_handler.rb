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
Module which provides a mechanism to enable/disable actions basing on whether
some 'states' are *true* or *false*. This functionality is similar to that provided
by the KDE XML GUI framework, but much more flexible.

A state is simply a string to which a *true* or *false* value is associated. For
example, the value associated with a state called <tt>"current_document_modified"</tt>
should be set to *true* whenever the current document becomes modified and to
*false* when it's saved. Through the rest of this documentation, the expression
<i>the value of the state</i> will mean <i>the true or false value associated with
the state</i>.

The system works this way: an action
is registered using the <tt>register_action_handler</tt> method. To do
so, a block (called a _handler_) and a list of states the action depends on are
supplied.

The value of a state is modified using the <tt>change_state</tt> method. That method
will call the handlers of every action depending on the changed state, passing it
a list of all known states, and enables or disable them according to the value
returned by the block.

Whenever this module is included in a class derived from <tt>Qt::Object</tt>, it
will define a signal with the following signature <tt>ui_state_changed(QString, bool)</tt>,
which will be emitted from the <tt>state_changed</tt> method. The signal won't be
defined if the module _extends_ an object (even if it is <tt>Qt::Object</tt>).

<b>Note:</b> before using any of the functionality provided by this module, you
must call the <tt>initialize_states_handler</tt> method. This is usually done in
the +initialize+ method of the including class.
=end
  module GuiStatesHandler

    Data = Struct.new :action, :handler, :extra_id #:nodoc:

=begin rdoc
Override of +Module#included+ which is called whenever the module is included in
another module or class.

If _other_ is a class derived from <tt>Qt::Object</tt>, it defines the <tt>ui_state_changed(QString, bool)</tt>
signal.
=end
    def self.included other
      super
      other.send :signals, 'ui_state_changed(QString, bool)' if other.ancestors.include?(Qt::Object)
    end

=begin rdoc
Makes an action known to the system, telling it on which states it depends and
which handler should be used to decide whether the action should be enabled or
not.

_action_ is a <tt>Qt::Action</tt> or derived object. _states_ is an array of strings
and/or symbols or a single string or symbol. Each string/symbol represents the
name of a state _action_ depends on (that is, a state whose value concurs in
deciding whether _action_ should be enabled or not).

_blk_ is the handler associated with _action_. It takes a single argument, which
will be a hash having the names of the states as keys and their values as values,
and returns a true value if, basing on the values of the states, _action_ should
be enabled and a false value if it shouldn't.

_option_ contains some options. One is <tt>:check</tt>: if *true*, the handler
will be called (and the action enabled or disabled) immediately after registering
it; if it's false, nothing will be done until one of the states in _states_
changes. The other option is <tt>:extra_id</tt>. If not *nil*, it is an extra value
used to identify the action (see <tt>remove_action_handler_for</tt> for more information).

If the block is not given and _states_ is a string, a symbol or an array with only
one element, then a default handler is generated (if _states_ is an array with
more than one element, +ArgumentError+ is raised). The default handler returns the
same value as the state value. If the only state starts with a <tt>!</tt>, instead,
the leading exclamation mark is removed from the name of the state and the generated
handler returns the opposite of the state value (that is, returns *true* if the
state is *false* and vice versa).

<b>Note:</b> even if states can be specified as symbols, they're actually always
converted to strings.

====Examples

In all the following examples, <tt>action_handler</tt> is an instance of a class
which includes this module.

This registers an handler for an action which depends on the two states 'a' and
'b'. The action should be enabled when 'a' is *true* and 'b' is *false* or when
'a' is *false*, regardless of 'b'.

  action_handler.register_action_handler KDE::Action.new(nil), ['a', 'b'] do |states|
    if states['a'] and !states['b'] then true
    elsif !states['a'] then true
    else false
    end
  end

This registers an action depending only on the state 'a' which should be enabled
when 'a' is *true* and disabled when 'a' is *false*.

  action_handler.register_action_handler KDE::Action.new(nil), ['a'] do |states|
    states['a']
  end

Here we could also have passed simply the string 'a' as second argument. Even easier,
we could have omitted the block, relying on the default handler that would have
been generated:
  action_handler.register_action_handler KDE::Action.new(nil), 'a'

Here, still using the default handler, register an handler for an action which
depends only on the state 'a' but needs to be enabled when 'a' is *false* and
disabled when it's *true*.
  action_handler.register_action_handler KDE::Action.new(nil), '!a'
=end
    def register_action_handler action, states, options = {:check => true}, &blk
      states = Array(states)
      states = states.map &:to_s
      if !blk and states.size > 1
        raise ArgumentError, "If more than one state is supplied, a block is needed"
      elsif !blk
        if states[0].start_with? '!'
          states[0] = states[0][1..-1]
          blk = Proc.new{|s| !s[states[0]]}
        else blk = Proc.new{|s| s[states[0]]}
        end
      end
      unless action.is_a? KDE::Action
        raise TypeError, "first argument to GuiStatesHandler#register_action_handler should be a KDE::Action, instead a #{action.class} was given"
      end
      data = Data.new(action, blk, options[:extra_id])
      states.each{|s| @gui_state_handler_handlers[s.to_s] << data}
      if options[:check]
        action.enabled = blk.call @gui_state_handler_states
      end
    end

=begin rdoc
Remove the existing handlers for actions matching _action_ and <i>extra_id</i>.

_action_ may be either a <tt>Qt::Action</tt> or a string. If it is a <tt>Qt::Action</tt>,
then only the handlers for that object will be removed (actually, there usually
is only one handler).

If _action_ is a string, all handlers for actions whose
<tt>object_name</tt> is _action_ will be removed. In this case, the <i>extra_id</i>
parameter can be used narrow the list of actions to remove (for example, if there
are more than one action with the same name but different <tt>extra_id</tt>s). If
<tt>extra_id</tt> isn't *nil*, then only actions whose <tt>object_name</tt> is
_action_ and which were given an <tt>extra_id</tt> equal to <i>extra_id</i> will
be removed.
=end
    def remove_action_handler_for action, extra_id = nil
      if action.is_a? KDE::Action
        @gui_state_handler_handlers.each_value do |v|
          v.delete_if{|d| d.action.same? action}
        end
      elsif extra_id
        @gui_state_handler_handlers.each_value do |v|
          v.delete_if{|d| d.action.object_name == action and d.extra_id == extra_id}
        end
      else
        @gui_state_handler_handlers.each_value do |v|
          v.delete_if{|d| d.action.object_name == action}
        end
      end
      @gui_state_handler_handlers.delete_if{|k, v| v.empty?}
    end

=begin rdoc
Sets the value associated with the state _state_ to _value_, then calls the
handlers of all actions depending on _state_ and enables or disables them according
to the returned value. If *self* is an instance of <tt>Qt::Object</tt>, it also
emits the <tt>ui_state_changed(QString, bool)</tt> signal, passing _state_ and
_value_ (converted to bool) as arguments.

_state_ can be either a string or symbol (in this case, it'll be converted to string).
_value_ can be any value. It will be converted to *true* or *false* according to
the usual ruby rules before being used.
=end
    def change_state state, value
      state = state.to_s
      value = value.to_bool
      @gui_state_handler_states[state] = value
      @gui_state_handler_handlers[state].each do |d|
        d.action.enabled = d.handler.call @gui_state_handler_states
      end
      emit ui_state_changed state, value if self.is_a?(Qt::Object)
    end
    alias_method :set_state, :change_state

=begin rdoc
Returns the value associated with the state _name_. If the value of the state
has never been set using <tt>change_state</tt>, *nil* will be returned.
=end
    def state name
      @gui_state_handler_states[name.to_s]
    end
    alias_method :gui_state, :state

    private

=begin rdoc
Initializes the instance variables used by the module. It must be called before
any other method in the module is used.
=end
    def initialize_states_handler
      @gui_state_handler_states = {}
      @gui_state_handler_handlers = Hash.new{|h, k| h[k] = []}
    end

  end

end