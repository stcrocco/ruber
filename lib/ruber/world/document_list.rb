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
A list of documents

It's an immutable @Enumerable@ class with some convenience methods for dealing
with documents.

The documents in the list are set in the constructor and can't be changed later.
=end
    class DocumentList
      
      include Enumerable

=begin rdoc
@param [Array<Document>, DocumentList] docs the documents to insert in the
  list when created. If it's a {DocumentList}, changes to _docs_ will be
  reflected by the newly created object. This won't happen if _docs_ is an array
=end
      def initialize docs = []
        @documents = docs.is_a?(DocumentList) ? docs.document_array : docs.dup
      end

=begin rdoc
Iterates on the documents

@overload each{|doc| }
  Calls the block once for each document in the list, in insertion order
  @yieldparam [Ruber::Document] doc the documents in the list
  @return [DocumentList] *self*
@overload each
  @return [Enumerator] an enumerator which iterates on the documents
@return [DocumentList,Enumerator]
=end
      def each &blk
        if block_given?
          @documents.each &blk
          self
        else self.to_enum
        end
      end
      
=begin rdoc
@return [Integer] the number of documents in the list
=end
      def size
        @documents.size
      end
      
=begin rdoc
Whether or not the list is empty
@return [Boolean] *true* if the list is empty and *false* otherwise
=end
      def empty?
        @documents.empty?
      end
      
=begin rdoc
Element access
@overload [] idx
  Returns the document at a given position
  @param [Integer] idx the index of the document to return. If negative, elements
    are counted from the end of the list
  @return [Document,nil] the document at position _idx_ or *nil* if _idx_ is out
    of range
@overload [] range
  Returns an array containing the documents in the given range of indexes
  @param [Range] range the range of indexes of the documents to return. Negative
    indexes are counted from the end of the list
  @return [Array<Document>,nil] an array containing the documents corresponding
    to the given range. Indexes which are out of range are ignored. If the whole
    range is out of range, *nil* is returned
@overload [] url
  Returns the document associated with the given URL
  
  You must use a @KDE::Url@ if you want to find a document using it's url. Passing
  a string wouldn't work, as it would be considered the document's name.
  @param [KDE::Url] url the url to retrieve the document for
  @return [Document,nil] the document associated with the given url or *nil*
    if the list contains no document associated with the url. If the list contains
    more than one document associated with the url, the first of them is returned
@overload [] file
  Returns the document associated with the given file
  @param [String] fike the *absolute* path of the file
  @return [Document,nil] the document associated with the given file or *nil*
    if the list contains no document associated with the file. If the list contains
    more than one document associated with the file, the first of them is returned
@overload [] name
  Returns the document with the given document name
  @param [String] name the document name. It must not start with a slash (@/@)
  @return [Document,nil] the document with the given document name or *nil*
    if the list contains no document with that name. If the list contains
    more than one document with that name, the first of them is returned
@return [Document,Array<Document>,nil]
=end
      def [] arg
        case arg
        when Integer, Range then @documents[arg]
        when KDE::Url then @documents.find{|doc| doc.url == arg}
        when String 
          if arg.start_with? '/'
            @documents.find do |doc|
              doc.url.local_file? and doc.path == arg
            end
          else @documents.find{|doc| doc.document_name == arg}
          end
        end
      end
      
=begin rdoc
The document associated with a given file
@param [String] file the absolute path of the file
@return [Document,nil] the document associated with the given file or *nil* if
  there's no document associated with it in the list. If there is more than one
  document associated with the file, the first one will be returned
@raise [ArgumentError] if the file name is not an absolute path (i.e., it doesn't
  start with a @/@)
=end
      def document_for_file file
        raise ArgumentError, "#{file} is not an absolute path" unless file.start_with?('/')
        @documents.find{|doc| doc.url.local_file? && doc.path == file}
      end
      
=begin rdoc
Whether or not the list contains a document associated with a given file
@param (see DocumentList#document_for_file)
@return [Boolean] *true* if the list contains a document associated with _file_ and *false*
  otherwise
@raise (see DocumentList#document_for_file)
=end
      def document_for_file? file
        document_for_file(file).to_bool
      end

=begin rdoc
The document associated with a given URL
@param [KDE::Url, String] url the URL associated with the file. If it is a string,
  it must be in a format suitable to be passed to @KDE::Url.new@
@return [Document,nil] the document associated with the given url or *nil* if
  there's no document associated with it in the list. If there is more than one
  document associated with the URL, the first one will be returned
=end
      def document_for_url url
        @documents.find{|doc| doc.url == url}
      end

=begin rdoc
Whether or not the list contains a document associated with a given URL
@param (see DocumentList#document_for_url)
@return [Boolean] *true* if the list contains a document associated with _url_ and *false*
  otherwise
=end
      def document_for_url? url
        document_for_url(url).to_bool
      end

=begin rdoc
The document with a given @document_name@
@param [String] name the name of the document
@return [Document,nil] the document with the given document name or *nil* if
  there's no document with that name. If there is more than one
  document with the given document name, the first one will be returned
=end
      def document_with_name name
        @documents.find{|doc| doc.document_name == name}
      end
      
=begin rdoc
Whether or not the list contains a document with a given document name
@param (see DocumentList#document_with_name)
@return [Boolean] *true* if the list contains a document with the given document
  name and *false* otherwise
=end
      def document_with_name? name
        document_with_name(name).to_bool
      end
      
=begin rdoc
A list of the documents having a file associated with them

According to the _which_ argument, this method can return all the documents in
the list which have a file associated with them, only those which have a _local_
file associated with them or only those which have a _remote_ file associated with
them.

@param [Symbol] which the kind of files which can be associated with the documents.
  It can be: @:local@ to return only documents associated with local files, @:remote@
  to return only documents associated with remote files or @:any@ to return documents
  associated with either @:local@ or @:remote@ files
@return [Array<Document>] a list of the documents associated with a file, according
  with the restrictions posed by _which_.
=end
      def documents_with_file which = :any
        case which
        when :local then @documents.select{|doc| doc.url.local_file?}
        when :remote then @documents.select{|doc| doc.url.remote_file?}
        when :any then @documents.select{|doc| doc.has_file?}
        end
      end
      
=begin rdoc
Comparison operator

@param [Object] other the object to compare *self* with
@return [Boolean] *true* if _other_ is either an @Array@ or a {DocumentList}
  containing the same elements as *self* in the same order and *false* otherwise
=end
      def == other
        case other
        when DocumentList
          @documents == other.instance_variable_get(:@documents)
        when Array then @documents == other
        else false
        end
      end
      
=begin rdoc
Comparison operator used by Hash

@param [Object] other the object to compare *self* with
@return [Boolean] *true* if _other_ is a {DocumentList} containing the
  same elements as *self* in the same order and *false* otherwise
=end
      def eql? other
        if other.is_a? DocumentList
          @documents == other.instance_variable_get(:@documents)
        else false
        end
      end
      
=begin rdoc
Override of @Object#hash@

@return [Integer] the hash value for *self*
=end
      def hash
        @documents.hash
      end
      
      protected
      
=begin rdoc
@return [Array<Document>] the internal array used to keep trace of the documents
=end
      def document_array
        @documents
      end
      
    end
    
=begin rdoc
A {DocumentList} which allows to change the contents of the list.
=end
    class MutableDocumentList < DocumentList
      
=begin rdoc
@param [Array<Document>, DocumentList] docs the documents to insert in the
  list when created. Further changes to _docs_ won't change the new instance and
  vice versa
=end
      def initialize docs = []
        docs = docs.document_array if docs.is_a? DocumentList 
        @documents = docs.dup
      end
      
=begin rdoc
Override of @Object#dup@
@return [MutableDocumentList] a duplicate of *self*
=end
      def dup
        self.class.new self
      end

=begin rdoc
Override of @Object#clone@
@return [MutableDocumentList] a duplicate of *self*
=end
      def clone
        res = self.class.new self
        if frozen?
          res.freeze 
          res.document_array.freeze
        end
        res
      end


=begin rdoc
Adds documents to the list

@param [Array<Document,Array<Document>>] docs the documents to add. If it contains
  nested arrays, they'll be flattened
@return [MutableDocumentList] *self*
@note this method doesn't check for duplicate documents. While having multiple
  copies of the same document shouldn't cause troubles, it's better to avoid them.
  To do so, either check beforehand that _docs_ contains no duplicates and no
  document already in the list, or use {#uniq!} afterwards
=end
      def add *docs
        docs.flatten!
        @documents.insert -1, *docs
        self
      end
      
=begin rdoc
Adds the contents of another array or {MutableDocumentList} to the list

The documents from the other list will be added at the end of this list.

@param [Array<Document>, DocumentList] other the list whose contents should
  be added to this list contents
@param [Boolean] remove_duplicates if *true*, after adding the contents of _other_
  to the list, {#uniq!} will be called to ensure there are no duplicates. If *false*,
  {#uniq!} won't be called
@return [MutableDocumentList] *self*
=end
      def merge! other, remove_duplicates = true
        if other.is_a? DocumentList
          @documents.concat other.document_array
        else @documents.concat other
        end
        uniq! if remove_duplicates
        self
      end
      
=begin rdoc
Removes a document from the list

If the given document isn't in the list, nothing is done

@param [Document] doc the document to remove
@return [Document,nil] the removed document or *nil* if no document was removed
=end
      def remove doc
        @documents.delete doc
      end
      
=begin rdoc
Removes all the elements from the list

@return [MutableDocumentList] *self*
=end
      def clear
        @documents.clear
        self
      end
      
=begin rdoc
Removes from the list all documents for which the block returns true

@yieldparam [Document] doc the documents in the list
@yieldreturn [Boolean] *true* for documents which should be removed from the list
  and *false* otherwise
@return [MutableDocumentList] *self*
=end
      def delete_if &blk
        @documents.delete_if &blk
        self
      end
      
=begin rdoc
Ensures that the list doesn't contain duplicates

After calling this method, the list won't contain the same document in multiple
places
@return [MutableDocumentList] *self*
=end
      def uniq!
        @documents.uniq!
        self
      end

    end
    
  end
  
end