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
require 'ruber/settings_container'
require 'ruber/yaml_option_backend'
require 'ruber/kde_config_option_backend'

module Ruber

=begin rdoc
Class which provides easy access to the KDE::Config for the application using the
SettingsContainer module and the KDEConfigSettingsBackend classes.

Almost all the functionality of this class comes is provided by the SettingsContainer
module, so see its documentation for more information.

===Signals
<tt>settings_changed</tt>::
  signal emitted whenever the settings changed (actually, this signal is currently
  emitted whenever the +write+ method is called. Since this usually happens when
  the settings have changed, there's not a big difference).
=end
  class ConfigManager < Qt::Object

    include PluginLike
    
    include SettingsContainer

    slots :load_settings
    
    signals :settings_changed

=begin rdoc
  Creates a new +ConfigManager+. <i>_manager</i> is the component manager 
  (it is unused, but it's required by the plugin loading system). _pdf_ is the
  PluginSpecification related to this component
=end
    def initialize _manager, pdf
      super()
      initialize_plugin pdf
      setup_container KDEConfigSettingsBackend.new
      self.dialog_title = 'Configure Ruber'
    end
    
=begin rdoc
Override of SettingsContainer#write which emits the <tt>settings_changed</tt> signal
after writing back the settings.
=end
    def write
      super
      emit settings_changed
    end

=begin rdoc
Returns the configuration object. In theory, this shouldn't been needed, but it's
provided for those few cases when it's needed.
=end
    def kconfig
      @backend.instance_variable_get :@config
    end

  end

end
