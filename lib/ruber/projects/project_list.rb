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

require 'ruber/project'
require 'ruber/plugin_like'

module Ruber
  
=begin rdoc
The current project

@return [Ruber::Project,nil] the current project or *nil* if no project is open
=end
  def self.current_project
    self[:projects].current_project
  end

=begin rdoc
List of all open global projects

It allows to obtain a list of the open projects, to know when a project is
closed and keeps trace of which is the current project. The most common usage
is the following:
* use the {#project} method to retrieve an open project basing on the name of
  its file, or to open it if it isn't already open, or to create a new project.
  This will also cause the project to be added to the list of open projects,
  if needed
* use {#current_project=} to set the current project
* use one of the methods to iterate or work with one of the projects
* close one of the projects with the project's {Project#close close} method, or use the
  {#close_current_project} method to close the current project.
=end
  class ProjectList < Qt::Object
    
    include PluginLike
    
    include Enumerable

=begin rdoc
Signal emitted when the current project changes

@param [Ruber::Project,nil] prj the new current project, or *nil* if there's no open
project
=end
    signals 'current_project_changed(QObject*)'

=begin rdoc
Signal emitted when the current project changes

The signal is emitted after the previous current project has been deactivated and before
the new current project has been activated

@param [Ruber::Project,nil] new the new current project, or *nil* if there's no current project
@param [Ruber::Project,nil] old the previous current project, or *nil* if there wasn't any current project
=end
    signals 'current_project_changed_2(QObject*, QObject*)'
    
=begin rdoc
Signal emitted just before a project is closed

@param [Ruber::Project] prj the project which is being closed
=end
    signals 'closing_project(QObject*)'

=begin rdoc
Signal emitted whenever a project is added

@param [Ruber::Project] prj the newly added project
=end
    signals 'project_added(QObject*)'
    
    slots 'add_project(QObject*)', 'close_project(QObject*)', 'load_settings()'

=begin rdoc
@return [Ruber::Project,nil] the current project or *nil* if there's no open project
=end
    attr_reader :current_project
    alias_method :current, :current_project
    
=begin rdoc
@param [Ruber::ComponentManager] _manager (unused)
@param [Ruber::PluginSpecification] psf the plugin specification object describing
the component
=end
    def initialize _manager, psf
      super Ruber[:app]
      initialize_plugin psf
      @current_project = nil
      @projects = {}
    end

=begin rdoc
Iterates on all the projects

In both versions of the method, the order in which the projects are passed to the block is arbitrary

@overload each_project
  Passes each open project to the block in turn

  @yield [prj] one of the projects
  @return [Ruber::ProjectList] *self*
@overload each_project
  @return [Enumerator] an enumerator whose @each@ method yields all the projects
  in turn
=end
    def each_project &blk #:yields: project
      res = @projects.each_value &blk
      res.same?(@projects) ? self : res
    end
    alias each each_project
    
=begin rdoc
The existing projects

@return [Array<Ruber::Project>] the existing projects. Modifying the array
wont affect the @ProjectList@
=end
    def projects
      @projects.values
    end

=begin rdoc
Returns the project associated with a project file, opening it if necessary

This is one of the core methods of this class. It searchs the list of open projects
and return the one corresponding to the given project file. If a project for that
file isn't open, it will be opened and added to the list of open projects.

If, for any reason, you create a project using @Project.new@ instead of
using this method, you'll need to add it to the project list yourself using
{#add_project}.

@param [String] file the absolute path of the project file
@return [Ruber::Project] the project corresponding to the project file _file_
@raise an error deriving from @SystemCallError@ if the project file doesn't exist
or can't be opened
@raise {Ruber::AbstractProject::InvalidProjectFile} if _file_ isn't a valid project file
=end
    def project file
      @projects[file] || add_project(Project.new(file))
    end
    
=begin rdoc
Returns the project corresponding to a given file or with a given name

@overload [] name
  Returns the project with the given name
  @param [String] name the name of the project. It *must not* start with a slash (@/@)
  @return [Ruber::Project,nil] the project with name _name_ or *nil* if no open
  project with that name exists. If more than one project with that name exist,
  which will be returned is arbitrary
@overload [] file
  Returns the project corresponding to the given project file
  @param [String] file the absolute path of the project file
  @return [Ruber::Project,nil] the project corresponding to the project file _file_
  or *nil* if no open projects correspond to that file. Note that, unlike {#project},
  this method doesn't attempt to open the project corresponding to _file_ if it 
  isn't already open
=end
    def [] arg
      if arg[0,1] == '/' then @projects[arg]
      else
        find{|prj| prj.project_name == arg}
      end
    end

=begin rdoc
Creates a new empty project

After being created, the new project is added to the list. You almost always should
use this method, rather than calling {AbstractProject.new} to create a new empty
project.

@param [String] file the absolue path of the project file to associate with the
new project
@param [String] name the name of the new project
@return [Ruber::Project] the new project
@raise @RuntimeError@ if a file corresponding to the path _file_ already exists
=end
    def new_project file, name
      add_project Project.new( file, name )
    end

=begin rdoc
Makes a project active

The previously active project is deactivated, while the new one (unless *nil*)
will be activated (calling respectively the the projects' @deactivate@ and @activate@
methods)

@param [Ruber::Project,nil] prj the project to make current. If *nil*, the current
project will be deactivated, but no other project will become current
@raise @ArgumentError@ if _prj_ is not included in the project list
=end
    def current_project= prj
      if prj and !@projects[prj.project_file]
        raise ArgumentError, "Tried to set an unknown project as current project" 
      end
      old = @current_project
      @current_project.deactivate if @current_project
      @current_project = prj
      emit current_project_changed_2 prj, old
      emit current_project_changed prj
      @current_project.activate if @current_project
    end
    
=begin rdoc
Adds a project to the list

The {#project_added} signal is emitted after adding the project.

Since this method is automatically called by both {#project} and {#new_project},
you usually don't need to call it, unless you need to create the project using
@Project.new@ rather than using one of the above methods.

@param [Ruber::Project] prj the project to add
@return [Ruber::Project] the project itself
@raise @RuntimeError@ if a project corresponding to the same file as _prj_ is
already in the list
=end
    def add_project prj
      if @projects[prj.project_file]
        raise "A project with project file #{prj.project_file} is already open"
      end
      @projects[prj.project_file] = prj
      connect prj, SIGNAL('closing(QObject*)'), self, SLOT('close_project(QObject*)')
      emit project_added(prj)
      prj
    end

=begin rdoc
Closes the current project
  
If there's not a current project, nothing is done. Otherwise, it simply calls the
{#close_project} method passing the current project as argument.

@return [nil]
=end
    def close_current_project
      @current_project.close if @current_project
      nil
    end

=begin rdoc

Closes a project

If the project is current, sets the current project to *nil* before closing it.
In all cases, emits the {#closing_project} signal before closing the project.

@param [Ruber::Project] the project to close
@return [nil]
=end
    def close_project prj
      self.current_project = nil if @current_project == prj
      emit closing_project(prj)
      @projects.delete prj.project_file
      nil
    end
    
    
=begin rdoc
Saves each open project

@return [nil]
=end
    def save_settings
      @projects.values.each{|pr| pr.save}
      nil
    end
    
=begin rdoc
Tells whether it's all right for the projects to close the application

It calls the @query_close@ method for each project, returning *false* if any of
them returns *false* and *true* if all return *true*

@return [Boolean] *true* if it's all right for the projects to close the application
and *false* if at least one of them say the application can't be closed
=end
    def query_close
      @projects.values.each{|pr| return false unless pr.query_close}
      true
    end
    
=begin rdoc
Returns the project associated with a given project file

@param [String] file the path of the project file
@param [Symbol] which if @:active_only@, the project corresponding to _file_ will
be returned only if it's active. If it is @:all@ then it will be returned even if
it's inactive. Any other value will cause this method to always return *nil*
@return [Ruber::Project,nil] the project associated with the file _file_ or *nil*
if the list doesn't contain any such file or if it doesn't respect the value of
_which_.
=end
    def project_for_file file, which = :active_only
      current_prj = current
      return nil unless current_prj
      if current_prj.project_files.file_in_project?(file) then current_prj
      elsif which == :all
        find{|prj| prj.project_files.file_in_project?(file)}
      else nil
      end
    end
    
    
  end

end
