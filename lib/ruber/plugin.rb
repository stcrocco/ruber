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

require 'ruber/plugin_like'

module Ruber
  
=begin rdoc
Base class for all plugins
  
Most of its functionality comes from the included {PluginLike} module.
=end
  class Plugin < Qt::Object
    
=begin rdoc
A map between the license symbols used in the PSF and the @KDE::AboutData@ licenses
constants
=end
    LICENSES = {
      :unknown => KDE::AboutData::License_Unknown,
      :gpl => KDE::AboutData::License_GPL,
      :gpl2 => KDE::AboutData::License_GPL_V2,
      :lgpl => KDE::AboutData::License_LGPL,
      :lgpl2 => KDE::AboutData::License_LGPL_V2,
      :bsd => KDE::AboutData::License_BSD,
      :artistic => KDE::AboutData::License_Artistic,
      :qpl => KDE::AboutData::License_QPL,
      :qpl1 => KDE::AboutData::License_QPL_V1_0,
      :gpl3 => KDE::AboutData::License_GPL_V3,
      :lgpl3 => KDE::AboutData::License_LGPL_V3
      }
    
=begin rdoc
Signal emitted after an extension has been added

@param [String] name the name of the extension
@param [Qt::Object] ext the extension object itself
=end
    signals  'extension_added(QString, QObject*)'
    
=begin rdoc
Signal emitted before removing an extension

@param [String] name the the name of the extension being removed
@param [Qt::Object] ext the extension object being removed
=end
    signals 'removing_extension(QString, QObject*)'
    
=begin rdoc
Signal emitted after removing an extension

@param [String] name the the name of the removed extension
@param [Qt::Object] ext the removed extension object
=end    
    signals 'extension_removed(QString, QObject*)'
    
    slots 'load_settings()'
    
    include PluginLike

=begin rdoc
Creates a new instance

This method takes care of calling the {#initialize_plugin} method required by
the {PluginLike} module

@param [Ruber::PluginSpecification] psf the plugin specification object associated
with the plugin
=end
    def initialize psf
      super(Ruber[:app])
      initialize_plugin psf
    end
    
=begin rdoc
Creates a @KDE::AboutData@ object for the plugin

*Note:* every time this method is called, a new @KDE::AboutData@ object is created

@return [KDE::AboutData] a @KDE::AboutData@ containing information about the plugin,
taken from the PSF
=end
    def about_data
      about = @plugin_description.about
      app_name = @plugin_description.name.to_s
      version = @plugin_description.version
      license = @plugin_description.about.license
      license_key, license_text =
      if about.license.is_a? String then [KDE::AboutData::License_Custom, about.license]
      else [LICENSES[about.license], nil]
      end
      res = KDE::AboutData.new app_name, '', KDE.ki18n(about.human_name), version, 
          KDE.ki18n(about.description), license_key
      res.license_text = KDE.ki18n(license_text) if license_text
      @plugin_description.about.authors.each do |a|
        res.add_author KDE.ki18n(a[0]), KDE.ki18n(''), Qt::ByteArray.new(a[1] || '')
      end
      res.bug_address = Qt::ByteArray.new(about.bug_address) unless about.bug_address.empty?
      res.copyright_statement = KDE.ki18n(about.copyright) unless about.copyright.empty?
      res.homepage = Qt::ByteArray.new(about.homepage) unless about.homepage.empty?
      res.program_icon_name = about.icon unless about.icon.empty?
      res
    end

  end
  
=begin rdoc
Base class for all plugins which provide a GUI (that is, menu or toolbar entries).
=end
  class GuiPlugin < Plugin
    
=begin rdoc
Creates an instance and initializes the GUI
@param [Ruber::PluginSpecification] psf the plugin specification object associated
with the plugin
=end
    def initialize psf
      super
      @gui = KDE::XMLGUIClient.new Ruber[:main_window]
      @gui.send :set_XML_file, psf.ui_file
# TODO when the KDE::ComponentData which takes a KDE::AboutData constructor
# works, construct the KDE::ComponentData using the value returned by the about_data
# method. As the following lines are (hopefully) temporarily, I only add the minimum
# to make the plugins show correctly in the shortcuts editor dialog.
      @gui.component_data = KDE::ComponentData.new Qt::ByteArray.new(plugin_name.to_s)
      data = @gui.component_data.about_data
      data.program_name = KDE.ki18n(@plugin_description.about.human_name)
      setup_actions
      Ruber[:main_window].factory.add_client @gui
    end
    
=begin rdoc
Removes the GUI provided by this plugin from the application's GUI
@return [nil]
=end
    def unload
      @gui.factory.remove_client @gui
      super
    end
    
=begin rdoc
@return [KDE::ActionCollection] the action collection used to contain the plugin's actions
=end
    def action_collection
      @gui.action_collection
    end
    
=begin rdoc
Executes the action with a given name, if it belongs to the plugin's action collection

To execute the action, this method first checks whether it is included in the @actions@
entry of the PSF. If so, then the associated slot is directly called, passing 
_<notextile>*</notextile>args_ as argument. If the action is not included in that entry, then
the action object is forced to emit a signal according to its class: @toggled(bool)@
for a @KDE::ToggleAction@, @triggered()@ for a @KDE::Action, and
@triggered(*args)@ for all other actions.

If a plugin needs a different behaviour, for example because the slot connected to
the action uses @Qt::Object.sender@, and thus can only be called from a
signal, you'll need to override this method and have the action emit the signal.
To do so, you can use the following code:

bc.

a = action_collection.action(name)
a.instance_eval{emit signal_name(arg)}
 
where @name@ is the name of the action, @signal_name@ is the name of the
signal to emit and @arg@ is the argument of the signal (you can pass more
than one argument, if needed).

If the slot is called directly, _args_ are the arguments to be passed to the slot.
If the signal is emitted, _args_ are the arguments passed to the signal.

*Note:* emitting the signal can (in rare cases) have unwanted results. This
can happen if there are more than one slot connected to the signal, in which case
all of them will be called. Usually, this shouldn't be an issue since it's common
to connect only one signal to each action, but it can happen. This is why this
method prefers to call the slot directly, whenever possible.

@param [String,Symbol] name the name of the action to execute
@param [<Object>] args the arguments to pass to the slot or the signal
@return [Boolean] *true* if an action called _name_ was found and *false* otherwise
=end
    def execute_action name, *args
      data = plugin_description.actions[name.to_s]
      if data
        slot = data.slot.sub(/\(.*/, '')
        instance_eval(data.receiver).send slot, *args
        true
      elsif (action = action_collection.action(name))
        if action.class == KDE::ToggleAction then KDE::ToggleAction
          action.instance_eval{emit toggled(*args)}
        elsif action.class == KDE::Action 
          action.instance_eval{emit triggered()}
        else action.instance_eval{emit triggered(*args)}
        end
        true
      else false
      end
    end
    

    private
    
=begin rdoc
Override of {PluginLike#setup_actions}

It works as the base class method but doesn't need the action collection
@return [nil]
=end
    def setup_actions
      super @gui.action_collection
    end
    
=begin rdoc
Registers an UI action handler with the main window

It works like {GuiStatesHandler#register_action_handler} but doesn't require to specify
neither the plugin (which will be *self*) nor the action object, which will be retrieved
from the plugin's action collection nor the states which are taken from the @states@
entry of the PSF entry corresponding to the action

*Note:* to use this method, the action description in the PSF must include the
@states@ entry (the @state@ entry isn't used).

@param [String] name the name of the action for which the action handler is registered
@param [Boolean] check whether or not the state of the action should be checked
when the action handler is registered
@param [Proc] blk the block to call when one of the states the action depends on
changes
@return [nil]
@see GuiStatesHandler
=end
    def register_action_handler name, check = true, &blk
      action = @gui.action_collection.action name
      states = @plugin_description.actions[name].states
      if action
        Ruber[:main_window].register_action_handler action, states, :check => check, :extra_id => self, &blk
      end
      nil
    end

    
  end
    
end
