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

require 'ruber/editor/document'

module Ruber
  
  module World
  
=begin rdoc
Factory class to create documents

It ensures that at all times there's only a single document associated with a
given file.

@note in the documentation, whenever a file name is mentioned, it can be replaced
  by a @KDE::Url@.
=end
    class DocumentFactory < Qt::Object
      
      signals 'document_created(QObject*)'
      
=begin rdoc
@param [Qt::Object,nil] parent the parent object
=end
      def initialize world, parent = nil
        super parent
        @world = world
        @documents = {}
      end
    
=begin rdoc
Returns a document, creating it if needed

If a file name is specified, a document for that file will be returned.
If a document for that file name already exists, it will be returned. Otherwise, a new
document will be created.

If no file or URL is given, a new document (not associated with a file) is returned.
@param [String,KDE::Url,nil] file if not nil, the absolute name or the URL of the
  file to retrieve the document for. If *nil*, a new document not associated with
  any file will be created
@param [Qt::Object,nil] parent the object the document should be child of. If *nil*,
  the document will be parentless
@return [Document,nil] a document associated with _file_ or a new document not
  associated with a file if _file_ is *nil*. If _file_ represents a local file
  and that file doesn't exist, *nil* is returned
=end
      def document file, parent = nil
        if file
          url = KDE::Url.new file
          return if url.local_file? and !File.exist?(url.path)
          doc = @documents[url]
          doc || create_document(file, parent)
        else create_document nil, parent
        end
      end
      
      private
      
=begin rdoc
Slot called whenever a document is closed

It ensures that the document is removed from the internal document list
@param [Document] doc the document being closed
=end
      def document_closed doc
        @documents.delete doc.url
      end
      slots 'document_closed(QObject*)'
      
=begin rdoc
Slot called whenever a document's URL changes

It updates the internal list of documents
@param [Document] doc the document whose URL has changed
=end
      def document_url_changed doc
        @documents.reject!{|k, v| v == doc}
        @documents[doc.url] = doc
      end
      slots 'document_url_changed(QObject*)'
      
=begin rdoc
Creates a new document

After creating the document, makes all the necessary signal-slot connections with
it and adds it to the internal document list if needed
@param (see Ruber::World::DocumentFactory#document)
@return [Ruber::Document] the new document
=end
      def create_document file, parent
        doc = Document.new @world, file, parent
        @documents[doc.url] = doc if file
        connect doc, SIGNAL('closing(QObject*)'), self, SLOT('document_closed(QObject*)')
        connect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT('document_url_changed(QObject*)')
        emit document_created(doc)
        doc
      end
      
    end
    
  end
  
end