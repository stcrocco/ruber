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

require 'facets/kernel/deep_copy'

module Ruber

=begin rdoc
Backend for <tt>SettingsContainer</tt> which writes the options to a YAML file,
as a nested hash, where the outer hash contains the groups and each inner hash,
which represents a group, contains the options. Here's an example of the YAML
file produced by this class.

 :group1:
  :opt1: value1
  :opt2: value2
  :opt3: value3
 :group2:
  :opt1: value4
  :opt4: value5
 :group3:
  :opt5: value6
=end
  class YamlSettingsBackend
    
=begin rdoc
Exception raised when attempted to parse an invalid YAML file
=end
    class InvalidSettingsFile < StandardError
    end

=begin rdoc
Creates a new YamlSettingsBackend corresponding to the YAML file with name _file_.
If the file exists, it's parsed and the content is stored internally in a hash.
If it doesn't exist, the object is initialized with a new hash.

If the file exists but isn't a valid YAML file, or if it doesn't contain a toplevel
hash, InvalidSettingsFile is raised. In this case, however, the object will be
fully initialized (with an empty hash) before the exception is raised. This means
that a class deriving from YamlSettingsBackend which wants to ignore errors due to
an invalid project file can simply do the following:

class CustomSettingsBackend < Ruber::Yaml::SettingsBackend

 def initialize file
  begin super
  rescue Ruber::YamlSettingsBackend::InvalidSettingsFile
  end
 end
 
end
 
This way

 CustomSettingsBackend.new('/path/to/invalid_file')
 
will return an option backend fully initialized. (This happens because of how
Class.new works: the object is first allocated, then its initialize method is called
and the object is returned. If an exception raised by initialize is rescued within
the initialize method, Class.new will never notice something went wrong and still
return the allocated object)
=end
    def initialize file
      @filename = file
      if File.exist? file
        @data = begin YAML.load(File.read(file))
        rescue ArgumentError => e
          @data = {}
          raise InvalidSettingsFile, e.message
        end
        unless @data.is_a? Hash
          @data = {}
          raise InvalidSettingsFile, "The file #{file} isn\'t a valid option file"
        end
      else @data = {}
      end
    end
    
=begin rdoc
The name of the file associated with the backend. Note that there's no warranty
the file actually exists.
=end
    def file
      @filename
    end

=begin rdoc
Returns the option corresponding to _opt_. _opt_ is an option object with
the characteristics specified in SettingsContainer#add_option. If an option with
the same name and value of _opt_ isn't included in the internal hash, the option
default value will be returned
=end
    def [] opt
      grp = @data.fetch(opt.group){return opt.default.deep_copy}
      grp.fetch(opt.name, opt.default)
    end

=begin rdoc
Writes the options back to the YAML file (creating it if needed). _options_ is a
hash with option objects as keys and the corresponding values as entries. There
are two issues to be aware of:
* if one of the options in _options_ has a value which is equal to its default
  value, it won't be written to file
* _options_ is interpreted as only containing the options which might have changed:
  any option contained in the internal hash but not in _options_ is written back
  to the file unchanged.
  
After having written the new options back to file, the internal hash is updated
=end
    def write options
      new_data = compute_data options
      File.open(@filename, 'w'){|f| f.write YAML.dump(new_data)}
      @data = new_data
    end
    
    private
    
=begin rdoc
Creates a hash with the options to be written to file. See +write+ for a more detailed
description of how this happens
=end
    def compute_data options
      new_data = Hash.new{|h, k| h[k] = {}}
      removed = []
      options.each_pair do |k, v|
        if v != k.default then new_data[k.group][k.name] = v
        else removed << [k.group, k.name]
        end
      end
      @data.each_pair do |grp, data|
        data.each_pair do |opt, val|
          unless removed.include?([grp, opt])
            new_data[grp][opt] ||= val
          end
        end
      end
      new_data
    end
    
  end
  
end