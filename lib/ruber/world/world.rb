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

=begin rdoc
@param [ComponentManager] manager the component manager (unused)
@param [PluginSpecification] psf the plugin specification object associated with
  the component
=end
      def initialize manager, psf
        super manager
        initialize_plugin psf
        @document_factory = DocumentFactory.new self
        @project_factory = ProjectFactory.new self
      end
      
=begin rdoc
Creates a new document
@return [Document] the new document. It will be a child of *self*
=end
      def new_document
        @document_factory.document nil, self
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
      
    end
    
  end
  
end