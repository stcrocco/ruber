=begin 
    Copyright (C) 2011 by Stefano Crocco   
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
require 'ruber/world/document_factory'
require 'ruber/world/project_factory'
require 'ruber/world/environment'
require 'ruber/world/project_list'
require 'ruber/world/document_list'
require_relative 'ui/workspace_settings_widget'

module Ruber
  
  module World
    
    class World < Qt::Object

=begin rdoc
Exception raised from {Ruber::World::World#new_project} when the given file already
  exists
=end
      class ExistingProjectFileError < StandardError
      end

      include PluginLike
      
      attr_reader :default_environment
      
      attr_reader :active_environment
      
      signals 'active_environment_changed(QObject*)'
      
      signals 'active_environment_changed_2(QObject*, QObject*)'
      
      signals 'active_project_changed(QObject*)'
      
      signals 'active_project_changed_2(QObject*, QObject*)'
      
      signals 'document_created(QObject*)'
      
      signals 'project_created(QObject*)'
      
      signals 'project_closing(QObject*)'
      

=begin rdoc
@param [ComponentManager] manager the component manager (unused)
@param [PluginSpecification] psf the plugin specification object associated with
  the component
=end
      def initialize manager, psf
        super manager
        @documents = MutableDocumentList.new []
        @projects = MutableProjectList.new []
        @environments = {}
        
        initialize_plugin psf
        @document_factory = DocumentFactory.new self
        connect @document_factory, SIGNAL('document_created(QObject*)'), self, SLOT('slot_document_created(QObject*)')
        @project_factory = ProjectFactory.new self
        connect @project_factory, SIGNAL('project_created(QObject*)'), self, SLOT('slot_project_created(QObject*)')
        @default_environment = environment nil
      end
      
      def environment prj
        env = @environments[prj] 
        unless env
          env = Environment.new(prj)
          connect env, SIGNAL('closing(QObject*)'), self, SLOT('environment_closing(QObject*)')
          @environments[prj] = env
        end
        env
      end
      
      def active_environment= env
        return if @active_environment == env
        old = @active_environment
        old.deactivate if old
        @active_environment = env
        emit active_environment_changed(env)
        emit active_environment_changed_2(env, old)
        @active_environment.activate if @active_environment
      end
      
      def environments
        @environments.values
      end
      
      def each_environment
        if block_given? 
          @environments.each_value{|e| yield e}
          self
        else to_enum(:each_environment)
        end
      end
      
      def active_project= prj
        old = @active_environment.project if @active_environment
        return old if old == prj
        old.deactivate if old
        self.active_environment = @environments[prj]
        emit active_project_changed prj
        emit active_project_changed_2 prj, old
        prj.activate if prj
      end
      
      def active_project
        @active_environment.project if @active_environment
      end
      
      def projects
        ProjectList.new @environments.keys.compact
      end
      
      def each_project
        if block_given?
          @environments.each_key{|prj| yield prj if prj}
          self
        else self.to_enum(:each_project)
        end
      end
      
=begin rdoc
Creates a new document
@return [Document] the new document. It will be a child of *self*
=end
      def new_document
        doc = @document_factory.document nil, self
        doc
      end
      
=begin rdoc
The document associated with the given file or URL

If a document for the given file or URL already exists, that document will be
returned, otherwise a new one will be created.

@param [String,KDE::Url] file the absolute name or the URL of the
file to retrieve the document for
@return [Document,nil] a document associated with _file_ and having *self* as parent.
  If _file_ represents a local file and that file doesn't exist, *nil* is returned
=end
      def document file
        @document_factory.document file, self
      end
      
      def documents
        DocumentList.new @documents
      end
      
      def each_document
        if block_given?
          @documents.each{|doc| yield doc}
          self
        else self.to_enum :each_document
        end
      end
      
      def active_document
        @active_environment.active_document if @active_environment
      end
      
=begin rdoc
Creates a new project
@param [String] file the absolute path of the project file
@param [String] name the name of the project
@return [Project] a new project having _file_ as project file and _name_ as project
  name
@raise [ExistingProjectFileError] if a file called _file_ already exists (regardless
  of whether it's a valid project file or not)
=end
      def new_project file, name
        raise ExistingProjectFileError, "#{file} already exists" if File.exist?(file)
        @project_factory.project file, name
      end
   
=begin rdoc
Retrieves the project associated with a given project file

If a project associated with the project file _file_ already exists, that project
is returned. Otherwise, a new project object is created.

@param [String] file the absolute path of the project file. Note that this file
  *must* already exist and be a valid project file
@return [Project] a project associated with _file_
@raise [AbstractProject::InvalidProjectFile] if the project file is not a valid
  project file
=end
      def project file
        @project_factory.project file
      end
      
      private
      
      def environment_closing env
        @environments.delete env.project
        self.active_environment = nil if @active_environment == env
      end
      slots 'environment_closing(QObject*)'
      
      def slot_document_created doc
        @documents.add doc
        doc.connect(SIGNAL('closing(QObject*)')){|doc| @documents.remove doc}
        emit document_created(doc)
      end
      slots 'slot_document_created(QObject*)'
      
      def slot_project_created prj
        @projects.add prj
        connect prj, SIGNAL('closing(QObject*)'), self, SLOT('slot_project_closing(QObject*)')
        environment prj
        emit project_created(prj)
      end
      slots 'slot_project_created(QObject*)'
      
      def slot_project_closing prj
        emit project_closing(prj)
        @projects.remove prj
      end
      slots 'slot_project_closing(QObject*)'
      
      def load_settings
        tabs_closable = Ruber[:config][:workspace, :close_buttons]
        @environments.each_value{|e| e.tab_widget.tabs_closable = tabs_closable}
      end
      slots :load_settings
      
    end
    
    class WorkspaceSettingsWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::WorkspaceSettingsWidgetBase.new
        @ui.setup_ui self
      end
      
    end
    
  end
  
end