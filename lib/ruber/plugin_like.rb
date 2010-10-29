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

module Ruber
  
=begin rdoc
Module providing basic functionality common to both plugin and core components.

This mainly is an helper module, used to avoid code duplication among the {Plugin}
class and the various core components ({Application}, {MainWindow} and so on which
*can't* inherit from {Plugin}). From
a logical point of view, all of the functionality provided by this module should
be in the Plugin class, instead.

*Note:* this module *MUST* only be included in classes which descend from
@Qt::Object@, otherwise it will produce crashes
=end
  module PluginLike

=begin rdoc
@return [PluginSpecification] the plugins specification object for the plugin
=end
    attr_reader :plugin_description

=begin rdoc
@return [Symbol] the internal name of the plugin
=end
    def plugin_name
      @plugin_description.name
    end
    alias component_name plugin_name
    
=begin rdoc
Does the required cleanup before the application closes.

This method is also called when the plugin is unloaded when the application is
running (for example because the user deselects it from the Choose Plugin dialog).
This happens because usually the {#unload} method needs to do all {#shutdown} does
and more. In the rare eventuality you need to do something before closing the
application which shouldn't be done when unloading the plugin, you can check
{Application#status} and see whether it's set to @:running@, which
means the plugin is being unloaded, or to @:quitting@, which means the application
is being closed.

The base class version of this method does nothing.
@return [nil]
=end
    def shutdown
    end
    
=begin rdoc
Method called before the plugin is unloaded. It is used to do any needed cleanup.

This method should be overridden by any plugin which needs to do custom cleanup,
but it's important that the base class's version of the method is called as well
(most likely _after_ the custom part).

This basic implementation does the following:
* calls {#shutdown}
* disconnects the {#load_settings} slot from the config manager
  {Config#settings_changed} signal
* removes all the options belonging to the plugin from the config manager
* removes all tool widgets belonging to the plugin from the main window
@return [nil]
=end
    def unload
      shutdown
      if Ruber[:config]
        disconnect Ruber[:config], SIGNAL('settings_changed()'), self, SLOT('load_settings()')
        @plugin_description.config_options.each_key do |g, n| 
          Ruber[:config].remove_option(g.to_sym, n)
        end
      end
      @plugin_description.tool_widgets.each do |w| 
        Ruber[:main_window].remove_tool w.name if w.name
      end
      nil
    end

=begin rdoc
Whether or not the plugin allows the application to shut down

If this method returns *false* for any plugin, the application won't be closed.

@return [Boolean] *true*. Plugins may override this method and return something else,
maybe depending on the status of the plugin itself. As an example, the Document
List component checks whether there are unsaved documents and asks the user what
to do. If the user decides not to close the appplication, the method will return
*false*.
=end
    def query_close
      true
    end

=begin rdoc
Method called at application shutdown to allow plugins to save their settings
    
Plugins which need to save some settings need to override this method, as
the base class implementation does nothing.

*Note:* the plugin system calls this method for all plugins before starting
unloading them. This means that it's absolutely safe to access other plugins'
methods, objects, options,... from here
@return [nil]
=end
    def save_settings
      nil
    end
    
=begin rdoc
The data the plugin wants to store when the application is shut down by session
management

@return [Hash] a hash containing the information which should be stored by the
session manager. The hash returned by this method is empty, so plugin which need
to store some information need to override it. Note that the hashes returned by
this method from various plugins are merged. To avoid name clashes, you should use
unique names for the keys in the hashes. The best way to do this is to return a
hash with a single key, named after the plugin, and corresponding to an inner
hash containing the information you actually need to store
@see MainWindow#query_close
@see ComponentManager#session_data
=end
    def session_data
      {}
    end

=begin rdoc
Restores the state of the plugin from session management

This method is called by the component manager when a session needs to be restored.
Plugins need to override it if they have some state which needs to be restored
(there's no need to call _super_ when overriding, since the base class method does
nothing)

@param [Hash] cfg a hash containing the keys stored in the hash returned by {#session_data}
@see ComponentManager#restore_session
@see MainWindow#readProperties
=end
    def restore_session cfg
    end
    
=begin rdoc
Performs delayed initialization

This method is called by the component manager after the plugin object has been
stored in the component manager (and thus made availlable through {Ruber.[]}).
Plugins only need to override this method (the base class version does nothing)
if something which should happen during initialization requires to access the
plugin using {Ruber.[]}
@return [nil]
=end
    def delayed_initialize
    end
    private :delayed_initialize
    
=begin rdoc
Adds the project options provided by the plugin to a project

Only the options whose rules match the project are added.
    
If one of the options
provided by the plugin (and whose rules matches the project) has already been
inserted in the project, this method can either raise an exception or ignore the
option. The first behaviour is desirable the first time the plugin's options are
added to the project, while the second is useful if this method has already been
called for the project. In the first case, the existing option most likely belongs
to another plugin, which may lead to conflict. In  the second case, instead, the
option will belong to this plugin, so there's no risk.

@param [Ruber::AbstractProject] prj the project to add the options to
@param [Boolean] forbid_existing whether to raise an exception or do nothing if
an option already exists in the project.
@raise ArgumentError if _forbid_existing_ is *true* and one of the options provided
by the plugin already exists
@return [nil]
@see Ruber::AbstractProject#match_rule?
=end
    def add_options_to_project prj, forbid_existing = true
      @plugin_description.project_options.values.sort_by{|i| i.order || 0}.each do |o|
        o = o.to_os(prj.obj_binding)
        begin prj.add_option o if prj.match_rule?(o)
        rescue ArgumentError
          raise if forbid_existing
        end
      end
      nil
    end
    
=begin rdoc
Removes the project options provided by the plugin from a project

This method can operate in two ways: it can remove from the project all the options
it provides whose rules match or don't match the project. The first behaviour is
meant to be used when the plugin is unloaded or the project is closed; the second
when the project characteristics change, to remove those options which used to
match the project but don't anymore.

@param [Ruber::AbstractProject] prj the project to remove options from
@param [Boolean] matching whether to remove only
@return [nil]
@see Ruber::AbstractProject#match_rule?
=end
    def remove_options_from_project prj, matching = true
      if matching
        @plugin_description.project_options.each_pair do |_, o|
          o = o.to_os(prj.obj_binding)
          prj.remove_option o.group, o.name if prj.match_rule? o
        end
      else
        @plugin_description.project_options.each_pair do |_, o|
          o = o.to_os(prj.obj_binding)
          if prj.has_option?(o.group, o.name) and !prj.match_rule? o
            prj.remove_option o.group, o.name
          end
        end
      end
      nil
    end
    
=begin rdoc
Adds the project widgets provided by the plugin to a project

Only the widgets matching the project will be added.

@param [Ruber::AbstractProject] prj the project to adds the widgets to
@return [nil]
=end
    def add_widgets_to_project prj
      @plugin_description.project_widgets.each do |w| 
        prj.add_widget w if prj.match_rule? w
      end
      nil
    end
    
=begin rdoc
Removes the project widgets provided by the plugin from a project

@param [Ruber::AbstractProject] prj the project to remove the widgets from
@return [nil]
=end
    def remove_widgets_from_project prj
      @plugin_description.project_widgets.each do |w| 
        prj.remove_widget w
      end
      nil
    end
    
=begin rdoc
Adds the project extensions provided by the plugin to a project

Only the extensions matching the project will be added.

If the project already has one of the extensions this method wouold add, it can
either raise an exception or ignore the
exception. The first behaviour is desirable the first time the plugin's extensions are
added to the project, while the second is useful if this method has already been
called for the project. In the first case, the existing extension most likely belongs
to another plugin, which may lead to conflict. In  the second case, instead, the
extension will belong to this plugin, so there's no risk.

@param [Ruber::AbstractProject] prj the project to add the extensions to
@param [Boolean] forbid_existing whether to raise an exception or do nothing if
an extension already exists in the project.
@raise ArgumentError if _forbid_existing_ is *true* and the project already has
one of the extension which this method would add
@return [nil]
@see Ruber::AbstractProject#match_rule?
=end
    def add_extensions_to_project prj, forbid_existing = true
      @plugin_description.extensions.each_pair do |name, o|
        unless forbid_existing
          next if prj.extension name
        end
        ext = nil
        if o.is_a? Array
          o = o.find{|i| prj.match_rule? i}
          next unless o
          ext = o.class_obj.new prj
        elsif prj.match_rule? o
          ext = o.class_obj.new prj
        end
        if ext
          ext.plugin = self
          prj.add_extension name, ext
          emit extension_added(name.to_s, prj) rescue nil
        end
      end
    end
    
=begin rdoc
Remove the extensions provided by the pluging from a project

Depending on the value of _all_, all the extensions provided by the plugin or
only the ones which dont' match the project are removed. In this case, a multi-class
extension will only be removed if the class of the extension object is the same
as the one specified in one of the entries which don't match the project.

*Note:* to decide whether an extension belongs to the plugin or not, this method
checks whether the object returned by the exension's @plugin@ method is the same
as @self@.

@param [Ruber::AbstractProject] prj the project to remove the extensions from
@param [Boolean] all whether to remove all extensions provided by the plugin or
only those which don't match the project
@return [nil]
@see Ruber::AbstractProject#match_rule?
=end
    def remove_extensions_from_project prj, all = true
      if all
        prj.each_extension.select{|_, v| v.plugin.same? self}.each do |k, _|
          emit removing_extension k.to_s, prj rescue nil
          prj.remove_extension k
          emit extension_removed k.to_s, prj rescue nil
        end
      else
        exts = @plugin_description.extensions
        prj.each_extension.select{|_, v| v.plugin.same? self}.each do |k, o|
          data = exts[k]
          data = data.find{|i| i.class_obj == o.class} if data.is_a? Array
          if !prj.match_rule? data
            emit removing_extension k.to_s, prj rescue nil
            prj.remove_extension k
            emit extension_removed k.to_s, prj rescue nil
          end
        end
      end
      nil
    end
    
=begin rdoc
Informs a project of the existance of the plugin

The base class implemenetation adds all the known project options, poject widgets and project
extensions to the project. If a plugin needs to do something fancy with projects,
it can override this method and do it from here, after calling the base class
implementation.

@param [Ruber::AbstractProject] prj the project to register with
@return [nil]
=end
    def register_with_project prj
      add_options_to_project prj, true
      add_widgets_to_project prj
      add_extensions_to_project prj, true
    end
    
=begin rdoc
Removes all traces of the plugin from a project

This method is called when the plugin is unloaded or when the project is closed
and takes care of removeing all project options, project widgets and project extensions
belonging to the plugin from the project.

If a plugin needs to do some other cleanup when removed from a project, it can
override this method and do what it needs here (usually before calling *super*)
@param [Ruber::AbstractProject] prj the project to remove the plugin from
@return [nil]
=end
    def remove_from_project prj
      remove_options_from_project prj, true
      remove_widgets_from_project prj
      remove_extensions_from_project prj, true
    end
    
=begin rdoc
Ensures that all the project options, widgets and extensions which are provided
by the plugin and match the project have been added to it and that none which
doesn't match it have been added

This method is called when one of the characteristics of the project the rules
take into account change, so that the plugin always add to the project all the
pertinent content
@param [Ruber::AbstractProject] prj the project to check
@return [nil]
=end
    def update_project prj
      remove_options_from_project prj, false
      add_options_to_project prj, false
      remove_widgets_from_project prj
      add_widgets_to_project prj
      remove_extensions_from_project prj, false
      add_extensions_to_project prj, false
    end

    private
    
=begin rdoc
Initializes the plugin

If this were a class rather than a module, this would be its initialize method.
Since this is a module, it can't have an initialize method in the sense classes
do, therefore it's up to classes including this module to call this method from
their @initialize@, before using any functionality provided by this module.

The most important things done here are (in order):
* adding the plugin to the component manager, so that it can be accessed using
{Ruber.[]}
* connects the {#load_settings} method with the {Ruber::ConfigManager configuration manager}'s
{Ruber::ConfigManager#settings_changed settings_changed} signal
* adds the options provided by the plugin to the configuration manager and loads
the settings
* creates the tool widgets provided by the plugin

*Note:* everything regarding the configuration manager is ignored  if it doesn't
exist
@return [PluginLike] *self*
=end
    def initialize_plugin pdf
      @plugin_description = pdf
      Ruber[:components].add self
      if Ruber[:config]
        connect Ruber[:config], SIGNAL(:settings_changed), self, SLOT(:load_settings)
        register_options
        load_settings
      end
      @plugin_description.tool_widgets.each{|w| create_tool_widget w}
      self
    end
    
=begin rdoc
Creates the actions provided by the plugin

Once created, the actions are stored in the @KDE::ActionCollection@ given as 
argument. If any UI handler is provided for an action in the PSF, it's registered
with the main window. If the PSF entry for an acton contains a @:slot@, a @:receiver@ and a @:signal@ entry,
a signal-slot connection is made using those parameters.

@param [KDE::ActionCollection] the action collection to add the new actions to
@return [nil]
@see #setup_action
=end
    def setup_actions coll
      @plugin_description.actions.each_value do |a|
          action = setup_action a, coll
          coll.add_action a.name, action
      end
      nil
    end
    
=begin rdoc
Applies the configuration settings

This method is called when the plugin is created and whenever the global settings
change. The base class implementation does nothing. Plugins which need to react
to changes in the global settings must reimplement it.

*Note:* this method *must* be a slot, so any class which directly includes this
module should have a line like

<code>slots :load_settings</code>
@return [nil]
=end
    def load_settings
    end
    
=begin rdoc
Adds the global options and configuration widgets provided by the plugin to the
configuration manager

It does nothing if the configuration manager hasn't as yet been created
@return [nil]
=end
    def register_options
      config = Ruber[:config]
      return unless config
      @plugin_description.config_options.values.sort_by{|o| o.order || 0}.each do |o| 
        config.add_option o.to_os(binding)
      end
      @plugin_description.config_widgets.each{|w| config.add_widget w}
      nil
    end
    
=begin rdoc
Creates a tool widget and inserts it in the main window

It uses the data contained in the PSF to find out the characteristics of the tool
widget. If the PSF contains a @var_name@ entry for the tool widget, then an
instance variable with that name will be created and set to the tool widget. If 
the PSF contains a @name@ entry for the tool widget, its @object_name@ will be
set to that value.

If the tool widget object has a @load_settings@ method, it'll be connected with
the {ConfigManager configuration manager}'s {ConfigManager#settings_changed settings_changed}
signal

@param [OpenStruct] data the data from the PSF corresponding to the tool widget
@option data [String] code (nil) a string of code which, when evaluated in the
plugin's context, returns the tool widget. At least one between this entry and
the @class_obj@ entry must be not *nil*
@option data [Class] :class_obj (nil) the class of the tool widget. Ignored if 
the @code@ entry is not *nil*At least one between this entry and
the @code@ entry must be not *nil*
@option data [String] pixmap the name of the file containing the icon to use for
the tool widget. It's mandatory
@option data [String] caption the caption for the tool widget. Mandatory
@option data [Symbol] position (:left) the side of the screen where to put the
tool widget. The values @:left@, @:right@ and @:bottom@ are valid
@return [nil]
=end
    def create_tool_widget data
      w = data.code ? eval(w, binding) : data.class_obj.new
      w.object_name = data.name if data.name
      Ruber[:main_window].add_tool data.position, w, Qt::Pixmap.new(data.pixmap), data.caption
      instance_variable_set("@#{data.var_name}", w) if data.var_name
      if w.respond_to? :load_settings and Ruber[:config]
        connect Ruber[:config], SIGNAL("settings_changed()"), w, SLOT("load_settings()")
        w.load_settings
      end
    end
    
=begin rdoc
Creates one of the actions described in the PSF

Besides creating the action and adddint it to the specified @KDE::ActionCollection@,
it registers a state handler for the action in the main window, if the PSF entry
for the action includes a @state@ entry (the plugin iself is used as @extra_id@
for the handler), and creates a signal-slot connection between
the action and the receiver specified in the @receiver@ PSF entry for the action,
provided that the @slot@ entry isn't *nil*.

@param [OpenStruct] data the structure containing the data used to create the
action
@param [KDE::ActionCollection] cool the action collection the new action belongs
to
@option data [Symbol,String,nil] standard_action (nil) if not nil, the name of the
@KDE::StandardAction@ method to call to create the action. If this entry isn't
given, the action won't be a standard action
@option data [Class] action_class (KDE::Action) the class object to instantiate
to create the action
@option data [String] text ('') the text for the action
@option data [String] help_text ('') the help text for the action
@option data [String] shortcut ('') a string representing the default shortcut
for the action
@option data [String] icon ('') the filename of the icon to use for the action
@option data [String] slot (nil) the slot to connect a signal from the action to.
If missing, no signal-slot connection is made.
@option data [String,Symbol] signal ('triggered()') the signature of the action
signal to connect to. Ignored unless the @slot@ entry is given
@option data [String] receiver ('self') a string which, when evalued in the
context of the plugin, returns the object the action should be connected to
@option data [String] state (nil) the name of a single GUI state the action depends
on. Note that this method doesn't register a state handler for multiple states
@return [KDE::Action] the newly created action
=end
    def setup_action data, coll
      action = if data.standard_action
        if data.standard_action.to_s == 'open'
          KDE::StandardAction.open nil, '', coll
        else KDE::StandardAction.send data.standard_action, nil, '', coll
        end
      else data.action_class.new coll
      end
      action.text = data.text unless data.text.empty?
      action.help_text = data.help unless data.help.empty?
      action.shortcut = data.shortcut if data.shortcut
      action.icon = Qt::Icon.new(data.icon) unless data.icon.empty?
      if data.slot
        rec = instance_eval(data.receiver)
        connect action, SIGNAL(data.signal), rec, SLOT(data.slot)
      end
      state = data.state
      if state
        Ruber[:main_window].register_action_handler action, state, :extra_id => self
      end
      action
    end
      
  end

  
end