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

module Ruber
  
  module World
    
=begin rdoc
Class whose task is to ensure that there's only one project open for any given
project file.

To create a new project, call the {#project} method instead of using {Project}.new.
If a project for the given file already exists, it'll be returned, otherwise a
new project will be created.
=end
    class ProjectFactory < Qt::Object
      
=begin rdoc
Exception raised when the name requested for a project file is different for the
name contained in the project itself
=end
      class MismatchingNameError < StandardError
        
=begin rdoc
@return [String] the project file
=end
        attr_reader :file
        
=begin rdoc
@return [String] the requested project name
=end
        attr_reader :requested_name
        
=begin rdoc
@return [String] the project name contained in the project file
=end
        attr_reader :actual_name
        
=begin rdoc
@param [String] file the project file
@param [String] requested_name the name requested for the project
@param [String] actual_name the project name contained in the project
=end
        def initialize file, requested_name, actual_name
          @file = file
          @requested_name = requested_name
          @actual_name = actual_name
          super "A project associated with #{file} exists, but the corresponding project name is #{actual_name} instead of #{requested_name}"
        end
      end
      
=begin rdoc
@param [Qt::Object,nil] parent the parent object
=end
      def initialize parent = nil
        super
        @projects = {}
      end
      
=begin rdoc
Retrieves the project associated with a given project file

If a project associated with the project file _file_ already exists, that project
is returned. Otherwise, a new project is created.

@param (see Ruber::Project#initialize)
@return [Project] a project associated with _file_
@raise [MismatchingNameError] if _name_ is specified, a project associated with
  _file_ already exists but _name_ and the name of the existing project are different
=end
      def project file, name = nil
        prj = @projects[file]
        if prj
          if name and prj.project_name != name
            raise MismatchingNameError.new file, name, prj.project_name
          end
          prj
        else
          prj = Project.new file, name
          connect prj, SIGNAL('closing(QObject*)'), self, SLOT('project_closing(QObject*)')
          @projects[prj.project_file] = prj
        end
      end
      
      private
      
=begin rdoc
Method called whenever a project is closed

It ensures that the list of open projects is up to date
@return [nil]
=end
      def project_closing prj
        @projects.delete prj.project_file
        nil
      end
      slots 'project_closing(QObject*)'
      
    end
  end
  
end