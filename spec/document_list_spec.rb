require 'spec/common'
require 'pathname'

require 'ruber/utils'
require 'ruber/documents/document_list'
require 'ruber/plugin_specification'

describe 'a document_list method', :shared => true do

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
    @keeper.instance_variable_get(:@docs).each{|d| d.dispose}
  end

end

describe Ruber::DocumentList do

  it_should_behave_like 'a document_list method'

  it 'should be Enumerable' do
    Ruber::DocumentList.ancestors.include?(Enumerable).should be_true
  end

  it 'should have no documents when created' do
    @keeper.should be_empty
  end
  
  it 'should call the initialize_plugin method' do
    @keeper.plugin_description.should == @pdf
  end

end

describe 'Ruber::DocumentList#[]' do

  it_should_behave_like 'a document_list method'

  it 'should return the document in the given position when called with an integer argument' do
    docs = 4.times.map{@keeper.new_document}
    res = []
    4.times{|i| res[i] = @keeper[i]}
    res.should == docs
    @keeper[5].should be_nil
  end

  it 'should return the document associated with an absolute path or nil when called with an absolute path' do
    doc = @keeper.document __FILE__
    @keeper[File.expand_path(__FILE__)].should == doc
    @keeper[`which ruby`].should be_nil
  end

  it 'should return the document with the given document_name or nil if called with a string which is not an absolute path' do
    doc = @keeper.document __FILE__
    @keeper[doc.document_name].should == doc
    @keeper['abcd'].should be_nil
  end

  it 'should raise TypeError if called with any other argument' do
    doc = @keeper.document __FILE__
    lambda{@keeper[1.2]}.should raise_error(TypeError)
    lambda{@keeper[{}]}.should raise_error(TypeError)
    lambda{@keeper[:xyz]}.should raise_error(TypeError)
  end

end

describe 'Ruber::Document#document_for_file' do

  it_should_behave_like 'a document_list method'

  it 'should return the document corresponding to the given absolute path or nil' do
    doc = @keeper.document __FILE__
    @keeper.document_for_file( File.expand_path(__FILE__)).should == doc
    @keeper.document_for_file('/test').should be_nil
  end

  it 'should return the document corresponding to the given relative path (expanding it) or nil' do
    doc = @keeper.document __FILE__
    @keeper.document_for_file( __FILE__).should == doc
    @keeper.document_for_file('test').should be_nil
  end

end

describe 'Ruber::Document#document_with_name' do

  it_should_behave_like 'a document_list method'
  
  it 'should return the document with the given document_name or nil' do
    doc = @keeper.document __FILE__
    @keeper.document_with_name( File.basename(__FILE__)).should == doc
    @keeper.document_for_file('test').should be_nil
  end

end

describe 'Ruber::Document#each' do

  it_should_behave_like 'a document_list method'

#   it 'should allow to iterate on all documents (in creation order) when called with a block' do
#     docs = 4.times.map{@keeper.new_document}
#     res = []
#     @keeper.each{|d| res << d}
#     res.should == docs
#   end

#   it 'should return an enumerator which allows to iterate on all documents in creation order when called without a block' do
#     docs = 4.times.map{@keeper.new_document}
#     e = @keeper.each
#     e.should be_an(Enumerable)
#     res = []
#     e.each{|d| res << d}
#     res.should == docs
#   end

end

# describe 'Ruber::Document#each_document' do
# 
#   it_should_behave_like 'a document_list method'
# 
#   it 'should allow to iterate on all documents (in creation order) when called with a block' do
#     docs = 4.times.map{@keeper.new_document}
#     res = []
#     @keeper.each_document{|d| res << d}
#     res.should == docs
#   end
# 
#   it 'should return an enumerator which allows to iterate on all documents in creation order when called without a block' do
#     docs = 4.times.map{@keeper.new_document}
#     e = @keeper.each_document
#     e.should be_an(Enumerable)
#     res = []
#     e.each{|d| res << d}
#     res.should == docs
#   end
# 
# end

describe 'Ruber::Document#documents' do

  it_should_behave_like 'a document_list method'

  it 'should return an array with all the documents, in an arbitrary order' do
    docs = 4.times.map{@keeper.new_document}
    res = @keeper.documents
    res.should be_kind_of(Array)
    res.should == docs
  end

end

describe 'Ruber::Document#to_a' do

  it_should_behave_like 'a document_list method'

  it 'should return an array with all the documents, in an arbitrary order' do
    docs = 4.times.map{@keeper.new_document}
    res = @keeper.to_a
    res.should be_kind_of(Array)
    res.should == docs
  end

end

describe 'Ruber::Document#document_for_file?' do

  it_should_behave_like 'a document_list method'

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

describe 'Ruber::Document#document_with_name' do
  
  it_should_behave_like 'a document_list method'

  it 'should tell whether there\'s a document with the given document_name' do
    @keeper.document __FILE__
    @keeper.document_with_name?( File.basename(__FILE__ )).should be_true
    @keeper.document_with_name?('test').should be_false
  end

end

describe 'Ruber::Document#documents_with_file' do

  it_should_behave_like 'a document_list method'

  it 'should return an array containing only the documents associated with files' do
    @keeper.document __FILE__
    @keeper.new_document
    @keeper.documents_with_file.should == [@keeper[0]]
  end

end

describe 'Ruber::DocumentList#close_all' do
  
  before do
    @main_window = flexmock('main_window'){|mk| mk.should_receive(:save_documents).by_default.and_return true}
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return @main_window
    @app = KDE::Application.instance
    pdf = Ruber::PluginSpecification.full({:name => :documents, :class => Ruber::DocumentList})
    @manager = flexmock("manager"){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return @app
    flexmock(Ruber).should_receive(:[]).with(:components).and_return @manager
    flexmock(Ruber).should_receive(:[]).with(:config).and_return nil
    @keeper = Ruber::DocumentList.new @manager, pdf
    @docs = Array.new(5){|i| flexmock("doc #{i}"){|m| m.should_receive(:close).and_return(true).by_default}}
    5.times {|i| flexmock(Ruber::Document).should_receive(:new).and_return(@docs[i])}
    @keeper.instance_variable_set :@docs, @docs.dup
  end

  it 'should call Ruber[:main_window].save_documents passing it all the documents, if the argument is true' do
    @main_window.should_receive(:save_documents).once.with(@docs).and_return true
    @keeper.close_all
  end

  it 'should return immediately if the call Ruber[:main_window].save_documents returns false' do
    @main_window.should_receive(:save_documents).once.with(@docs).and_return false
    @docs.each{|d| d.should_receive(:close).never}
    @keeper.close_all
  end
  
  it 'shouldn\'t call Ruber[:main_window].save_documents if the argument is false' do
    @main_window.should_receive(:save_documents).never
    @keeper.close_all false
  end
  
  it 'should close each document, passing false argument as argument' do
    @main_window.should_receive(:save_documents).and_return true
    @docs.each{|d| d.should_receive(:close).once.and_return true}
    @keeper.close_all false
  end
  
  it 'should return true if the documents where closed and false otherwise' do
    @main_window.should_receive(:save_documents).once.with(@docs).and_return true
    @keeper.close_all.should be_true
    @main_window.should_receive(:save_documents).once.with(@docs).and_return false
    @keeper.close_all.should_not be
  end
  
end

describe 'Ruber::DocumentList, when a document is closed' do
  it_should_behave_like 'a document_list method'
  
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
  
  it_should_behave_like 'a document_list method'
  
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

describe 'Ruber::DocumentList#document' do

  it_should_behave_like 'a document_list method'
  
  it 'should not create a new document but return the existing one if a document for the given file already exists in the list' do
    doc1 = @keeper.document __FILE__
    flexmock(Ruber::Document).should_receive(:new).never
    doc2 = @keeper.document __FILE__
    doc2.should equal(doc1)
    doc3 = @keeper.document File.expand_path(__FILE__)
    doc3.should equal(doc1)
  end
  
  it 'should create a document for the given file if the list doesn\'t already contain one and return it if the first argument is true' do
    doc = @keeper.document File.expand_path(__FILE__)
    doc.should be_kind_of( Ruber::Document)
    doc.path.should == File.expand_path( __FILE__)
    doc.text.should == File.read( __FILE__)
  end
  
  it 'should return nil if a document for the given file doesn\'t exist and the second argument is false' do
    @keeper.document( File.expand_path(__FILE__), false).should be_nil
    @keeper.documents.should == []
  end
  
  it 'should expand the given file name relative to the current directory if the file name is relative' do
    flexmock(Ruber::Document).should_receive(:new).with(@mw, File.expand_path(__FILE__))
    doc = @keeper.document __FILE__
    # this is necessary because otherwise the 'after' block fails (because the document list contains nil)
    @keeper.instance_variable_get(:@docs).clear
  end
  
  it 'should raise ArgumentError if the file doesn\'t exist' do
    lambda{@keeper.document 'test'}.should raise_error(ArgumentError, "File #{File.expand_path 'test'} doesn't exist")
    lambda{@keeper.document File.expand_path('test')}.should raise_error(ArgumentError, "File #{File.expand_path 'test'} doesn't exist")
  end
  
  it 'should add the new document to the list of documents' do
    doc = @keeper.document __FILE__
    @keeper.documents.size.should == 1
    @keeper.documents.include?(doc).should be_true
  end
  
  it 'should connect the "closing(QObject*)" signal of the new document to the "close_document(QObject*) slot' do
    file = File.expand_path(__FILE__)
    doc = Ruber::Document.new @keeper, file
    flexmock(Ruber::Document).should_receive(:new).with(@mw, file).once.and_return(doc)
    flexmock(@keeper).should_receive(:close_document).once
    @keeper.document __FILE__
    doc.close
  end

  it 'should emit the "document_created(QObject*)" signal passing the new document as argument' do
    file = File.expand_path(__FILE__)
    doc = Ruber::Document.new nil, file
    exp = doc.object_id
    flexmock(Ruber::Document).should_receive(:new).with(@mw, file).once.and_return(doc)
    m = flexmock{|mk| mk.should_receive(:document_created).with(exp).once}
    @keeper.connect(SIGNAL('document_created(QObject*)')){|d| m.document_created d.object_id}
    @keeper.document __FILE__
  end
  
  it 'should close the already-existing document when called with a path and the only existing document is pristine' do
    old = @keeper.new_document
    Qt::Object.connect old, SIGNAL('closing(QObject*)'), @keeper, SLOT('close_document(QObject*)')
    doc = @keeper.document __FILE__
    @keeper[0].should == doc
    @keeper.size.should == 1
  end

end

describe 'Ruber::DocumentList#add_document' do

  it_should_behave_like 'a document_list method'
  
  it 'should add the given document to the list of documents' do
    doc = Ruber::Document.new
    @keeper.add_document doc
    @keeper.documents.size.should == 1
    @keeper.documents.include?(doc).should be_true
  end
  
  it 'should connect the "closing(QObject*)" signal of the given document to the "close_document(QObject*) slot' do
    file = File.expand_path(__FILE__)
    doc = Ruber::Document.new @keeper, file
    flexmock(@keeper).should_receive(:close_document).once
    @keeper.add_document doc
    doc.close
  end
  
end

describe 'Ruber::DocumentList#save_documents' do
  
  it_should_behave_like 'a document_list method'
  
  before do
    @docs = [@keeper.document(__FILE__), @keeper.new_document, @keeper.new_document]
  end
  
  it 'should save all the documents passed as argument' do
    @docs.each{|d| flexmock(d).should_receive(:save).once}
    @keeper.save_documents @docs
  end
  
  it 'should return an empty array if all the documents were saved successfully' do
    @docs.each{|d| flexmock(d).should_receive(:save).once.and_return true}
    @keeper.save_documents( @docs).should == []
  end
  
  it 'should return an array containing the documents for which save returned false, if the second argument is false' do
    flexmock(@docs[0]).should_receive(:save).once.and_return true
    flexmock(@docs[2]).should_receive(:save).once.and_return true
    flexmock(@docs[1]).should_receive(:save).once.and_return false
    @keeper.save_documents( @docs, false).should == [@docs[1]]
  end
  
  it 'should not call the save method on all remaining documents if one fails, if the second argument is true' do
    flexmock(@docs[0]).should_receive(:save).once.and_return true
    flexmock(@docs[1]).should_receive(:save).once.and_return false
    flexmock(@docs[2]).should_receive(:save).never
    @keeper.save_documents( @docs, true)
  end
  
  it 'should return an array containing the first document for which save returned false and all the documents which weren\'t saved if the second argument is true' do
    flexmock(@docs[0]).should_receive(:save).once.and_return true
    flexmock(@docs[1]).should_receive(:save).once.and_return false
    flexmock(@docs[2]).should_receive(:save).never
    @keeper.save_documents( @docs, true).should == @docs[1..-1]
  end
  
end

describe Ruber::DocumentList do
  
  it_should_behave_like 'a document_list method'
  
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