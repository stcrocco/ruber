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
Class which contains a list of all open documents

===Signals
<tt>document_created(QObject* doc)</tt>::
  signal emitted when a new document has been created/. _doc_ is the document
  itself (of class Document)
<tt>closing_document(QObject* doc)</tt>::
  signal emitted before a document is closed. _doc_ is the document (of class
  Document)
=end
  class DocumentList < Qt::Object
    
    include PluginLike
    
    include Enumerable
    
    extend Forwardable
    

    signals 'document_created(QObject*)', 'closing_document(QObject*)'
    
    slots 'close_document(QObject*)', 'load_settings()'
    
    def_delegators :@docs, :empty?, :length, :size
    
##
# :method: documents
# 
# Returns an array of the open documents
    def_delegator :@docs, :dup, :documents

    alias_method :to_a, :documents

=begin rdoc
Creates a new DocumentList
=end
    def initialize _manager, pdf
      super Ruber[:app]
      initialize_plugin pdf
      @docs = []
    end

#DOCUMENT CREATION
    
=begin rdoc
Adds a new empty document to the list and emits the <tt>document_created</tt>
signal. Returns the new document
=end
    def new_document
      doc = Document.new Ruber[:main_window]
      add_document doc
      emit document_created(doc)
      doc
    end
    
=begin rdoc
Returns the document associated with the file _file_. _file_ can be an absolute
or relative pathname (if it's relative, it will be considered relative to the
current directory). If a document associated with _file_ doesn't exist, and
<i>create_if_needed</i> is *true*, a new document is created and added to the list,
raising +ArgumentError+ if the file doesn't exist. If a document for _file_ doesn't
exist and <i>create_if_needed</i> is *false*, *nil* is returned; otherwise the
new document is returned.

If a new document has been created, the <tt>document_created</tt> signal is emitted.
=end
    def document file, create_if_needed = true
      file = File.expand_path(file)
      doc = document_for_file file
      return doc if doc or !create_if_needed
      raise ArgumentError, "File #{file} doesn't exist" unless File.exist?(file)
      doc = Document.new Ruber[:main_window], file
      begin @docs[0].close if @docs.only.pristine?
      rescue IndexError
      end
      add_document doc
      emit document_created(doc)
      doc
    end
    
=begin rdoc
Adds a new document to the list
=end
    def add_document doc
      if doc
        connect doc, SIGNAL('closing(QObject*)'), self, SLOT('close_document(QObject*)')
        @docs << doc
      end
    end
    
=begin rdoc
Attempts to save all the documents in the array _docs_, returning an array with
those documents which couldn't be saved.

If <i>stop_on_failure</i> is *true*, when a document can't be saved the method
doesn't attempt to save other documents, and includes both the one which failed
and the ones it didn't try to save in the returned array. When <i>stop_on_failure</i>
is *false*, instead, the method will try to save all documents, regardless of
whether all the previous ones could be saved or not. In this case, only the ones
for which saving failed will be put in the returned array.

If all the documents were saved successfully, the returned array will be empty.
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
    
    def save_settings
      @docs.each{|d| d.save_settings}
    end
    
#CLOSING DOCUMENTS
    
=begin rdoc
Removes the document _doc_ from the list and emits the <tt>closing_document</tt>
signal
=end
    def close_document doc
      emit closing_document(doc)
      @docs.delete doc
    end

=begin rdoc
  Closes all the documents. If _ask_ is +true+ the user is displayed a dialog
  to choose which documents he wants to save (see MainWindow#save_documents for
  more information).
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
If _key_ is an integer, returns the document at position _key_ in the list. If
_key_ is an absolute path, returns the document associated with that file (or
*nil* if no document is associated with the file). If _file_ is a string which
isn't an absolute path, it's interpreted as the <tt>document_name</tt> of a document
and the document with that <tt>document_name</tt> (or *nil*) will be returned.
If _key_ is something else, +TypeError+ will be raised.
=end
    def [] key
      case key
      when String
        if Pathname.new(key).absolute? then @docs.find{|d| d.path == key}
        else @docs.find{|d| d.document_name == key}
        end
      when Integer then @docs[key]
      else raise TypeError
      end
    end

=begin rdoc
If passed a block, calls the block for each document, otherwise returns an
<tt>Enumerable::Enumerator</tt> which does the same.
=end
    def each_document
      if block_given? then @docs.each{|d| yield d}
      else @docs.each
      end
    end
    alias_method :each, :each_document

=begin rdoc
Returns the document with filename _file_. _file_ can be an absolute
or relative pathname (if it's relative, it will be considered relative to the
current directory). If no document associated with file _file_ exists, *nil*
is returned.
=end
    def document_for_file file
      file = File.expand_path file
      @docs.find{|d| d.path == file}
    end

=begin rdoc
Returns the document with <tt>document_name</tt> _name_, or *nil* if no such
document is found
=end
    def document_with_name name
      @docs.find{|d| d.document_name == name}
    end

=begin rdoc
Returns an array containing all the documents associated with a file.
=end
    def documents_with_file
      @docs.select{|d| d.has_file?}
    end

#DOCUMENT QUERIES
    
=begin rdoc
Returns *true* if there's a document associated with the file _file_, which can
be an absolute filename or a filename relative to the current directory, and *false*
otherwise.
=end
    def document_for_file? file
      file = File.expand_path file
      @docs.any?{|d| d.path == file}
    end
    
=begin rdoc
Returns *true* if there's a file with <tt>document_name</tt> _name_ and *false*
otherwise.
=end
    def document_with_name? name
      @docs.any?{|d| d.document_name == name}
    end
        
    def query_close
      @docs.each{|d| return false unless d.own_project.query_close}
      Ruber[:main_window].save_documents
    end

  end

end