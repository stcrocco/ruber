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
  
  class DocumentProject < AbstractProject
    
=begin rdoc
Backend for SettingsContainer used in particular for ProjectDocuments. It mostly
works as YamlSettingsBackend, with the following differences:
* it doesn't create the file if the only option to be written (that is, the only
  one different from its default value) is the +project_name+. In that case, if
  the file already exists, it is deleted
* it automatically determines the name of the associated file from the name of the
  document
=end
    class Backend < YamlSettingsBackend
      
=begin rdoc
Creates a new DocumentProject::Backend. _file_ is the path of the file associated
with the backend.

If _file_ is an invalid project file, the behaviour will be the same as the file
didn't exist. This means that it will be overwritten when the project is saved.
The reason for this behaviour is that there should be no user file in the directory
where document projects are saved.
=end
      def initialize file
        @old_files = []
        begin super file_for(file)
        rescue InvalidSettingsFile
        end
      end
      
=begin rdoc
Works mostly as <tt>YamlSettingsBackend#write</tt>. If the only option to be written
is the project name, the file isn't created, if it doesn't exist, and is deleted
if it does exist. Also, if there are any obsolete files (see <tt>document_path=</tt>),
they are deleted, too.

If no file name is associated with the backend (that is, if +file+ returns an empty string),
a +SystemCall+ error (most likely, <tt>Errno::ENOENT</tt>) will be raised
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
      end
      
=begin rdoc
Changes the project name and the file name so that they match a document path of
_value_. This means:
* setting the project name to _value_
* changing the file associated with the backend to an encoded version of _value_
* adding the old associated file to a list of obsolete files, which will be deleted
  at the next write
=end
      def document_path= value
        @data[:general] ||= {}
        @data[:general][:project_name] = value
        @old_files << @filename unless @filename.empty?
        @filename = file_for(value)
      end
      
      private
      
=begin rdoc
Returns the file where the data for the document path _path_ should be stored (an
empty string if _path_ is empty).
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
The document associated with the project
=end
    attr_reader :document
    
=begin rdoc
Creates a new DocumentProject. _doc_ is the document the project refers to.  Note
that, until _doc_ becomes associated with a file, attempting to save the project
will fail with an +ArgumentError+.

If the path of the file associated with the document changes (usually because of
a "Save As" action), the file associated with the backend is changed automatically

@todo in classes derived from Qt::Object, korundum executes the code in initialize,
up until the call to super twice. This means that two Backend items will be created.
See if something can be done to avoid it. I don't know whether this has any bad
consequence or not.
=end
    def initialize doc
      @document = doc
      path = backend_file
      back = Backend.new path
      !File.exist?(back.file) ? super(doc, back, path) : super(doc, back)
      connect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT(:change_file)
    end
    
=begin rdoc
Override of <tt>AbstractProject#scope</tt> which returns +:document+
=end
    def scope
      :document
    end
    
=begin rdoc
Override of AbstractProject#match_rule? which also takes into account the mimetype
and the file extension of the document and compares them with those in the rule.
The comparison is made using <tt>Document#file_type_match?</tt>. This method returns
*true* only if the <tt>Document#file_type_match?</tt> returns *true* and the
rule's scope includes +:document+
=end
    def match_rule? obj
      doc_place  = if !@document.path.empty?
        @document.url.local_file? ? :local : :remote
      else :local
      end
      if !super then false
      elsif !obj.place.include? doc_place then false
      elsif !@document.file_type_match? obj.mimetype, obj.file_extension then false
      else true
      end
    end
    
=begin rdoc
Override of <tt>AbstractProject#project_directory</tt> which returns the current
directory if the document isn't associated with a file.
=end
    def project_directory
      path = @document.path
      path.empty? ? Dir.pwd : File.dirname(path) 
    end
    alias_method :project_dir, :project_directory
    
=begin rdoc
Override of <tt>AbstractProject#write</tt> which prevents a Errno::ENOENT exception
to be raised by the backend if the document isn't associated with a file. If the
document is associated with a file, however, the exception will be raised as usual.

The reason for this kind of behaviour is that the backend is expected to raise
the exception when the document isn't associated with a file: it simply means that
it doesn't know where to write the data. If the document is associated with a file,
however, this shouldn't happen and the exception is then propagated because it
truly means something is wrong.
=end
    def write
      begin super
      rescue Errno::ENOENT
        raise unless @document.path.empty?
      end
    end
    
=begin rdoc
Override of AbstractProject#files which returns an array with the path of the 
associated document, if it corresponds to a file, and an empty array otherwise
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
    
    private
    
=begin rdoc
Updates the backend so that the associated file reflects the file associated with
the document.
=end
    def change_file
      @backend.document_path = backend_file
    end
    
    def backend_file
      if @document.has_file?
        @document.url.to_encoded(Qt::Url::RemoveUserInfo|Qt::Url::RemovePort|Qt::Url::RemoveFragment).to_s
      else ''
      end
    end
    
  end
  
end