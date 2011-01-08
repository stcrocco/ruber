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
require 'facets/kernel/deep_copy'

module Ruber

=begin rdoc
Backend for SettingsContainer which saves the options using the KDE configuration
system (namely, <tt>KDE::Config</tt>).

To allow to store values of types which the KDE configuration system can't handle
(for example, hashes or symbols), those values are converted to strings using YAML
on writing and converted back to their original values on reading. This also happens
when the value of the option and its default value are of different classes (the
reason for this is that otherwise the object would be converted to the class of 
the default value when calling <tt>KDE::ConfigGroup#read_entry</tt>).

To know which options are stored as YAML strings and which aren't, an extra option
is written to file. It's store in the "Ruber Internal" group under the "Yaml options"
key and contains a list of the options which have been stored in YAML format. Each
entry of this option has the form "group_name/option_name".

Group names and option names are converted to a more human friendly form before
being written to the file: underscores are replaced by spaces and the first letters
of all the words are capitalized.

---
TODO: it seems that writing and reading some kind of options doesn't work for the ruby bindings,
while it works in C++ (for example, fonts). To work around this, I've changed a
bit the code where the actual read and write was done. I've asked on the mailing
list about this. When I get an answer, I'll see how to better fix this.
=end
  class KDEConfigSettingsBackend
    
=begin rdoc
An array containing the classes which can be handled directly by KDE::Config.
+Array+ isn't included because whether it can be handled or not depends on its
contents.
=end
    RECOGNIZED_CLASSES = [Qt::Variant, String, Qt::Font, Qt::Point, Qt::Rect,
                          Qt::Size, Qt::Color, Fixnum, Bignum, TrueClass, FalseClass,
                          Float, Qt::DateTime, Qt::Time]
    
=begin rdoc
Creates a new KDEConfigSettingsBackend. _filename_ is the name of the file where
the options will be stored, while _mode_ is the open flag to pass to
<tt>KDE::SharedConfig#open_config</tt>. If _filename_ is not given, the global config
object is used.

<b>Note:</b> this class uses <tt>KDE::SharedConfig</tt>, rather than a regular
<tt>KDE::Config</tt>. This means that if another instance of this class is created
for the same file, they'll share the configuration object.
=end
    def initialize filename = nil, mode = KDE::Config::FullConfig
      @config = if filename then KDE::SharedConfig.open_config filename, mode
      else KDE::Global.config
      end
      yaml_options = @config.group('Ruber Internal').read_entry('Yaml options', [])
      @yaml_options = yaml_options.map{|o| o.split('/').map( &:to_sym)}
    end

=begin rdoc
Returns the option corresponding to _opt_. _opt_ is an option object with
the characteristics specified in SettingsContainer#add_option. If an option with
the same name and value of _opt_ isn't stored in the file, the option
default value will be returned
=end
    def [] opt
      grp = KDE::ConfigGroup.new @config, humanize(opt.group)
      return opt.default.deep_copy unless grp.has_key(humanize(opt.name))
      if @yaml_options.include? [opt.group, opt.name] or !recognized_value?(opt.default)
        YAML.load grp.read_entry humanize(opt.name), ''
      else
#Uncomment the following lines if the state/open_projects is read as a string
#         begin grp.read_entry humanize(opt.name), opt.default
#         rescue ArgumentError
        (grp.read_entry humanize(opt.name), Qt::Variant.from_value(opt.default)).value
#         end
      end
    end

=begin rdoc
Writes the options back to the file. _options_ is a
hash with option objects as keys and the corresponding values as entries. There
are two issues to be aware of:
* if one of the options in _options_ has a value which is equal to its default
  value, it won't be written to file
* _options_ is interpreted as only containing the options which might have changed:
  any option already in the file but not contained in _options_ is left unchanged
  
This method also updates the list of options written in YAML format, both in memory
and on file.
=end
    def write opts
      opts.each_pair do |opt, value|
        if opt.default == value
          @config.group(humanize(opt.group)).delete_entry humanize(opt.name)
          next
        elsif need_yaml? opt, value
          @config.group(humanize(opt.group)).write_entry(humanize(opt.name), YAML.dump(value))
          @yaml_options << [opt.group, opt.name]
        else
#Uncomment the following lines if the state/open_projects is written as a string
#           begin @config.group(humanize(opt.group)).write_entry(humanize(opt.name), value)
#           rescue ArgumentError
          @config.group(humanize(opt.group)).write_entry(humanize(opt.name), Qt::Variant.from_value(value))
#           end
        end
      end
      @yaml_options.uniq!
      @config.group('Ruber Internal').write_entry('Yaml options', @yaml_options.map{|i| i.join('/')})
      @config.sync
    end
    
    private

=begin rdoc
Returns the human-friendly version of the _data_ (which must be a string or symbol).
This is obtained by replacing all underscores with spaces and capitalizing the
first letter of each word.
=end
    def humanize data
      data.to_s.split('_').map{|s| s.capitalize}.join ' '
    end

=begin rdoc
Tells whether the object _value_ is recognized by <tt>KDE::ConfigGroup</tt>. It
returns *true* if the object's class is included in <tt>RECOGNIZED_CLASSES</tt>
or if it is an array and all its entries are of classes included in that array
and *false* otherwise.
=end
    def recognized_value? value
      if RECOGNIZED_CLASSES.include? value.class then true
      elsif value.is_a? Array then value.all?{|v| RECOGNIZED_CLASSES.include? v.class}
      else false
      end
    end
    
=begin rdoc
Tells whether the value _value_ for the option represented by the option object
_opt_ needs to be stored using YAML or not. In particular, this returns *true*
if the value can't be handled by <tt>KDE::ConfigGroup</tt> or if the class of _value_
and that of the default value of the option differ (except in the case when one
is *true* and the other is *false*) and *false* otherwise.
=end
    def need_yaml? opt, value
      if !recognized_value? value then return true
      elsif value.class == opt.default.class then return false
      elsif value.bool? and opt.default.bool? then return false
      else return true
      end
    end
    
  end
  
end