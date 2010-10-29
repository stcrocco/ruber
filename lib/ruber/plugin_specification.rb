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


  class PluginSpecification < OpenStruct
    
    class PSFError < StandardError
      attr_accessor :file
    end
    
    class << self
      alias_method :intro, :new
    end
    
    def self.full file, dir = nil
      res = self.new file, dir
      res.complete_processing
      res
    end
    
    attr_reader :directory
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
    end
    
    def intro_only?
      @intro_only
    end

    def has_config_options?
      raise "Ruber::PluginSpecification#has_config_options? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !config_options.empty?
    end

    def has_tool_widgets?
      raise "Ruber::PluginSpecification#has_tool_widgets? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !tool_widgets.empty?
    end

    def has_config_widgets?
      raise "Ruber::PluginSpecification#has_config_widgets? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !config_widgets.empty?
    end
    
    def has_project_options?
      raise "Ruber::PluginSpecification#has_project_options? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !project_options.empty?
    end
    
    def has_project_widgets?
      raise "Ruber::PluginSpecification#has_project_widgets? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !project_widgets.empty?
    end
    
    def has_extensions?
      raise "Ruber::PluginSpecification#has_extensions? can only be called on a full "\
          "Ruber::PluginSpecification" if @intro_only
      !extensions.empty?
    end
    
    def complete_processing
      @reader.process_pdf @data
      @intro_only = false
    end
    
  end
  
end
