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

require 'forwardable'
require 'pathname'
require 'facets/array/only'

require 'ruber/editor/document'
require 'ruber/plugin_like'

module Ruber

=begin rdoc
List of all open documents

It contains convenience methods to iterate on the open documents and to create
them. Whenever possible, you should use them. In particular, when you need a document
associated with a given file or URL, you should always use {#document}, so that
if a document for that file is already installed, no new document will be created.

If, for any reason, you need to create a document using {Document.new}, please
don't forget to add the document to the list using {#add_document}.
=end
  class DocumentList < Qt::Object
    
    include PluginLike
    
    include Enumerable
    
=begin rdoc
Signal emitted when a new document is created

@param [Document] doc the new document
=end
    signals 'document_created(QObject*)'
    
=begin rdoc
Signal emitted before a document is closed

@param [Document] doc the document which is being closed
=end
    signals 'closing_document(QObject*)'
    
    slots 'close_document(QObject*)', 'load_settings()'
    
=begin rdoc
@param [ComponentManager] _manager the component manager (unused)
@param [PluginSpecification] psf the plugin specification object
=end
    def initialize _manager, psf
      super Ruber[:app]
      initialize_plugin psf
      @docs = []
    end

#DOCUMENT CREATION
    
=begin rdoc
Creates a new empty document

The document is automatically added to the list and the {#document_created} signal
is emitted
@return [Ruber::Document] the created document
=end
    def new_document
      doc = Document.new Ruber[:main_window]
      add_document doc
      emit document_created(doc)
      doc
    end
    
=begin rdoc
The document for a given file or url

If there's no open document associated with the given file or url, depending on
the value of _create_if_needed_ a new document associated with the file or url
will be created. In this case, the {#document_created} signal will be emitted.

@param [String, KDE::Url] file the file name or URL associated with the document.
  A relative file name will be expanded with respect to the current directory. A
  string containing a url will be interpreted as an url, not as a filename. If you
  need a document with a name which looks like an url, you can create an empty
  @KDE::Url@, then using @path=@ to set its path
@param [Boolean] create_if_needed whether or not to create a document associated
  with _file_ if there isn't one
@return [Document,nil] the document associated with _file_. If no such document
  exists and _create_if_needed_ is *false*, *nil* will be returned
@raise [ArgumentError] if _file_ is a local file, there's
  no document for it, it doesn't exist and _create_if_needed_ is *true*. Note that
  this won't happen if _file_ is a remote file, even if it doesn't exist
=end
    def document file, create_if_needed = true
      if file.is_a? String
        url = KDE::Url.new file
        url.path = File.expand_path(file) if url.relative?
      else url = file
      end
      doc = document_for_url file
      return doc if doc or !create_if_needed
      if !doc and create_if_needed
        if url.local_file?
          raise ArgumentError, "File #{url.path} doesn't exist" unless File.exist?(url.path)
        end
        doc = Document.new Ruber[:main_window], file
        begin @docs[0].close if @docs.only.pristine?
        rescue IndexError
        end
        add_document doc
        emit document_created(doc)
      end
      doc
    end
    
=begin rdoc
@return [Array<Document>] a list of open documents
=end
    def documents
      @docs.dup
    end
    alias :to_a :documents
    
=begin rdoc
@return [Boolean] whether the document list is empty or not
=end
    def empty?
      @docs.empty?
    end
    
=begin rdoc
@return [Integer] the number of documents in the list
=end
    def size
      @docs.size
    end
    alias :length :size
    
=begin rdoc
Adds a new document to the list

If you use {#new_document} and {#document} to create documents, you don't need to
call this method.

*Note:* this method doesn't check whether the document has already been added to
the list. If so, the results may cause errors. Please, always make sure the document
isn't already in the list before calling this.

@param [Document, nil] doc the document to add. If *nil*, nothing is done
@return [Document, nil] _doc_
=end
    def add_document doc
      if doc
        connect doc, SIGNAL('closing(QObject*)'), self, SLOT('close_document(QObject*)')
        @docs << doc
      end
    end
    
=begin rdoc
Attempts to save the given documents

What happens if a document can't be saved depends on the value of _stop_on_failure_:
if it's *false*, documents which can't be saved are skipped, while if it's true,
this method will return as soon as one document fails to save.

*Note:* by can't be saved, we mean that the user chose to save a document but,
for any reason, it couldn't be saved (for example this can happen if the user
doesn't have write permission on the file, or if the disk is full). If the user
decides not to save the file, instead, it is considered a success.

@param [Array<Document>] docs an array with the documents to save
@param [Boolean] stop_on_failure what to do when a document fails to save. If *true*,
  return immediately; if *false*, attempt to save the remaining documents
@return [Array<Document>] an array with the documents which couldn't be saved. If
  _stop_on_failure_ is *false*, it contains only the documents for which saving failed;
  if _stop_on_failure_ is *true* it also contains the documents for which saving
  wasn't even attempted. If all documents were saved successfully, the array will
  be empty
=end
    def save_documents docs, stop_on_failure = false
      failed = []
      docs.each_with_index do |d, i| 
        success = d.save
        failed << d unless success
        if !success and stop_on_failure
          failed += docs[(i+1)..-1]
          break
        end
      end
      failed
    end
    
=begin rdoc
Saves the settings for all open documents

@return [nil]
=end
    def save_settings
      @docs.each{|d| d.save_settings}
      nil
    end
    
#CLOSING DOCUMENTS
    
=begin rdoc
Removes a document from the list

The {#closing_document} signal is emitted before removing the document.
@param [Document] doc the document to remove. It must have been added to the list
  using {#add_document} (which is automatically called by {#document} and {#new_document})
@return [nil]
=end
    def close_document doc
      emit closing_document(doc)
      @docs.delete doc
      nil
    end
    private :close_document

=begin rdoc
Closes all the documents
  
If there are modified files and _ask_ is *true*, the user will be asked whether
he wants to save them (see {MainWindow#save_documents}). If he chooses to abort
closing, nothing will be done

@param [Boolean] ask if *true*, in case some files are modified, the user will
  be asked whether to save them. If *false*, no file will be saved
@return [Boolean] *true* if the documents were closed and *false* otherwise
=end
  def close_all ask = true
    docs = @docs.dup
    if !ask or Ruber[:main_window].save_documents docs
      docs.each {|d| d.close false}
      true
    else false
    end
  end

#DOCUMENT ACCESS

=begin rdoc
The document corresponding to the given key

How _key_ is interpreted depends on its class:
* if it's an @Integer@, the document in the corresponding position in the list will
  be returned
* if it's a @KDE::Url@, then the document associated with that url will be returned
* if it's a @String@ starting with a @/@ (that is, an absolute path) then the
  document associated with that file will be returned
* if it's a string not startng with a @/@, then the document with that
  @document_name@ will be returned
@param [String,Integer,KDE::Url] key the key for the document
@return [Document,nil] the document corresponding to _key_ or *nil* if no document
  corresponds to it
@raise [TypeError] if _key_ is not a @String@, @Integer@ or @KDE::Url@
=end
    def [] key
      case key
      when String
        if Pathname.new(key).absolute? then @docs.find{|d| d.path == key}
        else @docs.find{|d| d.document_name == key}
        end
      when KDE::Url
        @docs.find{|d| d.url == key}
      when Integer then @docs[key]
      else raise TypeError
      end
    end

=begin rdoc
Calls the block for each document
@yield [Document] each document in turn
@return [DocumentList,Enumerator] @self@ if called with a block; an @Enumerable@
otherwise
=end
    def each_document
      if block_given? 
        @docs.each{|d| yield d}
        self
      else self.to_enum
      end
    end
    alias_method :each, :each_document

=begin rdoc
The document associated with a given file

@param [String] file the name of the file. If it's relative, it will be considered
  relative to the current directory
@return [Document,nil] the document associated with _file_ or *nil* if no such
    document exists
=end
    def document_for_file file
      file = File.expand_path file
      @docs.find{|d| d.path == file}
    end

=begin rdoc
The document associated with a given URL

@param [KDE::Url] url the url
@return [Document,nil] the document associated with _url_ or *nil* if no such
    document exists
=end
    def document_for_url url
      @docs.find{|d| d.url == url}
    end

=begin rdoc
The document with a given name

@param [String] name the name of the document
@return [Document,nil] the document with @document_name@ _name_ or *nil* if no
  document with that name exists
=end
    def document_with_name name
      @docs.find{|d| d.document_name == name}
    end

=begin rdoc
The documents which are associated with a file

_which_ can be used to restrict the list of documents to only those associated
with local or remote files:
* if _which_ is @:local@ only documents associated with local files will be returned;
* if _which_ is @:remote@ only documents associated with remoted files will be returned;
* if _which_ has any other value, both documents associated with local and with
  remote files will be returned
@param [Object] which which kind of documents should be included in the list
@return [Array<Document>] a list of documents associated with files, and restricted
  according to the value of _which_
=end
    def documents_with_file which = :any
      @docs.select do |d| 
        if d.has_file?
          case which
          when :local then d.url.local_file?
          when :remote then !d.url.local_file?
          else true
          end
        end
      end
    end

#DOCUMENT QUERIES
    
=begin rdoc
Whether there's a document associated with a given file

@param [String] file the name of the file (absolute or relative to the current
  directory)
@return [Boolean] *true* if there's a document associated with _file_ and *false*
  otherwise
=end
    def document_for_file? file
      file = File.expand_path file
      @docs.any?{|d| d.path == file}
    end
    
=begin rdoc
Whether there's a document associated with a given URL

@param [@KDE::Url@] url the url
@return [Boolean] *true* if there's a document associated with _url_ and *false*
otherwise
=end
    def document_for_url? url
      @docs.any?{|d| d.url == url}
    end
    
=begin rdoc
Whether there's a document with a given name

@param [String] name of the document
@return [Boolean] *true* if there's a document associated with _name_ and *false*
  otherwise
=end
    def document_with_name? name
      @docs.any?{|d| d.document_name == name}
    end
  
=begin rdoc
Override of {PluginLike#query_close}

It first calls the {DocumentProject#query_close query_close} of each document's
own project, returning *false* as soon as one of them returns *false*, then 
attempts to save each document

@return [Boolean] *true* if it is all right to go on closing Ruber and *false*
  otherwise
=end
    def query_close
      @docs.each{|d| return false unless d.own_project.query_close}
      Ruber[:main_window].save_documents
    end

  end

end