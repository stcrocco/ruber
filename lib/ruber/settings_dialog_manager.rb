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

require 'facets/string/snakecase'
require 'yaml'

module Ruber
  
=begin rdoc
Class which takes care of automatically syncronize (some of) the options in
an SettingsContainer with the widgets in the SettingsDialog.

In the following documentation, the widgets passed as argument to the constructor
will be called _upper level widgets_, because they're the topmost widgets
this class is interested in. The term _child widget_ will be used to refer
to any widget which is child of an upper level widget, while the generic _widget_
can refer to both. The upper _level widget corresponding to_ a widget is
the upper level widget the given widget is child of (or the widget itself if it
already is an upper level widget)

To syncronize options and widgets contents, this class looks among the upper level
widgets and their children for the widget which have an @object_name@ of the form
@_group__option@, that is: an underscore, a group name, two underscores,
an option name (both the group and the option name can contain underscores. This
is the reason for which _two_ underscores are used to separate them). Such a
widget is associated with the option with name _name_ belonging to the group
_group_.

Having a widget associated with an option means three things:
# when the widget emits some signals (which mean that the settings have changed,
   the dialog's Apply button is enabled)
# when the dialog is displayed, the widget is updated so that it displays the
   value stored in the SettingsContainer
# when the Apply or the OK button of the dialog is clicked, the option in the
   SettingsContainer is updated with the value of the widget.
   
For all this to happen, who writes the widget (or the upper level widget the widget
is child of) must give it several custom properties
(this can be done with the UI designer, if it is used to create the widget, or
by hand). These properties are:
* signal: it's a string containing the signal(s) on which the Apply button of the
  dialog will be enabled. If more than one signal should be used, you can specify
  them using a YAML array (that is, enclose them in square brackets and separate
  them with a comma followed by one space). If the widget has only a single signal
  with that name, you can omit the signal's signature, otherwise you need to include
  it (for example,  has a single signall called @textChanged@,
  so you can simply use that instead of . On the other
  hand,  has two signals called @currentIndexChanged@, so
  you must fully specify them:  or
  ).
* read: is the method to use to sync the value in the widget with that in
  the SettingsContainer. The reason of the name "read" is that it is used to
  read the value from the container.
* store: is the method to use to sync the value in the SettingsContainer with that
  in the widget.
* access: a method name to derive the @read@ and the @store@ methods from. The
  @store@ method has the same name as this property, while the @read@
  method has the same name with ending "?" and "!" removed and an ending 
  "=" added.

In the documentation for this class, the term <i>read method</i> refers to the
method specified in the @read@ property or derived from the @access@ property by
adding the  to it. The term <i>store method</i> refers to the
method specified in the @store@ or @access@ property.

If the @read@, @store@ or @access@ properties start with a dollar sign (*@$@*), they'll be called
on the upper level widget corresponding to the widget, instead than on the widget
itself.

Not all of the above properties need to be specified. In particular, the @access@
property can't coexhist the @read@ and the @store@ properties. On the other hand,
you can't give only one of the @read@ and @store@ properties. If you omit the
@access@, @store@ and @read@ property entierely, and the @signal@ property only
contains one signal, then an @access@ property is automatically created using the
name of the signal after having removed from its end the strings 'Edited', 'Changed',
'Modified', '_edited', '_changed', '_modified' (for example, if the signal is
'text()', then the @access@ property will become @text@.

If the @signal@ property hasn't been specified, a default one will be used, depending
on the class of the widgets. See the documentation for DEFAULT_PROPERTIES to see
which signals will be used for which classes. If neither the @access@ property
nor the @read@ and @store@ properties have been given, a default @access@ property
will also be used. If the class of the widget is not included in DEFAULT_PROPERTIES,
an exception will be raised.

A read method must accept one argument, which is the value of the option, and 
display it in the corresponding widget in whichever way is appropriate. A store
method, instead, should take no arguments, retrieve the option value from the widget,
again using the most appropriate way, and return it.

Often, the default @access@ method is almost, but not completely, enough. For
example, if the widget is a , but you want to store
the option as a string, instead of using a , you'd need to create
a method whose only task is to convert a   to a string and vice
versa. The same could happen with a symbol and a . To avoid
such a need, this class also performs automatic conversions, when reading or storing
an option. It works this way: if the value to store in the @SettingsContainer@ or
in the widget are of a different class from the one previously contained there,
the @DEFAULT_CONVERSIONS@ hash is scanned for an entry corresponding to the two
classes and, if found, the value returned by the corresponding @Proc@ is stored
instead of the original one.

h3. Example

Consider the following situation:

*Options:*

- an option which contains an integral value, with default 4:=
   @OpenStruct.new({:name => :number, :group => :G1, :default => 4})@=:
- an option which contains a path (as a string). The default value is the @HOME@
  environment variable:=
  @OpenStruct.new({:name => :path, :group => :G1, :default => ENV[['HOME']]})@=:
- an option which contains an array of strings, with default value @['a', 'b', 'c']@:=
  @OpenStruct.new({:name => :list, :group => :G2, :default => %w[a b c]})@=:

*Widgets:*

There's a single upper level widget, of class @MyWidget@, which contains a
@Qt::SpinBox@, a @KDE::UrlRequester@ and a @Qt::LineEdit@.
The value displayed in the spin box should be associated to the @number@
option, while the url requester should be associated to the @path@ option.
The line edit widget should be associated with the @list@ option, by splitting
the text on commas.

We can make some observations:
* the spin box doesn't need anything except having its name set to match the
   @number@ option: the default signal and access method provided by
  {DEFAULT_PROPERTIES} are perfectly adequate to this situation.
* the url requester doesn't need any special settings, aside from the object name:
  the default signal and access method provided by {DEFAULT_PROPERTIES} are
  almost what we need and the only issue is that the methods take and return a
   instead of a string. But since the {DEFAULT_CONVERSIONS}
  contains conversion procs for this pair of classes, even this is handled automatically
* the line edit requires custom @read@ and @store@ methods (which can be specified
  with a signle @access@ property), because there's no default conversion from
  array to string and vice versa. The default signal, instead, is suitable for
  our needs, so we don't need to specify one.

Here's how the class @MyWidget@ could be written (here, all widgets are created
manually. Usually, you'd use the Qt Designer to create them. In that case, you
can set the widgets' properties using the designer itself).
Note that in the constructor we make use of the block form of the widgets' constructors,
which evaluates the given block in the new widget's context.

<pre>class MyWidget < Qt::Widget
    
    def initialize parent = nil
      super
      @spin_box = Qt::SpinBox.new{ self.object_name = '_G1__number'}
      @url_req = KDE::UrlRequester.new{self.object_name = '_G1__path'}
      @line_edit = Qt::LineEdit.new do
        self.object_name = '_G2__list'
        set_property 'access', '$items'
      end
    end

  # This is the store method for the list option. It takes the text in the line
  # edit and splits it on commas, returning the array
    def items
      @line_edit.text.split ','
    end
    
  # This is the read method for the list option. It takes the array containing
  # the value of the option (an array) as argument, then sets the text of the
  # line edit to the string obtained by calling join on the array
    def items= array
      @line_edit.text = array.join ','
    end
    
  end
</pre>
=end
  class SettingsDialogManager < Qt::Object
    
=begin rdoc
A hash containing the default signal and access methods to use for a number of
classes, when the @signal@ property isn't given. The keys of the hash are the
classes, while the values are arrays of two elements. The first element is the
name of the signal, while the second is the name of the access method.
=end
    DEFAULT_PROPERTIES = {
      Qt::CheckBox => [ 'toggled(bool)', "checked?"],
      Qt::PushButton => [ 'toggled(bool)', "checked?"],
      KDE::PushButton => [ 'toggled(bool)', "checked?"],
      KDE::ColorButton => [ 'changed(QColor)', "color"],
      KDE::IconButton => [ 'iconChanged(QString)', "icon"],
      Qt::LineEdit => [ 'textChanged(QString)', "text"],
      KDE::LineEdit => [ 'textChanged(QString)', "text"],
      KDE::RestrictedLine => [ 'textChanged(QString)', "text"],
      Qt::ComboBox => [ 'currentIndexChanged(int)', "current_index"],
      KDE::ComboBox => [ 'currentIndexChanged(int)', "current_index"],
      KDE::ColorCombo => [ 'currentIndexChanged(int)', "color"],
      Qt::TextEdit => [ 'textChanged(QString)', "text"],
      KDE::TextEdit => [ 'textChanged(QString)', "text"],
      Qt::PlainTextEdit => [ 'textChanged(QString)', "text"],
      Qt::SpinBox => [ 'valueChanged(int)', "value"],
      KDE::IntSpinBox => [ 'valueChanged(int)', "value"],
      Qt::DoubleSpinBox => [ 'valueChanged(double)', "value"],
      KDE::IntNumInput => [ 'valueChanged(int)', "value"],
      KDE::DoubleNumInput => [ 'valueChanged(double)', "value"],
      Qt::TimeEdit => [ 'timeChanged(QTime)', "time"],
      Qt::DateEdit => [ 'dateChanged(QDate)', "date"],
      Qt::DateTimeEdit => [ 'dateTimeChanged(QDateTime)', "date_time"],
      Qt::Dial => [ 'valueChanged(int)', "value"],
      Qt::Slider => [ 'valueChanged(int)', "value"],
      KDE::DatePicker => [ 'dateChanged(QDate)', "date"],
      KDE::DateTimeWidget => [ 'valueChanged(QDateTime)', "date_time"],
      KDE::DateWidget => [ 'changed(QDate)', "date"],
      KDE::FontComboBox => [ 'currentFontChanged(QFont)', "current_font"],
      KDE::FontRequester => [ 'fontSelected(QFont)', "font"],
      KDE::UrlRequester => [ 'textChanged(QString)', "url"],
      KDE::EditListBox => ['changed()', 'items']
    }

=begin rdoc
Hash which contains the Procs used by @convert_value@ to convert a value
from its class to another. Each key must an array of two classes, corresponding
respectively to the class to convert _from_ and to the class to convert _to_. The
values should be Procs which take one argument of class corresponding to the first
entry of the key and return an object of class equal to the second argument of the
key.

If you want to implement a new automatic conversion, all you need to do is to
add the appropriate entries here. Note that usually you'll want to add two entries:
one for the conversion from A to B and one for the conversion in the opposite
direction.
=end
    DEFAULT_CONVERSIONS = {
      [Symbol, String] => proc{|sym| sym.to_s},
      [String, Symbol] => proc{|str| str.to_sym},
      [String, KDE::Url] => proc{|str| KDE::Url.from_path(str)},
    # KDE::Url#path_or_url returns nil if the KDE::Url is not valid, so, we use
    # || '' to ensure the returned object is a string
      [KDE::Url, String] => proc{|url| url.path_or_url || ''},
      [String, Fixnum] => proc{|str| str.to_i},
      [Fixnum, String] => proc{|n| n.to_s},
      [String, Float] => proc{|str| str.to_f},
      [Float, String] => proc{|x| x.to_s},
    }
    
    slots :settings_changed
    
    
=begin rdoc
Creates a new SettingsDialogManager. The first argument is the SettingsDialog whose
widgets will be managed by the new instance. The second argument is an array with
the option objects corresponding to the options which are candidates for automatic
management. The keys of the hash are the option
objects, which contain all the information about the options, while the values
are the values of the options. _widgets_ is a list of widgets where to look for
for widgets corresponding to the options.

When the +SettingsDialogManager+ instance is created, associations between options
and widgets are created, but the widgets themselves aren't updated with the values
of the options.
=end
    def initialize dlg, options, widgets
      super(dlg)
      @widgets = widgets
      @container = dlg.settings_container
      @associations = {}
      options.each{|o| setup_option o}
    end

=begin rdoc
Updates all the widgets corresponding to an automatically managed option by calling
the associated reader methods, passing them the value read from the option container,
converted as described in the the documentation for SettingsDialogManager, 
<tt>convert_value</tt> and <tt>DEFAULT_CONVERSIONS</tt>. It emits the
<tt>settings_changed</tt> signal with *true* as argument.
=end
    def read_settings
      @associations.each_pair do |o, data|
        group, name = o[1..-1].split('__').map(&:to_sym)
        value = @container.relative_path?(group, name) ? @container[group, name, :abs] : @container[group, name]
        old_value = call_widget_method data
        value = convert_value(value, old_value)
        call_widget_method data, value
      end
    end

=begin rdoc
Updates all the automatically managed options by calling setting them to the values
returned by the associated 'store' methods,
converted as described in the the documentation for +SettingsDialogManager+, 
<tt>convert_value</tt> and <tt>DEFAULT_CONVERSIONS</tt>. It emits the
<tt>settings_changed</tt> signal with *false* as argument.
=end
    def store_settings
      @associations.each_pair do |o, data|
        group, name = o[1..-1].split('__').map(&:to_sym)
        value = call_widget_method(data)
        old_value = @container[group, name]
        value = convert_value value, old_value
        @container[group, name] = value
      end
    end
    
=begin rdoc
It works like <tt>read_settings</tt> except for the fact that it updates the
widgets with the default values of the options.
=end
    def read_default_settings
      @associations.each_pair do |o, data|
        group, name = o[1..-1].split('__').map(&:to_sym)
        value = @container.default(group, name)
        old_value = call_widget_method data
        value = convert_value(value, old_value)
        call_widget_method data, value
      end
    end
    
    private

=begin rdoc
Looks in the list of widgets passed to the constructor and their children for a
widget whose name corresponds to that of the option (see widget_name for the meaning
of _corresponds_). If one is found, the setup_automatic_option method is called
for that option. If no widget is found, nothing is done.
=end
    def setup_option opt
      name = widget_name opt.group, opt.name
      widgets = @widgets.find! do |w|
        if w.object_name == name then [w, w]
        else
          child = w.find_child(Qt::Widget, name)
          child ? [child, w] : nil
        end
      end
      setup_automatic_option opt, *widgets if widgets
    end

=begin rdoc
Associates the widget _w_ with the option _option_. _ulw_ is the upper level
widget associated with _widget_. Associating a widget with an option means two
things:
* connecting each signal specified in the +signal+ property of the widget with
  the settings_changed slot of *self*
* creating an entry in the <tt>@associations</tt> instance variable with the name
  of the widget as key and a hash as value. Each hash has a +read+ and a +store+
  entry, which are both arrays: the second element is the name of the +read+ and
  +store+ method respectively, while the first is the widget on which it should
  be called (which will be either _widget_ or the corresponding upper level widget,
  _ulw_).
  
As explained in the documentation for this class, some of the properties may be
missing and be automatically determined. If one of the following situations happen,
+ArgumentError+ will be raised:
* no +signal+ property exist for _widget_ and its class is not in +DEFAULT_PROPERTIES+
* _widget_ doesn't specify neither the +access+ property nor the +read+ and the
  +store+ properties and more than one signal is specified in the +signal+ property
* both the +access+ property and the +read+ and/or +store+ properties are specified
  for _widget_
* the signature of one signal isn't given and it couldn't be determined automatically
  because either no signal or more than one signals of _widget_ have that name
=end
    def setup_automatic_option opt, widget, ulw
      #Qt::Variant#to_string returns nil if the variant is invalid
      signals = Array(YAML.load(widget.property('signal').to_string || '[]'))
      #Qt::Variant#to_string returns nil if the variant is invalid
      methods = %w[read store access].map{|m| prop = widget.property(m).to_string}
      if signals.empty?
        data = DEFAULT_PROPERTIES.fetch(widget.class) do
          raise ArgumentError, "No default signal exists for class #{widget.class}, you need to specify one"
        end
        signals = [data[0]]
        methods[2] = data[1] if methods == Array.new(3, nil)
      end
      signals.each_index do |i| 
        signals[i] = add_signal_signature signals[i], widget
        connect widget, SIGNAL(signals[i]), self, SLOT(:settings_changed)
      end
      data = find_associated_methods signals, methods, widget, ulw
      @associations[widget.object_name] = data
    end
    
=begin rdoc
Returns the name of the widget corresponding to the option belonging to group
_group_ and with name _name_. The widget name has the form: underscore, group,
double underscore, name. For example if _group_ is :general and _name_ is _path_,
this method would return "_general__path"
=end
    def widget_name group, name
      "_#{group}__#{name}"
    end

=begin rdoc
Returns the full signature of the signal with name _sig_ in the <tt>Qt::Object</tt>
obj. If _sig_ already has a signature, it is returned as it is. Otherwise, the list
of signals of _obj_ is searched for a signal whose name is equal to _sig_ and the
full name of that signal is returned. If no signal has that name, or if more than
one signal have that name, +ArgumentError+ is raised.
=end
    def add_signal_signature sig, obj
      return sig if sig.index '('
      mo = obj.meta_object
      reg = /^#{Regexp.quote sig}/
      signals = mo.each_signal.find_all{|s| s.signature =~ reg}
      raise ArgumentError, "Ambiguous signal name, '#{sig}'" if signals.size > 1
      raise ArgumentError, "No signal with name '#{sig}' exist" if signals.empty?
      signals.first.signature
    end
    
=begin rdoc
Finds the read and store methods to associate to the widget _widget_. It returns
an hash with keys <tt>:read</tt> and <tt>:store</tt> and for values pairs of the
form <tt>[receiver, method]</tt>, where _method_ is the method to call to read
or store the option value and _receiver_ is the object to call the method on (it
may be either _widget_, if the corresponding property doesn't begin with +$+, 
or its upper level widget, _ulw_, if the property begins with +$+).

_signals_ is an array with all the signals included in the +signal+ property of
the widget. _methods_ is an array with the contents of the +read+, +store+ and
+access+ properties, (in this order), converted to string (if one property is
missing, the corresponding entry will be *nil*). _widget_ is the widget for which
the association should be done and _ulw_ is the corresponding upper level widget.

See the documentation for <tt>setup_automatic_option</tt> for a description of
the situation on which an +ArgumentError+ exception is raised.
=end
    def find_associated_methods signals, methods, widget, ulw
      read, store, access = methods
      if access and (read or store)
        raise ArgumentError, "The widget #{widget.object_name} has both the access property and one or both of the store and read properties"
      elsif access
        read = access.sub(/[?!=]$/,'')+'='
        store = access
      elsif !access and !(store and read)
        if signals.size > 1
          raise ArgumentError, "When more signals are specified, you need to specify also the access property or both the read and store properties"
        end
        sig = signals.first
        store ||= sig[/[^(]+/].snakecase.sub(/_(?:changed|modified|edited)$/, '')
        read ||= sig[/[^(]+/].snakecase.sub(/_(?:changed|modified|edited)$/, '') + '='
      end
      data = {}
      data[:read] = read[0,1] == '$' ? [ulw, read[1..-1]] : [widget, read]
      data[:store] = store[0,1] == '$' ? [ulw, store[1..-1]] : [widget, store]
      data
    end

=begin rdoc
:call-seq:
manager.call_widget_method data
manager.call_widget_method data, value

Helper method which calls the 'read' or 'store' method for an association. If called
in the first form, calls the 'store' method, while in the first form it calls the
'read' method passing _value_ as argument. _data_ is one of the hashes contained
in the <tt>@associations</tt> instance variable as values: it has the following
form: <tt>{:read => [widget, read_method], :store => [widget, store_method]}. In
both versions, it returns what the called method returned.
=end
    def call_widget_method *args
      data = args[0]
      if args.size == 1 then data[:store][0].send data[:store][1]
      else data[:read][0].send data[:read][1], args[1]
      end
    end
  
=begin rdoc
Converts the value _new_ so that it has the same class as _old_. To do so, it looks
in the +DEFAULT_CONVERSIONS+ hash for an entry whose key is an array with the class
of _new_ as first entry and the class of _old_ as second entry. If the key is found,
the corresponding value (which is a +Proc+), is called, passing it _new_ and the
method returns its return value. If the key isn't found (including the case when
_new_ and _old_ have the same class), _new_ is returned as it is.
=end
    def convert_value new, old
      prc = DEFAULT_CONVERSIONS[[new.class, old.class]]
      if prc then 
        prc.call new
      else new
      end
    end
    
=begin rdoc
Enables the Apply button of the dialog
=end
    def settings_changed
      parent.enable_button_apply true
    end
    
  end
  
end