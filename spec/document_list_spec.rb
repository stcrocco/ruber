require './spec/common'
require 'pathname'

require 'ruber/utils'
require 'ruber/documents/document_list'
require 'ruber/plugin_specification'

describe Ruber::DocumentList do
  
  before do
    @app = KDE::Application.instance
    @pdf = Ruber::PluginSpecification.full({:name => :documents, :class => Ruber::DocumentList})
    @manager = flexmock("manager"){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return @app
    flexmock(Ruber).should_receive(:[]).with(:components).and_return @manager
    flexmock(Ruber).should_receive(:[]).with(:config).and_return nil
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return @mw
    @keeper = Ruber::DocumentList.new @manager, @pdf
    flexmock(Ruber).should_receive(:[]).with(:docs).and_return @keeper
    flexmock(Ruber).should_receive(:[]).with(:documents).and_return @keeper
  end
  
  after do
    @keeper.instance_variable_get(:@docs).each{|d| d.dispose rescue nil}
  end
  
  it 'should be Enumerable' do
    Ruber::DocumentList.ancestors.include?(Enumerable).should be_true
  end

  it 'should have no documents when created' do
    @keeper.should be_empty
  end
  
  it 'should call the initialize_plugin method' do
    @keeper.plugin_description.should == @pdf
  end

  describe 'Ruber::DocumentList#[]' do
    
    context 'when called with an integer argument' do
      
      before do
        @docs = 4.times.map do 
          doc = Ruber::Document.new Ruber[:main_window]
          @keeper.add_document doc
          doc
        end
      end
      
      it 'returns the document in the given position' do
        res = []
        4.times{|i| res[i] = @keeper[i]}
        res.should == @docs
      end
      
      it 'returns nil if the index is out of range' do
        @keeper[5].should be_nil
      end
    
    end
    
    context 'when called with a string representing an absolute path' do
      
      it 'returns the document associated with the path' do
        doc = Ruber::Document.new Ruber[:main_window], __FILE__
        @keeper.add_document doc
        @keeper[File.expand_path(__FILE__)].should == doc
      end
    
      it 'returns nil if a document for that file doesn\'t exist' do
        @keeper[`which ruby`].should be_nil
      end
      
    end
    
    context 'when called with a string which doensn\'t represent an absolute path' do
      
      it 'returns the document with the given document_name' do
        doc = Ruber::Document.new Ruber[:main_window], __FILE__
        @keeper.add_document doc
        @keeper[doc.document_name].should == doc
      end
      
      it 'returns nil if no document with the given document name exists' do
        @keeper['abcd'].should be_nil
      end
      
    end
    
    context 'when called with a KDE::Url' do
      
      it 'returns the document associated with the url' do
        url = KDE::Url.new 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
        doc = Ruber::Document.new Ruber[:main_window], url
        @keeper.add_document doc
        @keeper[url].should == doc
      end
      
      it 'returns nil if no document is associated with the given url' do
        url = KDE::Url.new 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
        @keeper[url].should be_nil
      end
      
    end

    context 'when called with any other argument' do

      it 'raises TypeError' do
        doc = @keeper.document __FILE__
        lambda{@keeper[1.2]}.should raise_error(TypeError)
        lambda{@keeper[{}]}.should raise_error(TypeError)
        lambda{@keeper[:xyz]}.should raise_error(TypeError)
      end
    
    end

  end

  describe 'Ruber::Document#document_for_file' do

    it 'returns the document corresponding to the given absolute path or nil' do
      doc = @keeper.document __FILE__
      @keeper.document_for_file( File.expand_path(__FILE__)).should == doc
      @keeper.document_for_file('/test').should be_nil
    end

    it 'returns the document corresponding to the given relative path (expanding it) or nil' do
      doc = @keeper.document __FILE__
      @keeper.document_for_file( __FILE__).should == doc
      @keeper.document_for_file('test').should be_nil
    end

  end

  describe 'Ruber::Document#document_with_name' do
    
    it 'should return the document with the given document_name or nil' do
      doc = @keeper.document __FILE__
      @keeper.document_with_name( File.basename(__FILE__)).should == doc
      @keeper.document_for_file('test').should be_nil
    end

  end
  
  describe '#document_for_url' do
    
    it 'returns the document associated with the given KDE::Url' do
      url = KDE::Url.new 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
      doc = Ruber::Document.new Ruber[:main_window], url
      @keeper.add_document doc
      @keeper.document_for_url(url).should == doc
    end
    
    it 'converts the argoment to a KDE::Url if it\'s a string' do
      str = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
      url = KDE::Url.new str
      doc = Ruber::Document.new Ruber[:main_window], url
      @keeper.add_document doc
      @keeper.document_for_url(str).should == doc
    end
    
    it 'returns nil if no document corresponding to the url exists' do
      url = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
      @keeper.document_for_url(KDE::Url.new(url)).should be_nil
      @keeper.document_for_url(url).should be_nil
    end
    
  end

  describe '#each' do
    
    context 'when called with a block' do

      it 'allows to iterate on all documents (in creation order)' do
        docs = 4.times.map{@keeper.new_document}
        res = []
        @keeper.each{|d| res << d}
        res.should == docs
      end
      
      it 'returns self' do
        docs = 4.times.map{@keeper.new_document}
        @keeper.each{|d| d}.should equal(@keeper)
      end
    
    end
    
    context 'when called without a block' do
      
      it 'returns an enumerator which allows to iterate on all documents in creation order and returns the list' do
        docs = 4.times.map{@keeper.new_document}
        e = @keeper.each
        e.should be_an(Enumerable)
        res = []
        obj = e.each{|d| res << d}
        res.should == docs
        obj.should == @keeper
      end

    end


  end

  describe 'Ruber::Document#each_document' do
  
    it 'should allow to iterate on all documents (in creation order) when called with a block' do
      docs = 4.times.map{@keeper.new_document}
      res = []
      @keeper.each_document{|d| res << d}
      res.should == docs
    end
  
    it 'should return an enumerator which allows to iterate on all documents in creation order when called without a block' do
      docs = 4.times.map{@keeper.new_document}
      e = @keeper.each_document
      e.should be_an(Enumerable)
      res = []
      e.each{|d| res << d}
      res.should == docs
    end
  
  end

  describe 'Ruber::Document#documents' do

    it 'should return an array with all the documents, in an arbitrary order' do
      docs = 4.times.map{@keeper.new_document}
      res = @keeper.documents
      res.should be_kind_of(Array)
      res.should == docs
    end

  end

  describe 'Ruber::Document#to_a' do

    it 'should return an array with all the documents, in an arbitrary order' do
      docs = 4.times.map{@keeper.new_document}
      res = @keeper.to_a
      res.should be_kind_of(Array)
      res.should == docs
    end

  end

  describe 'Ruber::Document#document_for_file?' do

    it 'should tell whether there\'s a document for the given filename if called with an absolute filename' do
      @keeper.document __FILE__
      @keeper.document_for_file?( File.expand_path(__FILE__) ).should be_true
      @keeper.document_for_file?('/test').should be_false
    end

    it 'should tell whether there\'s a document for the given filename if called with a relative filename (which will be expanded)' do
      @keeper.document __FILE__
      @keeper.document_for_file?( __FILE__ ).should be_true
      @keeper.document_for_file?('test').should be_false
    end

  end
  
  describe '#document_for_url?' do
    
    it 'returns true if a document associated with the given KDE::Url exists' do
      url = KDE::Url.new 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
      doc = Ruber::Document.new Ruber[:main_window], url
      @keeper.add_document doc
      @keeper.document_for_url?(url).should be_true
    end
    
    it 'converts the argoment to a KDE::Url if it\'s a string' do
      str = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
      url = KDE::Url.new str
      doc = Ruber::Document.new Ruber[:main_window], url
      @keeper.add_document doc
      @keeper.document_for_url?(str).should be_true
    end
    
    it 'returns false if no document corresponding to the url exists' do
      url = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
      @keeper.document_for_url(KDE::Url.new(url)).should be_false
      @keeper.document_for_url(url).should be_false
    end

  end

  describe 'Ruber::Document#document_with_name' do

    it 'should tell whether there\'s a document with the given document_name' do
      @keeper.document __FILE__
      @keeper.document_with_name?( File.basename(__FILE__ )).should be_true
      @keeper.document_with_name?('test').should be_false
    end

  end

  describe 'Ruber::Document#documents_with_file' do
    
    before do
      @all_docs = []
      @empty_docs = []
      @local_docs = []
      @remote_docs = []
      @empty_docs << Ruber::Document.new << Ruber::Document.new
      @local_docs << Ruber::Document.new(nil, __FILE__) << Ruber::Document.new(nil, File.join(File.dirname(__FILE__), 'common.rb'))
      @remote_docs << Ruber::Document.new(nil, KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/ruber.gemspec')) << Ruber::Document.new(nil,
        KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/bin/ruber'))
      @all_docs << @empty_docs[0] << @local_docs[0] << @remote_docs[0] << @remote_docs[1] << @local_docs[1] << @empty_docs[1]
      @all_docs.each{|d| @keeper.add_document d}
    end
    
    describe 'when called with the :local argument' do
      it 'returns an array containing only the documents associated with local files' do
        @keeper.documents_with_file(:local).should == @local_docs
      end
    end
    
    describe 'when called with the :remote argument' do
      it 'returns an array containing only the documents associated with remote files' do
        @keeper.documents_with_file(:remote).should == @remote_docs
      end
    end
    
    describe 'when called with the :any argument' do
      it 'returns an array containing the documents associated with any file' do
        @keeper.documents_with_file(:any).should == [@local_docs[0], @remote_docs[0], @remote_docs[1], @local_docs[1]]
      end
    end
    
    describe 'when called with no arguments' do
      it 'returns an array containing the documents associated with any file' do
        @keeper.documents_with_file.should == [@local_docs[0], @remote_docs[0], @remote_docs[1], @local_docs[1]]
      end
    end

  end

  describe 'Ruber::DocumentList#close_all' do
    
    before do
      flexmock(@mw).should_receive(:save_documents).by_default.and_return(true)
      pdf = Ruber::PluginSpecification.full({:name => :documents, :class => Ruber::DocumentList})
      @docs = Array.new(5){|i| flexmock("doc #{i}"){|m| m.should_receive(:close).and_return(true).by_default}}
      5.times {|i| flexmock(Ruber::Document).should_receive(:new).and_return(@docs[i])}
      @keeper.instance_variable_set :@docs, @docs.dup
    end

    it 'should call Ruber[:main_window].save_documents passing it all the documents, if the argument is true' do
      @mw.should_receive(:save_documents).once.with(@docs).and_return true
      @keeper.close_all
    end

    it 'should return immediately if the call Ruber[:main_window].save_documents returns false' do
      @mw.should_receive(:save_documents).once.with(@docs).and_return false
      @docs.each{|d| d.should_receive(:close).never}
      @keeper.close_all
    end
    
    it 'shouldn\'t call Ruber[:main_window].save_documents if the argument is false' do
      @mw.should_receive(:save_documents).never
      @keeper.close_all false
    end
    
    it 'should close each document, passing false argument as argument' do
      @mw.should_receive(:save_documents).and_return true
      @docs.each{|d| d.should_receive(:close).once.and_return true}
      @keeper.close_all false
    end
    
    it 'should return true if the documents where closed and false otherwise' do
      @mw.should_receive(:save_documents).once.with(@docs).and_return true
      @keeper.close_all.should be_true
      @mw.should_receive(:save_documents).once.with(@docs).and_return false
      @keeper.close_all.should_not be
    end
    
  end

  describe 'Ruber::DocumentList, when a document is closed' do

    
    it 'should emit the "document_closing(QObject*)" signal, passing the document as argument' do
      doc = @keeper.new_document
      exp = doc.object_id
      m = flexmock{|mk| mk.should_receive(:closing_document).once.with(exp)}
      @keeper.connect(SIGNAL('closing_document(QObject*)')){|d| m.closing_document d.object_id}
      doc.close
    end
    
    it 'should remove the closed file from the list, without leaving a hole' do
      docs = 3.times.map{ @keeper.new_document}
      docs[1].close false
      @keeper.size.should == docs.size - 1
      @keeper[0].should == docs[0]
      @keeper[1].should == docs[2]
      @keeper.to_a.should == @keeper.to_a.compact
    end

  end

  describe 'Ruber::DocumentList#new_document' do
    
    it 'should create and return a new empty document' do
      doc = @keeper.new_document
      doc.should be_kind_of(Ruber::Document)
      doc.should be_pristine
    end
    
    it 'should add the new document to the list' do
      doc = @keeper.new_document
      @keeper.documents.should == [doc]
    end
    
    it 'should connect the "closing(QObject*)" signal of the document to the "close_document(QObject*) slot' do
      doc = Ruber::Document.new
      flexmock(Ruber::Document).should_receive(:new).with(@mw).once.and_return(doc)
      flexmock(@keeper).should_receive(:close_document).once
      @keeper.new_document
      doc.close
    end
    
    it 'should emit the "document_created(QObject*)" signal passing the document as argument' do
      doc = Ruber::Document.new
      exp = doc.object_id
      flexmock(Ruber::Document).should_receive(:new).with(@mw).once.and_return(doc)
      m = flexmock{|mk| mk.should_receive(:document_created).with(exp).once}
      @keeper.connect(SIGNAL('document_created(QObject*)')){|d| m.document_created d.object_id}
      @keeper.new_document
    end
    
  end

  describe '#document' do
    
    context 'when a document for the given file or url already exists' do

      it 'doesn\'t create a new document but return the existing one if a document for the given file or url already exists in the list' do
        url = KDE::Url.new 'http://github.com/stcrocco/ruber/raw/ruber.gemspec'
        doc1 = Ruber::Document.new nil, __FILE__
        doc2 = Ruber::Document.new nil, url
        @keeper.add_document doc1
        @keeper.add_document doc2
        flexmock(Ruber::Document).should_receive(:new).never
        @keeper.document(__FILE__).should equal(doc1)
        #Since the tests are run from the top directory, we need to prepend the spec directory
        @keeper.document(File.expand_path(File.join('spec', File.basename(__FILE__)))).should equal(doc1)
        @keeper.document(url).should equal(doc2)
      end
      
    end
    
    context 'when a document for the given file or url doesn\'t exist' do
      
      context 'and the second argument is false' do
        
        it 'returns nil' do
          @keeper.document( File.expand_path(__FILE__), false).should be_nil
          @keeper.document(KDE::Url.new('http://github.com/stcrocco/ruber/raw/ruber.gemspec'), false).should be_nil
          @keeper.documents.should == []
        end
        
      end
      
      context 'and the second argument is true' do
        
        it 'creates a new document for the given file or url' do
          url = KDE::Url.new 'http://github.com/stcrocco/ruber/raw/ruber.gemspec'
          doc = @keeper.document __FILE__
          doc.should be_kind_of( Ruber::Document)
          doc.path.should ==  __FILE__
          doc.text.should == File.read( __FILE__)
          doc = @keeper.document url
          doc.url.should == url
        end
        
        it 'raises ArgumentError if the argument is a string or local url and the corresponding file doesn\'t exist' do
          lambda{@keeper.document 'test'}.should raise_error(ArgumentError, "File #{File.expand_path 'test'} doesn't exist")
          lambda{@keeper.document File.expand_path('test')}.should raise_error(ArgumentError, "File #{File.expand_path 'test'} doesn't exist")
          lambda{@keeper.document KDE::Url.new('file:///test')}.should raise_error(ArgumentError, "File #{'/test'} doesn't exist")
        end
        
        it 'doesn\'t raise ArgumentError if the argument is a remote url which doesn\'t exist' do
          lambda{@keeper.document KDE::Url.new('http://xyz/abc.def')}.should_not raise_error
        end
        
        it 'adds the new document to the list of documents' do
          doc = @keeper.document __FILE__
          @keeper.documents.size.should == 1
          @keeper.documents.include?(doc).should be_true
        end
        
        it 'connects the "closing(QObject*)" signal of the new document to the "close_document(QObject*) slot' do
          file = File.expand_path(__FILE__)
          doc = Ruber::Document.new @keeper, file
          flexmock(Ruber::Document).should_receive(:new).with(@mw, file).once.and_return(doc)
          flexmock(@keeper).should_receive(:close_document).once
          @keeper.document __FILE__
          doc.close
        end
        
        it 'emits the "document_created(QObject*)" signal passing the new document as argument' do
          file = File.expand_path(__FILE__)
          doc = Ruber::Document.new nil, file
          exp = doc.object_id
          flexmock(Ruber::Document).should_receive(:new).with(@mw, file).once.and_return(doc)
          m = flexmock{|mk| mk.should_receive(:document_created).with(exp).once}
          @keeper.connect(SIGNAL('document_created(QObject*)')){|d| m.document_created d.object_id}
          @keeper.document __FILE__
        end
        
        it 'closes the already-existing document when called with a path and the only existing document is pristine' do
          old = @keeper.new_document
          Qt::Object.connect old, SIGNAL('closing(QObject*)'), @keeper, SLOT('close_document(QObject*)')
          doc = @keeper.document __FILE__
          @keeper[0].should == doc
          @keeper.size.should == 1
        end
        
      end
      
    end
    
    it 'expands the given file name relative to the current directory if the file name is relative' do
      flexmock(Ruber::Document).should_receive(:new).with(@mw, File.expand_path(__FILE__))
      doc = @keeper.document __FILE__
      # this is necessary because otherwise the 'after' block fails (because the document list contains nil)
      @keeper.instance_variable_get(:@docs).clear
    end

  end

  describe '#add_document' do
    
    it 'adds the given document to the list of documents' do
      doc = Ruber::Document.new
      @keeper.add_document doc
      @keeper.documents.size.should == 1
      @keeper.documents.include?(doc).should be_true
    end
    
    it 'connects the "closing(QObject*)" signal of the given document to the "close_document(QObject*) slot' do
      file = File.expand_path(__FILE__)
      doc = Ruber::Document.new @keeper, file
      flexmock(@keeper).should_receive(:close_document).once
      @keeper.add_document doc
      doc.close
    end
    
  end

  describe '#save_documents' do
    
    before do
      @docs = [@keeper.document(__FILE__), @keeper.new_document, @keeper.new_document]
    end
    
    it 'saves all the documents passed as argument' do
      @docs.each{|d| flexmock(d).should_receive(:save).once}
      @keeper.save_documents @docs
    end
    
    it 'returns an empty array if all the documents were saved successfully' do
      @docs.each{|d| flexmock(d).should_receive(:save).once.and_return true}
      @keeper.save_documents( @docs).should == []
    end
    
    it 'returns an array containing the documents for which save returned false, if the second argument is false' do
      flexmock(@docs[0]).should_receive(:save).once.and_return true
      flexmock(@docs[2]).should_receive(:save).once.and_return true
      flexmock(@docs[1]).should_receive(:save).once.and_return false
      @keeper.save_documents( @docs, false).should == [@docs[1]]
    end
    
    it 'doesn\'t call the save method on all remaining documents if one fails, if the second argument is true' do
      flexmock(@docs[0]).should_receive(:save).once.and_return true
      flexmock(@docs[1]).should_receive(:save).once.and_return false
      flexmock(@docs[2]).should_receive(:save).never
      @keeper.save_documents( @docs, true)
    end
    
    it 'returns an array containing the first document for which save returned false and all the documents which weren\'t saved if the second argument is true' do
      flexmock(@docs[0]).should_receive(:save).once.and_return true
      flexmock(@docs[1]).should_receive(:save).once.and_return false
      flexmock(@docs[2]).should_receive(:save).never
      @keeper.save_documents( @docs, true).should == @docs[1..-1]
    end
    
  end
  
  describe '#save_settings' do
  
    it 'calls the save_settings method of each document\'s own project' do
      docs = [@keeper.document(__FILE__), @keeper.new_document, @keeper.new_document]
      docs.each{|d| flexmock(d).should_receive(:save_settings).once}
      @keeper.save_settings
    end
    
  end
  
  describe '#query_close' do
    
    before do
      @docs = [@keeper.document(__FILE__), @keeper.new_document, @keeper.new_document]
    end
    
    it 'calls the query_close method of each document\'s own project and returns false if one of them returns false' do
      flexmock(@docs[0].own_project).should_receive(:query_close).once.and_return true
      flexmock(@docs[1].own_project).should_receive(:query_close).once.and_return false
      flexmock(@docs[2].own_project).should_receive(:query_close).never.and_return(true)
      @keeper.query_close.should be_false
    end
    
    it 'calls the main window\'s close_documents method and return its value' do
      @docs.each{|d| flexmock(d.own_project).should_receive(:query_close).twice.and_return true}
      flexmock(@mw).should_receive(:save_documents).once.with_no_args.and_return true
      flexmock(@mw).should_receive(:save_documents).once.with_no_args.and_return false
      @keeper.query_close.should be_true
      @keeper.query_close.should be_false
    end
    
  end
  
end