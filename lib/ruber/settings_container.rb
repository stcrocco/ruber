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

require 'pathname'
require 'facets/basicobject'

require 'ruber/settings_dialog'

module Ruber

=begin rdoc
Module which allows including classes to store and retrieve settings and provides
an interface (but not the implentation, which is a backend's job) to write the
settings to a file. It's
a part of the <a href="../file.settings_framework.html">Ruber Settings Framework</a>

Settings are divided into groups, and each settings has a name, so any of them
can be accessed using the @[group, name]@ pair. Each group can contain multiple
settings, obviously all with different names (of course, you can have settings
with the same name in different groups).

To read or write a setting, you must first add it, using the {#add_setting} method.
This method takes what we call a _settings object_, that is an object describing
a setting. Among other things, a setting object provides information about the name
of the setting, the group it belongs to and the default value, that is the value
to use for the setting if the user hasn't changed it.

The user can change the value of the settings added to a container using the dialog
returned by the {#dialog} method. This dialog is a sublcass of @KDE::PageDialog@,
to which plugins can add the widgets needed to change their settings (see {#add_widget}).
The dialog is only created when the {#dialog} method is called and is destroyed
every time a widget is added or removed to it.

This module knows nothing about the way the data is stored to file, so it needs
a backend to do the reading/writing. Refer to
"the ruber settings framework documentation":../file.settings_framework.html#backends
for the interface a backend class must provide.

*Notes:*
* classes mixing-in this module *must* call {#setup_container} before using the
functionality it provides. Usually, this can be done from the class's @initialize@
method
* the values of the options in the backend aren't updated when they are changed
using the []= method, but only when the {#write} method is called.
* if you want to store a value of a custom class in a settings file, make sure
you require the file the class is defined in before _creating_ the instance of
@SettingsContainer@ associated with the configuration file (not before accessing
it). This is because some backends (for example the YAML backend) create all the
objects stored in it on creation


h3. Instance variables

There are some instance variables which classes mixing-in this module may set
to tune the behaviour of the module. They are:
* @@base_dir@: this variable can be set to a path to use as base for settings
representing a relative path. For example, if this variable is set to @/home/myhome/@,
a setting with value @/home/myhome/somefile@ will be stored simply as @somefile@
* @@dialog_class@: the class to instantiate to create the dialog. It must be a
subclass of {Ruber::SettingsDialog}. If this variable isn't set, {Ruber::SettingsDialog}
will be used.

@todo Change all names referring to "option" to use the word "setting" instead
@todo Replace instance variables used by classes mixing-in this (for example, @dialog_class)
with method calls which may be overridden
=end
  module SettingsContainer
    
=begin rdoc
Utility class to be used to avoid having to repeat the group
when fetching options from a {SettingsContainer}. When created, it takes a {SettingsContainer}
and a group name as parameters. To access one option in that group, you can simply
call the {#[]} and {#[]=} methods specifying the option name (and, in the second case,
the value). Alternatively, you can use the option names as if they were method
names (appending an equal sign to store values)

Note that you don't usually need to create instances of this class, as {SettingsContainer#[]}
returns one when called with one argument.

@example Without using Proxy:

  o1 = settings_container[:group1, :o1]
  o2 = settings_container[:group1, :o2]
  o3 = settings_container[:group1, :o3]
  o4 = settings_container[:group1, :o4, :abs]
  settings_container[:group1, :o1] = 1
  settings_container[:group1, :o2] = 2
  settings_container[:group1, :o3] = 3
  settings_container[:group1, :o4] = 4
  
@example Using {Proxy#[]} and {Proxy#[]}:

  proxy = settings_container[:group1]
  o1 = proxy[:o1]
  o2 = proxy[:o2]
  o3 = proxy[:o3]
  o4 = proxy[:o4, :abs]
  proxy[:o1] = 1
  proxy[:o2] = 2
  proxy[:o3] = 3
  proxy[:o4] = 4
  
@example Using Proxy via {#method_missing}

  proxy = settings_container[:group1]
  o1 = proxy.o1
  o2 = proxy.o2
  o3 = proxy.o3
  o4 = proxy.o4 :abs
  proxy.o1 = 1
  proxy.o2 = 2
  proxy.o3 = 3
  proxy.o4 = 4

=end
    class Proxy < BasicObject
      
=begin rdoc
@param [SettingsContainer] container the object to create the proxy for
@param [Symbol] group the group to create the proxy for
=end
      def initialize container, group
        @container = container
        @group = group
      end
      
=begin rdoc
Calls the {#[]} method of the associated container. 

The group passed to the container's {SettingsContainer#[] #[]} method is the one
associated with the proxy.
@param [Symbol] option the second argument to {SettingsContainer#[]}
@param [Symbol,nil] option the third argument to {SettingsContainer#[]}
@return [Object] whatever {SettingsContainer#[]} returns
=end
      def [](option, path_opt = nil)
        @container[@group, option, path_opt]
      end

=begin rdoc
Calls the {#[]=} method of the associated container. 

The group passed to the container's {SettingsContainer#[]= #[]=} method is the one
associated with the proxy.
@param [Symbol] option the second argument to {SettingsContainer#[]}
@param [Object] value the third argument to {SettingsContainer#[]}
=end
      def []=(option, value)
        @container[@group, option] = value
      end
      
=begin rdoc
Attempts to read or write an option with the same name as the method

If the method name ends with a @=@, it attempts to change the value of a setting
called as the method in the group associated with the proxy. If the method doesn't
end with an @=@, it attempts to read the setting

The contents of the _args_ array are passed to the called method
@param [Symbol] meth the name of the method
@param [Array] args the parameters to pass
=end
      def method_missing meth, *args
        name = meth.to_s
        if name[-1,1] == '=' then @container.send :[]=, @group, name[0...-1].to_sym, *args
        else @container[@group, meth, *args]
        end
      end
      
    end

=begin rdoc
Adds a setting to the container

*Note:* this method also deletes the configuration dialog, so a new one will be
created the next time it's needed

@param [Object] the settings object describing the setting to add. It must have the three
following methods:
* @name@: takes no arguments and returns a symbol corresponding to the name of the setting
* @group@: takes no arguments and returns a symbol corresponding to the group the setting belongs to
* @default@: takes one argument of class @Binding@ and returns the default value
to use for the setting

If the object also has a @relative_path@ method and that method returns *true*,
then the setting will be treated a a path relative to the base directory
@raise ArgumentError if an option with the same name nad belonging to the same group
already exists
@return [nil]
=end
    def add_setting opt
      full_name = [opt.group, opt.name]
      if @known_options[full_name]
        raise ArgumentError, "An option with name #{opt.name} belonging to group #{opt.group} already exists"
      end
      @known_options[full_name] = opt
      @options[full_name] = @backend[opt]
      delete_dialog
      nil
    end
    alias add_option add_setting
    
=begin rdoc
Removes a setting

*Note:* this method also deletes the configuration dialog, so a new one will be
created the next time it's needed

@overload remove_setting group, name
  @param [Symbol] group the group the setting belongs to
  @param [Symbol] name the name of the setting to remove
  @return [nil]
  
@overload remove_setting obj
 @param [Object] see {#add_setting}
 @return [nil]
=end
    def remove_setting *args
      group, name = if args.size == 1 then [args[0].group, args[0].name]
      else args
      end
      @known_options.delete [group, name]
      @options.delete [group, name]
      delete_dialog
    end
    alias remove_option remove_setting
    
=begin rdoc
Whether a given setting has been added to the container
@param [Symbol] group the name the setting belongs to
@param [Symbol] name the name of the setting
@return [Boolean] *true* if the setting had already been added and *false* otherwise
=end
    def has_setting? group, name
      !@known_options[[group, name]].nil?
    end
    alias has_option? has_setting?

=begin rdoc
Returns the value of a setting
@overload [] group
 Returns a {Proxy} object associated with a group
 @param [Symbol] group the name of the group 
 @return [SettingsContainer::Proxy]
 
@overload [] group, name
 @param [Symbol] group the group the setting belongs to
 @param [Symbol] name the name of the setting
 @return [Object] the value of the setting. If it has never been set, the default
 value is returned

@overload [] group, name, mode
 @param [Symbol] group the group the setting belongs to
 @param [Symbol] name the name of the setting
 @param [Symbol] mode if either @:abs@ or @absolute@, and if the setting is a @string@
 or a @Pathname@, it is considered as a path relative to the base directory. The
 absolute path, obtained by joining the base directory with the value of the setting
 is then returned
 @return [Object] the value of the setting. If it has never been set, the default
 value is returned

@raise IndexError if an option corresponding to the given group and name hasn't
been added, except in the case of one argument, where the {Proxy} object is always
returned
=end
    def [](*args)
      group, name, path_opt = args
      return Proxy.new self, group unless name
      res = @options.fetch([group, name]) do
        raise IndexError, "An option called #{name} belonging to group #{group} doesn't exist"
      end
      if @base_directory and (path_opt == :abs or path_opt == :absolute)
# The call to File.expand_path is used to avoid returning names as /base/dir/.
# if the value of the options were .
        if res.is_a? String
          res = File.expand_path(File.join(@base_directory, res))
        elsif res.is_a? Pathname
          res = (Pathname.new(@base_directory) + res).cleanpath
        end
      end
      res
    end

=begin rdoc
Changes the value of a setting

If the new value is a string containing an absolute path, the corresponding
setting object has a @relative_path@ method which returns *true* and the base directory
is not *nil*, the string will be trasformed into a path relative to the base directory
before being stored.

@param [Symbol] group the group the setting belongs to
@param [Symbol] name the name of the setting
@param [Object] value the new value of the setting
@raise {IndexError} if a setting with the given name and group haven't been added
to the object
@return [Object] _value_
=end
    def []=(group, name, value)
      full_name = [group, name]
      opt = @known_options.fetch(full_name) do
        raise IndexError, "No option called #{name} and belonging to group #{group} exists"
      end
      if value.is_a? String and (opt.relative_path rescue false) and @base_directory
        path = Pathname.new value
        dir = Pathname.new @base_directory
        value = path.relative_path_from( dir).to_s rescue value
      end
      @options[full_name] = value
    end

=begin rdoc
The default value for a given setting

@param [Sybmol] group the group the setting belongs to
@param [String] the name of the setting
@return [Object] the default value for the setting, without taking into account
the value returned by the @relative_path@ method of the setting object
(if it exists)
@raise @IndexError@ if a setting with the given name and group hasn't been added
=end
    def default group, name
      opt = @known_options.fetch([group, name]) do
        raise IndexError, "No option called #{name} and belonging to group #{group} exists"
      end
      opt.default
    end
    
=begin rdoc
Whether a setting should be considered a relative path or not

@param [Sybmol] group the group the setting belongs to
@param [String] the name of the setting
@return [Boolean] *true* if the settings object corresponding to _group_ and
_name_ has a @relative_path@ method and it returns *true* and *false* otherwise
=end
    def relative_path? group, name
      @known_options[[group, name]].relative_path.to_bool rescue false
    end

=begin rdoc
Instructs the container to add a widget to the associated dialog

The widget won't be immediately added to the dialog. This method only gives the
container information about the widget to insert in the dialog. The widget itself
will only be created and inserted in the dialog when it will first be shown.

This method resets the dialog.

@param [Object] w the object describing the widget. It must have the methods documented
below
@option w [String] caption the name of the page the widget should be put into. If
  the page doesn't exist in the dialog, it will be added. Otherwise, the widget will
  be added to the one already existing in the page
@option w [Class] class_obj (nil) the class of the widget to create. The class's
  @initialize@ method must take no parameters. Either this method or the @code@
  method must not be *nil*
@option w [String] code (nil) a piece of ruby code which, when executed in the
  @TOPLEVEL_BINDING@, will return the widget to add to the dialog. Either this
  method or the @class_obje@ method must not be *nil*. If both are not *nil*, this
  method will have the precedence
@option w [String] pixmap ('') the path of the pixmap to associate to the page
@return [nil]
@see SettingsDialog#initialize
=end
    def add_widget w
      @widgets << w
      delete_dialog
      nil
    end
    
=begin rdoc
Removes a widget from the dialog

If the dialog doesn't contain the widget, nothing is done. Otherwise, the dialog
will be deleted

@param [Qt::Widget] w the widget to remove
@return [nil]
=end
    def remove_widget w
      deleted = @widgets.delete w
      delete_dialog if deleted
    end
    
=begin rdoc
The dialog associated with the container

If a dialog has already been created, it will be returned. Otherwise, another dialog
will be created and filled with the widgets added to the container

The dialog will be an instance of the class stored in the @@dialog_class@ instance
variable.
@return [Qt::Dialog] the dialog associated with the container.
@see #add_widget
@see SettingsContainer
=end
    def dialog
      @dialog ||= @dialog_class.new self, @known_options.values, @widgets, @dialog_title
    end
    
=begin rdoc
Writes the settings to file

If you need to modify the content of an option before writing (for example because
it contains a value which can only be read if a specific plugin has been loaded),
override this method and change the value of the option, then return the hash.

@return [nil]
=end
    def write
      @backend.write collect_options
      nil
    end

    private
    
=begin
@return [String] the title which will be used for the dialog
=end
    attr_reader :dialog_title

=begin rdoc
Initializes instance variables needed by this module
    
This method must be called
before any of the instance method provided by the module may be
used. Usually it's called from the constructor of the including class.

@param [Object] backend the backend to use. See "here":../file.settings_framework.html#backends
for documentation about backends
@param [String,nil] base_dir the directory all paths settings will be relative
to. If *nil*, then settings containing absolute paths will be stored as such
@raise [ArgumentError] if _base_dir_ is a string but doesn't represent a full
path (that is, it doesn't start with a @/@)
@return [nil]
=end
    def setup_container backend, base_dir = nil
      @known_options = {}
      @options = {}
      @backend = backend
      @dialog = nil
      @dialog_title = nil
      @widgets = []
      @dialog_class = SettingsDialog
      if base_dir and !base_dir.match(%r{\A/})
        raise ArgumentError, "The second argument to setup_container should be either an absolute path or nil"
      end
      @base_directory = base_dir
      nil
    end   
    
=begin rdoc
Sets the title of the dialog

This method deletes the dialog

@param [String] title the new title to give the dialog
@return [nil]
=end
    def dialog_title= title
      @dialog_title = title
      delete_dialog
      nil
    end

=begin rdoc
Deletes the dialog

After calling this method, a call to {#dialog} will cause a new dialog to be
craeated. This is used, for example, when adding a new widget to the dialog or
removing an existing one.

If the dialog hadn't already been crated, nothing is done.
@retrun [nil]
=end
    def delete_dialog
      if @dialog
        @dialog.delete_later 
        @dialog = nil
      end
    end
    
=begin rdoc
The known settings and their values

@return [Hash] a hash having the settings objects added to the container as keys
and the corresponding values as values
=end
    def collect_options
      data = {}
      @known_options.each_value{|v| data[v] = @options[[v.group, v.name]]}
      data
    end
    
  end
  
end