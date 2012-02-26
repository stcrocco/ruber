require './spec/framework'
require './spec/common'

require 'ruber/world/document_list'
require 'ruber/editor/document'

describe Ruber::World::DocumentList do
  
  def create_list docs
    Ruber::World::DocumentList.new docs
  end
  
  before do
    @docs = 3.times.map{Ruber::Document.new Ruber[:world]}
  end
  
  it 'includes the enumerable module' do
    Ruber::World::DocumentList.ancestors.should include(Enumerable)
  end
  
  describe '.new' do
    
    it 'takes a Ruber::Worl::dDocumentList or an array as parameters' do
      list = Ruber::World::DocumentList.new @docs
      list.should == @docs
      other_list = Ruber::World::MutableDocumentList.new(@docs)
      list = Ruber::World::DocumentList.new other_list
      list.should == @docs
    end
    
    it 'doesn\'t create a duplicate of the argument if the argument is a DocumentList' do
      other_list = Ruber::World::DocumentList.new(@docs)
      list = Ruber::World::DocumentList.new other_list
      list.send(:document_array).should equal(other_list.send(:document_array))
    end
    
    it 'creates a duplicate of the argument if the argument is not a DocumentList' do
      list = Ruber::World::DocumentList.new @docs
      new_doc = Ruber::Document.new Ruber[:world]
      @docs << new_doc
      list.size.should == 3
    end
    
  end
  
  describe '#each' do
    
    before do
      @list = create_list @docs
    end
    
    context 'when called with a block' do
      
      it 'calls the block once for each document' do
        res = []
        @list.each{|d| res << d}
        res.should == @docs
      end
      
      it 'returns self' do
        @list.each{|d|}.should == @list
      end
      
    end
    
    context 'when called without a block' do
      
      it 'returns an enumerator which iterates on all documents' do
        res = []
        enum = @list.each
        enum.should be_an(Enumerator)
        enum.each{|d| res << d}
        res.should == @docs
      end
      
    end
    
  end
  
  describe '#empty?' do
        
    it 'returns true if the list doesn\'t contain any element' do
      list = create_list []
      list.should be_empty
    end
    
    it 'returns false if the list contains at least one element' do
      list = create_list @docs
      list.should_not be_empty
    end
    
  end
  
  describe '#size' do
    
    it 'returns the number of elements in the list' do
      list = create_list []
      list.size.should == 0
      list = create_list [Ruber::Document.new(Ruber[:world])]
      list.size.should == 1
      list = create_list @docs
      list.size.should == 3
    end
    
  end
  
  describe '#==' do
    
    before do
      @list = create_list @docs
    end
    
    context 'when the argument is a DocumentList' do
          
      it 'returns true if the argument contains the same documents in the same order' do
        other = create_list @docs
        @list.should == other
      end
      
      it 'returns false if the argument contains different documents' do
        other = create_list [@docs[1], @docs[2]]
        @list.should_not == other
      end
      
      it 'returns false if the argument contains the same documents in different order' do
        other = create_list [@docs[1], @docs[2], @docs[0]]
        @list.should_not == other
      end
      
    end
    
    context 'when the argument is an Array' do
      
      it 'returns true if the argument contains the same documents in the same order' do
        @list.should == @docs
      end
      
      it 'returns false if the argument contains different documents' do
        @list.should_not == [@docs[1], @docs[2]]
      end
      
      it 'returns false if the argument contains the same documents in different order' do
        @list.should_not == [@docs[1], @docs[2], @docs[0]]
      end
      
    end
    
    context 'when the argument is neither a DocumentList nor an array' do
      
      it 'returns false' do
        @list.should_not == {}
      end
      
    end
    
  end
  
  describe '#eql?' do
    
    before do
      @list = create_list @docs
    end
    
    context 'when the argument is a DocumentList' do
      
      it 'returns true if the argument contains the same documents in the same order' do
        other = create_list @docs
        @list.should eql(other)
      end
      
      it 'returns false if the argument contains different documents' do
        other = create_list [@docs[1], @docs[2]]
        @list.should_not eql(other)
      end
      
      it 'returns false if the argument contains the same documents in different order' do
        other =  create_list [@docs[1], @docs[2], @docs[0]]
        @list.should_not eql(other)
      end
      
    end
    
    context 'when the argument is not a DocumentList' do
      
      it 'returns false' do
        @list.should_not eql([])
        @list.should_not eql({})
      end
      
    end
    
  end
  
  describe '#hash' do
    
    it 'returns the same value as an array contining the same arguments' do
      list = create_list @docs
      list.hash.should == @docs.hash
    end
    
  end
  
  describe '#[]' do
    
    context 'when called with an integer argument' do
      
      before do
        @list = create_list @docs
      end
      
      it 'returns the document at the given position' do
        @list[1].should == @docs[1]
      end
      
      it 'counts backward if the argument is negative' do
        @list[-1].should == @docs[2]
      end
      
      it 'returns nil if the argument is out of range' do
        @list[5].should be_nil
      end
      
    end
    
    context 'when the argument is an integer range' do
      
      before do
        @list = create_list @docs
      end
      
      it 'returns the document with indexes in the given range' do
        @list[0..1].should == [@docs[0], @docs[1]]
      end
      
      it 'returns only the documents corresponding to existing indexes if the argument is partially out of range' do
        @list[0..5].should == @docs
      end
      
      it 'returns nil if the argument is out of range' do
        @list[5..9].should be_nil
      end
      
    end
    
    context 'when called with a KDE::Url' do
      
      before do
        @docs << Ruber::Document.new(Ruber[:world],__FILE__)
        @list = create_list @docs
      end
      
      it 'returns the document associated with the argument' do
        @list[KDE::Url.new(__FILE__)].should == @docs[-1]
      end
      
      it 'returns the first of the documents associated with the argument if there is more than one document for the given URL' do
        doc = Ruber::Document.new Ruber[:world], __FILE__
        @list = create_list @docs + [doc]
        @list[KDE::Url.new(__FILE__)].should == @docs[-1]
      end
      
      it 'returns nil if there\'s no document associated with the given URL' do
        @list[KDE::Url.new('file:///xyz')].should be_nil
      end
      
    end
    
    context 'when called with a string starting with a slash' do
      
      before do
        @docs << Ruber::Document.new(Ruber[:world], __FILE__)
        @list = create_list @docs
      end
      
      it 'returns the document associated with the file corresponding to the argument' do
        @list[__FILE__].should == @docs[-1]
      end
      
      it 'returns the first of the documents associated with the argument if there is more than one document for the given URL' do
        doc = Ruber::Document.new Ruber[:world], __FILE__
        @list = create_list @docs + [doc]
        @list[__FILE__].should == @docs[-1]
      end
      
      it 'doesn\'t return remote files' do
        url = KDE::Url.new("http://xyz.it#{__FILE__}")
        remote_doc = Ruber::Document.new Ruber[:world], url
        @list = create_list @docs + [remote_doc]
        @list[__FILE__].should == @docs[-1]
      end
      
      it 'returns nil if there\'s no local file associated with the given file' do
        @docs.delete_at -1
        @list = create_list @docs
        @list[__FILE__].should be_nil
        url = KDE::Url.new("http://xyz.it#{__FILE__}")
        remote_doc = Ruber::Document.new Ruber[:world], url
        @list = create_list @docs + [remote_doc]
        @list[__FILE__].should be_nil
      end
      
    end
    
    context 'when called with a string not starting with a slash' do
      
      before do
        flexmock(@docs[1]).should_receive(:document_name).and_return('doc1')
        flexmock(@docs[2]).should_receive(:document_name).and_return('doc2')
        @list = create_list @docs
      end
      
      it 'returns the document with having the argument as document name' do
        @list['doc1'].should == @docs[1]
      end
      
      it 'returns the first of the documents with the given document name if there is more than one document with that document name' do
        doc = Ruber::Document.new Ruber[:world]
        flexmock(doc).should_receive(:document_name).and_return('doc1')
        @list = create_list @docs + [doc]
        @list['doc1'].should == @docs[1]
      end
      
      it 'returns nil if there\'s no document with the given document name' do
        @list['xyz'].should be_nil
      end
      
    end
    
  end
  
  describe '#document_for_file' do
    
    before do
      @docs = [Ruber::Document.new(Ruber[:world]), Ruber::Document.new(Ruber[:world], __FILE__), Ruber::Document.new(Ruber[:world])]
      @list = create_list @docs
    end
    
    it 'returns the document associated with the given file' do
      @list.document_for_file(__FILE__).should == @docs[1]
    end
    
    it 'returns nil if there\'s no document associated with the given file' do
      @list.document_for_file('/xyz').should be_nil
    end
    
    it 'doesn\'t return remote files' do
      @docs.delete_at 1
      url = KDE::Url.new("http://www.xyz.org#{__FILE__}")
      @list = create_list @docs + [Ruber::Document.new(Ruber[:world], url)]
      @list.document_for_file(__FILE__).should be_nil
    end
    
    it 'returns the first document associated with the given file, if more than one document is associated with it' do
      @list = create_list @docs + [Ruber::Document.new(Ruber[:world], __FILE__)]
      @list.document_for_file(__FILE__).should == @docs[1]
    end
    
    it 'raises ArgumentError if the file name is relative' do
      file = File.basename(__FILE__)
      lambda{@list.document_for_file file}.should raise_error(ArgumentError, "#{file} is not an absolute path")
    end
    
  end
  
  describe '#document_for_file?' do
    
    before do
      @docs = [Ruber::Document.new(Ruber[:world]), Ruber::Document.new(Ruber[:world], __FILE__), Ruber::Document.new(Ruber[:world], )]
      @list = create_list @docs
    end
    
    it 'returns true if there\'s a document associated with the given file' do
      @list.document_for_file?(__FILE__).should == true
    end
    
    it 'returns false if there\'s no document associated with the given file' do
      @list.document_for_file?('/xyz').should == false
    end
    
    it 'raises ArgumentError if the file name is relative' do
      file = File.basename(__FILE__)
      lambda{@list.document_for_file? file}.should raise_error(ArgumentError, "#{file} is not an absolute path")
    end
    
  end
  
  describe '#document_for_url' do
    
    before do
      @docs = [Ruber::Document.new(Ruber[:world]), Ruber::Document.new(Ruber[:world], __FILE__), Ruber::Document.new(Ruber[:world])]
      @list = create_list @docs
    end
    
    it 'returns the document associated with the given URL' do
      @list.document_for_url(KDE::Url.new(__FILE__)).should == @docs[1]
    end
    
    it 'returns nil if there\'s no document associated with the given file' do
      @list.document_for_url(KDE::Url.new('http://xyz.org/abc')).should be_nil
    end
    
    it 'works if the URL is specified as a string' do
      @list.document_for_url('file://'+__FILE__).should == @docs[1]
    end
    
    it 'returns the first document associated with the given URL, if more than one document is associated with it' do
      @list = create_list @docs + [Ruber::Document.new(Ruber[:world], __FILE__)]
      @list.document_for_url(KDE::Url.new(__FILE__)).should == @docs[1]
    end
    
  end
  
  describe '#document_for_url?' do
    
    before do
      @docs = [Ruber::Document.new(Ruber[:world]), Ruber::Document.new(Ruber[:world], __FILE__), Ruber::Document.new(Ruber[:world])]
      @list = create_list @docs
    end
    
    it 'returns true if there\'s a document associated with the given URL' do
      @list.document_for_url?(KDE::Url.new(__FILE__)).should == true
    end
    
    it 'returns false if there\'s no document associated with the given URL' do
      @list.document_for_url?(KDE::Url.new('/xyz')).should == false
    end
    
    it 'also works if the URL is specified as a string' do
      @list.document_for_url?('file://'+__FILE__).should == true
    end
    
  end
  
  describe '#document_with_name' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new Ruber[:world]}
      flexmock(@docs[0]).should_receive(:document_name).and_return 'doc0'
      flexmock(@docs[2]).should_receive(:document_name).and_return 'doc2'
      @list = create_list @docs
    end
    
    it 'returns the document with the given document_name' do
      @list.document_with_name('doc0').should == @docs[0]
    end
    
    it 'returns nil if there\'s no document with the given document name' do
      @list.document_with_name('doc3').should be_nil
    end
    
    it 'returns the first document with the given document name, if there is more  than one document with that name' do
      doc = Ruber::Document.new Ruber[:world]
      flexmock(doc).should_receive(:document_name).and_return 'doc0'
      @list = create_list @docs + [doc]
      @list.document_with_name('doc0').should == @docs[0]
    end
    
  end
  
  describe '#document_with_name?' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new Ruber[:world]}
      flexmock(@docs[0]).should_receive(:document_name).and_return 'doc0'
      flexmock(@docs[2]).should_receive(:document_name).and_return 'doc2'
      @list = create_list @docs
    end
    
    it 'returns true if there\'s a document with the given name' do
      @list.document_with_name?('doc0').should == true
    end
    
    it 'returns false if there\'s no document associated with the given URL' do
      @list.document_with_name?('doc3').should == false
    end
    
  end
  
  describe 'Ruber::Document#documents_with_file' do
    
    before do
      @all_docs = []
      @empty_docs = []
      @local_docs = []
      @remote_docs = []
      @empty_docs << Ruber::Document.new(Ruber[:world]) << Ruber::Document.new(Ruber[:world])
      @local_docs << Ruber::Document.new(Ruber[:world], __FILE__) << Ruber::Document.new( Ruber[:world], File.join(File.dirname(__FILE__), 'common.rb'))
      @remote_docs << Ruber::Document.new(Ruber[:world], KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/ruber.gemspec')) << Ruber::Document.new(Ruber[:world],
        KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/bin/ruber'))
      @all_docs << @empty_docs[0] << @local_docs[0] << @remote_docs[0] << @remote_docs[1] << @local_docs[1] << @empty_docs[1]
      @list = create_list @all_docs
    end
    
    it 'returns an array containing only the documents associated with local files if called with the :local argument' do
      @list.documents_with_file(:local).should == @local_docs
    end
    
    it 'returns an array containing only the documents associated with remote files if called with the :remote argument' do
      @list.documents_with_file(:remote).should == @remote_docs
    end
    
    it 'returns an array containing the documents associated with any file when called with the :any argument' do
      @list.documents_with_file(:any).should == [@local_docs[0], @remote_docs[0], @remote_docs[1], @local_docs[1]]
    end
    
    it 'returns an array containing the documents associated with any file when called with no arguments' do
      @list.documents_with_file.should == [@local_docs[0], @remote_docs[0], @remote_docs[1], @local_docs[1]]
    end
    
  end
  
end

describe Ruber::World::MutableDocumentList do
  
  before do
    @list = Ruber::World::MutableDocumentList.new
  end
  
  it 'inherits from Ruber::World::DocumentList' do
    Ruber::World::DocumentList.ancestors.should include(Ruber::World::DocumentList)
  end

  describe '#initialize' do
    
    context 'when called with no arguments' do
    
      it 'creates an empty list' do
        @list.should be_empty
      end
      
    end
    
    context 'when called with an array as argument' do
      
      it 'creates a list containing the same documents as the argument' do
        docs = 3.times.map{Ruber::Document.new Ruber[:world]}
        @list = Ruber::World::MutableDocumentList.new docs
        @list.to_a.should == docs
      end
      
      it 'creates a duplicate of the argument' do
        docs = 3.times.map{Ruber::Document.new Ruber[:world]}
        @list = Ruber::World::MutableDocumentList.new docs
        new_doc = Ruber::Document.new Ruber[:world]
        @list.add new_doc
        docs.size.should == 3
      end
      
    end
    
    context 'when called with a DocumentList as argument' do
      
      it 'creates a list containing the same documents as the argument' do
        docs = 3.times.map{Ruber::Document.new Ruber[:world]}
        orig = Ruber::World::MutableDocumentList.new docs
        @list = Ruber::World::MutableDocumentList.new orig
        @list.to_a.should == docs
      end
      
      it 'creates a duplicate of the argument' do
        docs = 3.times.map{Ruber::Document.new Ruber[:world]}
        orig = Ruber::World::MutableDocumentList.new docs
        @list = Ruber::World::MutableDocumentList.new orig
        new_doc = Ruber::Document.new Ruber[:world]
        @list.add new_doc
        orig.size.should == 3
      end
      
    end
    
  end
  
  describe '#dup' do
    
    it 'duplicates the document list' do
      docs = 3.times.map{Ruber::Document.new Ruber[:world]}
      @list.add docs
      new_list = @list.dup
      new_list.remove docs[1]
      @list.should == docs
    end
    
  end
  
  describe '#clone' do
    
    it 'duplicates the document list' do
      docs = 3.times.map{Ruber::Document.new Ruber[:world]}
      @list.add docs
      new_list = @list.clone
      new_list.remove docs[1]
      @list.should == docs
    end
    
    it 'copies the frozen status of the document list' do
      docs = 3.times.map{Ruber::Document.new Ruber[:world]}
      @list.add docs
      @list.freeze
      new_list = @list.clone
      new_list.should be_frozen
      lambda{new_list.add Ruber::Document.new Ruber[:world]}.should raise_error(RuntimeError)
    end
    
  end
  
  describe '#add' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new Ruber[:world]}
    end
    
    it 'appends the given documents to the list' do
      @list.add @docs[0]
      @list.to_a.should == [@docs[0]]
      @list.add *@docs[1..-1]
      @list.to_a.should == @docs
    end
    
    it 'treats arrays of documents as if each document was an argument by itself' do
      @list.add @docs
      @list.to_a.should == @docs
    end
    
    it 'returns self' do
      @list.add(@docs).should equal(@list)
    end
    
  end
  
  describe '#uniq!' do
    
    it 'removes all duplicate elements from the list' do
      docs = [Ruber::Document.new(Ruber[:world]), Ruber::Document.new(Ruber[:world], __FILE__)]
      @list.add docs
      @list.add docs[0]
      @list.uniq!
      @list.should == docs
    end
    
    it 'returns self' do
      @list.uniq!.should == @list
    end
    
  end
  
  describe '#merge!' do
    
    before do
      @docs = 5.times.map{Ruber::Document.new Ruber[:world]}
      @list.add @docs[3..4]
    end
    
    it 'adds the contents of the argument to self' do
      other = Ruber::World::MutableDocumentList.new @docs[0..2]
      @list.merge!(other).should == @docs[3..4]+@docs[0..2]
    end
    
    it 'also works with an array argument' do
      @list.merge!(@docs[0..2]).should == @docs[3..4]+@docs[0..2]
    end
    
    it 'returns self' do
      @list.merge!(@docs[0..2]).should equal(@list)
    end
    
    it 'removes duplicate elements from the list if the second parameter is true' do
      @list.merge!(@docs[0..3], true).should == @docs[3..4]+@docs[0..2]
    end
    
    it 'doesn\'t remove duplicate elements from the list if the second parameter is false' do
      @list.merge!(@docs[0..3], false).should == @docs[3..4]+@docs[0..3]
    end
    
  end
  
  describe '#remove' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new Ruber[:world]}
      @list.add @docs
    end
      
    it 'removes the document from the list' do
      @list.remove @docs[1]
      @list.to_a.should == [@docs[0], @docs[2]]
    end
    
    it 'does nothing if the document is not in the list' do
      @list.remove Ruber::Document.new Ruber[:world]
      @list.to_a.should == @docs
    end
    
    it 'returns the removed document, if any' do
      @list.remove(@docs[1]).should == @docs[1]
    end
    
    it 'returns nil if no document was removed' do
      @list.remove(Ruber::Document.new Ruber[:world]).should be_nil
    end
    
  end
  
  describe '#clear' do
    
    it 'removes all elements from the list' do
      @list.add 3.times.map{Ruber::Document.new Ruber[:world]}
      @list.clear
      @list.should be_empty
    end
    
    it 'returns self' do
      @list.clear.should equal(@list)
    end
    
  end
  
  describe '#delete_if' do
    
    before do
      @docs = [Ruber::Document.new(Ruber[:world]), Ruber::Document.new(Ruber[:world], __FILE__), Ruber::Document.new(Ruber[:world])]
      @list.add @docs
    end
    
    it 'removes all the elements for which the block returns true' do
      @list.delete_if{|doc| !doc.has_file?}
      @list.should == [@docs[1]]
    end
    
    it 'returns self' do
      @list.delete_if{|doc| !doc.has_file?}.should equal(@list)
    end
    
  end
  
end