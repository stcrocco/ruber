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

require 'ruber/yaml_option_backend'

module Ruber
  
=begin rdoc
Backend for SettingsContainer used by the project class. It is similar to YamlSettingsBackend,
except for the fact that it produces three files instead of one: one only contains
options of type +:global+ (and is referred to as the <i>project file</i>),
another one contains only options of type +:user+ and
the last contains only options of type +:session+
=end
  class ProjectBackend
    
=begin rdoc
Associates each option type (+:global+, +:user+ and +:session+) with the extension
of the file where those options will be stored
=end
    EXTENSIONS = {:global => '.ruprj', :user => '.ruusr', :session => '.ruses'}
    
=begin rdoc
Creates a new ProjectBackend. <i>file</i> is the name of the project file. The
name of the file for the user options and the session options is obtained by
appending the appropriate extension to the project file:
* +.ruusr+ for the user options file
* +.ruses+ for the session options file
If _file_ has the +.ruprj+ extension, that extension will be removed before
adding the extensions above. If it has any other extension (or no extension at
all), they'll be kept.

For example, if _file_ is <tt>/home/stefano/xyz.ruprj</tt>, the other two files
will be <tt>/home/stefano/xyz.ruusr</tt> and <tt>/home/stefano/xyz.ruses</tt>.
Instead, if _file_ is <tt>/home/stefano/xyz.abc</tt>, the other two files
will be <tt>/home/stefano/xyz.abc.ruusr</tt> and <tt>/home/stefano/xyz.abc.ruses</tt>

If either the file for the global or the user options already exists but doesn't
have the correct format, <tt>YamlSettingsBackend::InvalidSettingsFile</tt> will be
raised. If the same happens for the session options file, instead, a warning
will be emitted, default values will be used for the session options and they
will never be saved to file.
=end
    def initialize file
      @backends = {}
      base_file = file.sub(/#{EXTENSIONS[:global]}$/, '')
      @backends[:global] = YamlSettingsBackend.new file
      @backends[:user] = YamlSettingsBackend.new base_file + EXTENSIONS[:user]
      @backends[:session] = begin YamlSettingsBackend.new base_file + EXTENSIONS[:session]
      rescue YamlSettingsBackend::InvalidSettingsFile
        warn "The file #{base_file + '.ruses'} already exists but it's not a valid session file. Session options won't be saved"
        YamlSettingsBackend.new ''
      end
    end
    
=begin rdoc
Returns the path of the file were the global options are stored
=end
    def file
      @backends[:global].file
    end
    
=begin rdoc
Returns the value of the option described by the option object _opt_
(see SettingsContainer#add_option).

The value will be retrieved from the backend corresponding to the type of the option
=end
    def [] opt
      @backends[opt.type][opt]
    end
    
=begin rdoc
Writes the options _opts_ back to disk. The options contained in _opts_ will be
grouped according to their types and the appropriate backend will be used to
save each group.
=end
    def write opts
      options = {:global => {}, :user => {}, :session => {}}
      opts.each{|k, v| options[k.type][k] = v}
      @backends[:global].write options[:global]
      @backends[:user].write options[:user]
      @backends[:session].write options[:session] unless @backends[:session].file.empty?
    end
    
  end
  
end