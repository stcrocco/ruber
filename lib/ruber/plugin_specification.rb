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

require 'yaml'
require 'ostruct'
require 'facets/kernel/constant'

require 'ruber/plugin_specification_reader'

module Ruber

=begin rdoc
Class containing information about a plugin

The information is grouped in two part: a header part and a details part. While
the header part is availlable for all plugins, the details part is only availlable
for plugins which have been loaded.

@!method name
  @return [Symbol] the internal name of the plugin

@!method type
  The type of plugin

  @return [Symbol] the type of the plugin. It can have one of the values:
    @:core@, @:library@, @:global@, @:project@

@!method about
  @return [OpenStruct] information about the plugin to be displayed to the user

@!method version
  @return [String] the version of the plugin

@!method required
  @return [<String>] a list of files to require before attempting to load the
    plugin

@!method features
  @return [<Symbol>] a list of the features provided by the plugin

@!method deps
  @return [<Symbol>] a list of the features the plugin needs to load

@!method runtime_deps
  @return [<Symbol>] a list of the features the plugins needs to run

  @note Currently the value returned by this method is not used

@!method class_obj
  @return [Class,nil] the class of the new plugin

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method ui_file
  The GUI RC file used by the plugin

  @return [String, nil] the GUI RC file used by the plugin or *nil* if the plugin
    doesn't provide a GUI

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method tool_widgets

  @return [Array] objects describing the tool widgets provided by the plugin

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method config_widgets

  @return [Array] objects describing the config widgets provided by the plugin

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method config_options
  The configuration options provided by the plugin

  @return [{(Symbol, Symbol) => Object}] the
    configuration options provided by the plugin

    The keys are made by the pair @(group, name)@; the values are objects describing
    the option

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*


@!method project_options
  The project options provided by the plugin

  @return [{(Symbol, Symbol) => Object}] the project options provided by the plugin

    The keys are made by the pair @(group, name)@; the values are objects describing
    the option

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method project_widgets

  @return [Array] objects describing the project widgets provided by the plugin

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method extensions
  The extensions provided by the plugin

  @return [{Symbol => Object}] objects describing the extensions provided by
    the plugin

    The keys are the names of the extensions while the values are the objects
    descibing them

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*

@!method actions
  The actions provided by the plugin

  @return [{Symbol => Object}] objects describing the actions provided by the
    plugin. The keys are the names of the actions, while the values are the
    objects themselves

  @note If this method is called for plugins which haven't been loaded, it
    returns *nil*
=end
  class PluginSpecification < OpenStruct
    class PSFError < StandardError
      attr_accessor :file
    end

=begin rdoc
Creates a new instance containing both intro and details reading from a file

@overload PluginSpecification.full file
  @param [String] the path of the plugin specification file

@overload PluginSpecification.full data, dir = nil
  @param [Hash] data a hash containing the data
  @param [String] dir the directory where the plugin specification file is. If
    *nil*, the current directory will be used

@return [PluginSpecification] the new instance
=end
    def self.full file, dir = nil
      res = self.new file, dir
      res.complete_processing
      res
    end

=begin rdoc
Create a new instance containing only the intro readig from a file
@overload PluginSpecification.intro file
  @param [String] the path of the plugin specification file

@overload PluginSpecification.intro data, dir = nil
  @param [Hash] data a hash containing the data
  @param [String] dir the directory where the plugin specification file is. If
    *nil*, the current directory will be used
@return (see .full)
=end
    def self.intro file, dir = nil
      new
    end
    
=begin rdoc
@return [String] the directory where the plugin is
=end
    attr_reader :directory

=begin rdoc
The object describing the position of the plugin in the dependency tree

@return [Dependent::Solution,nil] the solution object describing true dependencies
  of the plugin. It returns *nil* if the plugin hasn't been loaded
=end
    attr_accessor :solution

=begin rdoc
@overload initialize file
  @param [String] the path of the plugin specification file

@overload initialize data, dir = nil
  @param [Hash] data a hash containing the data
  @param [String] dir the directory where the plugin specification file is. If
    *nil*, the current directory will be used
=end
    def initialize arg, dir = nil
      super()
      @directory = if dir then dir
      elsif arg.is_a? String then File.dirname arg
      else File.expand_path Dir.pwd
      end
      @intro_only = true
      @reader = PluginSpecificationReader.new self
      @data = arg.is_a?(Hash) ? arg : YAML.load( File.read(arg) )
      @reader.process_pdf_intro @data
      @solution = nil
    end
    
=begin rdoc
@return [Boolean] whether this instance only contains the intro part or not
=end
    def intro_only?
      @intro_only
    end

=begin rdoc
@return [Boolean] whether or not there are configuration options

@raise RuntimeError if called on an instance containing only the introduction
=end
    def has_config_options?
      raise "Ruber::PluginSpecification#has_config_options? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !config_options.empty?
    end

=begin rdoc
@return [Boolean] whether or not there are tool widgets

@raise RuntimeError if called on an instance containing only the introduction
=end
    def has_tool_widgets?
      raise "Ruber::PluginSpecification#has_tool_widgets? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !tool_widgets.empty?
    end


=begin rdoc
@return [Boolean] whether or not there are configuration widgets

@raise RuntimeError if called on an instance containing only the introduction
=end
    def has_config_widgets?
      raise "Ruber::PluginSpecification#has_config_widgets? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !config_widgets.empty?
    end

=begin rdoc
@return [Boolean] whether or not there are project options

@raise RuntimeError if called on an instance containing only the introduction
=end
    def has_project_options?
      raise "Ruber::PluginSpecification#has_project_options? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !project_options.empty?
    end
    
=begin rdoc
@return [Boolean] whether or not there are project widgets

@raise RuntimeError if called on an instance containing only the introduction
=end
    def has_project_widgets?
      raise "Ruber::PluginSpecification#has_project_widgets? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !project_widgets.empty?
    end
    
=begin rdoc
@return [Boolean] whether or not there are extensions

@raise RuntimeError if called on an instance containing only the introduction
=end
    def has_extensions?
      raise "Ruber::PluginSpecification#has_extensions? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !extensions.empty?
    end

=begin rdoc
Reads the details part of the PSF from the file

@return [void]
=end
    def complete_processing
      @reader.process_pdf @data
      @intro_only = false
    end
    
  end
  
end
