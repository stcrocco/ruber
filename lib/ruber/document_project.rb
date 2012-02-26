=begin 
    Copyright (C) 2010, 2011, 2012 by Stefano Crocco   
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

require 'facets/hash/keys'
require 'fileutils'

begin
  require 'md5'
rescue LoadError
  require 'digest/md5'
end

require 'ruber/yaml_option_backend'
require 'ruber/project'

module Ruber
  
=begin rdoc
A project class where per-document settings are stored

A DocumentProject is associated with both a document and an environment (the
DocumentProject is said to live in the environment). This means that there can
be more than one project for a given document, each living in a different environment
and written to a different file.

The name of the file the DocumentProject is written to is automatically computed,
depending on both the path of the file associated with the document and the
path of the project file associated with the environment. Whenever the path of
the file associated with the document changes, the path of the file associated
with the DocumentProject is automatically changed (see {#change_file}).

If the document is not associated with a file, then the DocumentProject won't
be written to a file ({#save} will do nothing in that case).
=end
  class DocumentProject < AbstractProject
    
=begin rdoc
Backend for SettingsContainer used particular by {DocumentProject}. It mostly
works as YamlSettingsBackend, with the following differences:
* it doesn't create the file if the only option to be written (that is, the only
  one different from its default value) is the @project_name@. In that case, if
  the file already exists, it is deleted
* it automatically determines the name of the associated file from the name of the
  document
=end
    class Backend < YamlSettingsBackend
      
=begin rdoc
@param [String] file the path of the file to associate with the new instance.
  If a file with that name already exists but is not a valid project file, it
  will silently be overwritten. This shouldn't cause data losses, as there shouldn'
  t be user documents in  directory where document project files are saved
=end
      def initialize file
        @old_files = []
        path = file_for file
        begin super path
        rescue InvalidSettingsFile
          FileUtils.rm path
          @data = {}
        end
      end
      
=begin rdoc
Override of {YamlSettingsBackend#write}

The only difference with the base class method is that if the only setting with
a value different from the default is @general/project_name@, then the file won't
be created (actually, it'll be deleted if it exists). Also, any obsolete files
(see {#document_path=}) will be deleted.

@raise [SystemCallError] if no file is associated with the backend
@return [nil]
=end
      def write opts
        new_data = compute_data opts
        if new_data.has_only_keys?(:general) and new_data[:general].has_only_keys?(:project_name)
          FileUtils.rm_f @filename
          return
        end
        File.open(@filename, 'w'){|f| f.write YAML.dump(new_data)}
        @old_files.each{|f| FileUtils.rm_f f}
        @old_files.clear
        @data = new_data
        nil
      end
      
=begin rdoc
Changes the project name and the file name so that they match a document path of
_value_
  
Changes the project name and the file associated with the backend to match the
given document path

The file previously associated with the backend is marked as obsolete, and will
be deleted when {#write} is called.

The settings won't be automatically written to the new file: you'll have to call
{#write} to do so
@param [String] value the path of the file associated with the document
@return [nil]
=end
      def document_path= value
        @data[:general] ||= {}
        @data[:general][:project_name] = value
        @old_files << @filename unless @filename.empty?
        @filename = file_for(value)
        nil
      end
      
      private
      
=begin rdoc
@param [String] path the base string from which to compute the file associated
  with the backend
@return [String] the file where the data for the document should be stored. If
  _path_ is empty, an empty string is used
=end
      def file_for path
        return '' if path.empty?
        dir = KDE::Global.dirs.locate_local('appdata', 'documents/')
        md5 = Digest::MD5.new
        md5 << path
        File.join dir, md5.hexdigest
      end
      
    end
    
    slots :change_file
    
=begin rdoc
@return [Document] the document associated with the project
=end
    attr_reader :document
    
=begin rdoc
@return [World::Environment] the environment the project lives in
=end
    attr_reader :environment
    
=begin rdoc
A new instance of DocumentProject

@param [Document] doc the document the DocumentProject should be associated with
@param [World::Environment] env the environment the DocumentProject should live in
@return [DocumentProject] a new instance of DocumentProject

@todo in classes derived from Qt::Object, korundum executes the code in initialize,
up until the call to super twice. This means that two Backend items will be created.
See if something can be done to avoid it. I don't know whether this has any bad
consequence or not.
=end
    def initialize doc, env
      @document = doc
      @environment = env
      path = backend_file
      back = Backend.new path
      !File.exist?(back.file) ? super(doc, back, path) : super(doc, back)
      connect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT(:change_file)
    end
    
=begin rdoc
Override of {AbstractProject#scope}

It simply returns @:document@

@return [Symbol] @:document@
=end
    def scope
      :document
    end
    
=begin rdoc
Override of {AbstractProject#match_rule?}

It works as the base class method but also takes into account the mimetype and
the file extension of the document and compares them with those in the rule.

The comparison is made using {Document#file_type_match?}

@param [#scope,#mimetype,#file_extension] rule the rule to compare the document
  with
@return [Boolean] *true* if one of the mimetypes and/or file patterns specified
  in the rule match the document and the scope of the rule includes @:document@;
  *false* otherwise
@see Document#file_type_match?
=end
    def match_rule? rule
      doc_place  = if !@document.path.empty?
        @document.url.local_file? ? :local : :remote
      else :local
      end
      if !super then false
      elsif !rule.place.include? doc_place then false
      elsif !@document.file_type_match? rule.mimetype, rule.file_extension then false
      else true
      end
    end
    
=begin rdoc
Override of {AbstractProject#project_directory}

@return [String] the directory of the file associated with the document or the
  current directory if the document is not associated with a file
=end
    def project_directory
      path = @document.path
      path.empty? ? Dir.pwd : File.dirname(path) 
    end
    alias_method :project_dir, :project_directory
    
=begin rdoc
Override of {AbstractProject#write}

It works as the base class method, but it doesn't raise an exception if the
document is not associated with a file (because a document project has a valid
project file only if its document is itself associated with a file).

If an exception is raised when writing the file and the document is associated
with a file, the extension will be propagated as usual, because in this case
it means something unexpected has happened

@raise (see Ruber::AbstractProject#write)
@return [nil]
=end
    def write
      begin super
      rescue Errno::ENOENT
        raise if @document.has_file?
      end
    end
    
=begin rdoc
Override of {AbstractProject#files}

@return [<String>] an array with the file associated with the document or an empty
  array if the document is not associated with a file
=end
    def files
      url =  @document.url
      if url.local_file?
        path = url.path
      else 
        path = url.to_encoded(Qt::Url::RemoveUserInfo|Qt::Url::RemovePort|Qt::Url::RemoveFragment).to_s
      end
      path.empty? ? [] : [path] 
    end
    
=begin rdoc
Override of {AbstractProject#save}

It does nothing if the associated document doesn't correspond to file, otherwise
it behaves as {AbstractProject#save}

@return [Boolean] *true* if the project was saved or if the document isn't
  associated with a file and *false* otherwise
=end
    def save
      if @document.has_file? then super 
      else true
      end
    end
    
    private
    
=begin rdoc
Updates the backend so that the associated file reflects the file associated with
the document.
@return [nil]
=end
    def change_file
      @backend.document_path = backend_file
      nil
    end
    
=begin rdoc
Computes the name of the file where to save the settings

The name of the file is an encoded version of the url associated with the file,
followed by a colon and the project file associated with the environment the
document project lives in. If the environment is not associated with a project,
nothing follows the colon.

If the document is not associated with a file, an empty string is used.

@return [String] the path of the file where to save settngs
=end
    def backend_file
      if @document.has_file?
        file = @document.url.to_encoded(Qt::Url::RemoveUserInfo|Qt::Url::RemovePort|Qt::Url::RemoveFragment).to_s
        file << ":#{@environment.project ? @environment.project.project_file : ''}"
        file
      else ''
      end
    end
    
  end
  
end