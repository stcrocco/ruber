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
A list of projects

It's an immutable @Enumerable@ class with some convenience methods for dealing
with projects.

The projects in the list are set in the constructor and can't be changed later.

The order of projects won't be kept.

@note This list can't contain more than one project with the same project file.
=end
    class ProjectList
      
      include Enumerable
      
=begin rdoc
@param [Array<Project>, ProjectList] prjs the projects to insert in the
  list when created. If it's a {ProjectList}, changes to _prjs_ will be
  reflected by the newly created object. This won't happen if _prjs_ is an array.
  
  If the list contains multiple projects with the same project file, only the last
  one will be inserted in the list
=end
      def initialize prjs
        if prjs.is_a? ProjectList then @projects = prjs.project_hash
        else @projects = Hash[prjs.map{|prj| [prj.project_file, prj]}]
        end
      end

=begin rdoc
Iterates on the projects

@overload each{|prj| }
  Calls the block once for each project in the list (the order is arbitrary)
  @yieldparam [Project] prj the projects in the list
  @return [ProjectList] *self*
@overload each
  @return [Enumerator] an enumerator which iterates on the projects
@return [ProjectList,Enumerator]
=end
      def each &blk
        if block_given?
          @projects.each_value &blk
          self
        else to_enum
        end
      end
      
=begin rdoc
Whether or not the list is empty
@return [Boolean] *true* if the list is empty and *false* otherwise
=end
      def empty?
        @projects.empty?
      end
      
=begin rdoc
@return [Integer] the number of projects in the list
=end
      def size
        @projects.size
      end
      
=begin rdoc
Comparison operator

@param [Object] other the object to compare *self* with
@return [Boolean] *true* if _other_ is either an @Array@ or a {ProjectList}
  containing the same elements as *self* and *false* otherwise
=end
      def == other
        case other
        when ProjectList then @projects == other.project_hash
        when Array
          @projects.values.sort_by(&:object_id) == other.sort_by(&:object_id)
        else false
        end
      end

=begin rdoc
Comparison operator used by Hash

@param [Object] other the object to compare *self* with
@return [Boolean] *true* if _other_ is a {ProjectList} containing the
  same elements as *self* and *false* otherwise
=end
      def eql? other
        other.is_a?(ProjectList) ? @projects.eql?(other.project_hash) : false
      end
      
=begin rdoc
Override of @Object#hash@

@return [Integer] the hash value for *self*
=end
      def hash
        @projects.hash
      end
      
=begin rdoc
Element access

@overload [] filename
  Retrieves the project for the given project file
  @param [String] filename the absolute path of the project file. It must start
    with a slash
  @return [Project,nil] the project having _filename_ as project file or *nil* if
    no project having that project file is in the list
@overload [] name
  Retrieves the project having the given project name
  @param [String] name the project name. It must not start with a slash
  @return [Project,nil] the project having the given project name or *nil* if no
    such project exists in the list. If there is more than one document with the
    same project name, one of them is returned
@return [Project,nil]
=end
      def [] arg
        if arg.start_with? '/' then @projects[arg]
        else 
          prj = @projects.find{|i| i[1].project_name == arg}
          prj ? prj[1] : nil
        end
      end
      
      protected
      
=begin rdoc
@return [Hash{String=>Project}] the internal hash used to keep trace of the projects
=end
      def project_hash
        @projects
      end
      
    end
   
=begin rdoc
A {ProjectList} which allows to change the contents of the list.
=end
    class MutableProjectList < ProjectList
      
=begin rdoc
@param [Array<Project>, ProjectList] prjs the projects to insert in the
  list when created. Further changes to _prjs_ won't change the new instance and
  vice versa
=end
      def initialize prjs = []
        @projects = Hash[prjs.map{|prj| [prj.project_name, prj]}]
      end
      
=begin rdoc
Override of @Object#dup@
@return [MutableProjectList] a duplicate of *self*
=end
      def dup
        self.class.new self
      end
      
=begin rdoc
Override of @Object#clone@
@return [MutableProjectList] a duplicate of *self*
=end
      def clone
        res = self.class.new self
        if frozen?
          res.freeze
          res.project_hash.freeze
        end
        res
      end
      
=begin rdoc
Adds projects to the list

@param [Array<Project,Array<Project>>] projects the projects to add. If it contains
  nested arrays, they'll be flattened. If the list contains multiple projects with
  the same project file, only the last one will be kept (if a project with the same
  project name was already in the list, it'll be overwritten)
@return [MutableProjectList] *self*
=end
      def add *projects
        projects.flatten.each do |prj|
          @projects[prj.project_file] = prj
        end
      end
      
=begin rdoc
Adds the projects contained in another list to this list

@param [Array<Project>, ProjectList] other the list whose contents should
  be added to this list contents
@return [MutableProjectList] *self*
=end
      def merge! prjs
        if prjs.is_a? ProjectList then @projects.merge! prjs.project_hash
        else
          @projects.merge! Hash[prjs.map{|prj| [prj.project_file, prj]}]
        end
        self
      end
      
=begin rdoc
Removes a project from the list

If the given project isn't in the list, nothing is done

@param [Project] doc the project to remove
@return [Project,nil] the removed project or *nil* if no project was removed
=end
      def remove prj
        @projects.delete prj.project_file
      end
      
=begin rdoc
Removes all the elements from the list

@return [MutableProjectList] *self*
=end
      def clear
        @projects.clear
        self
      end
      
=begin rdoc
Removes from the list all the projects for which the block returns true

@yieldparam [Project] prj the projects in the list
@yieldreturn [Boolean] *true* for projects which should be removed from the list
  and *false* otherwise
@return [MutableProjectList] *self*
=end
      def delete_if &blk
        @projects.delete_if{|_, prj| blk.call prj}
        self
      end
      
    end
    
  end
  
end