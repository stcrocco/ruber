require './spec/framework'
require './spec/common'
require 'ruber/world/document_factory'

describe Ruber::World::DocumentFactory do
  
  it 'derives from Qt::Object' do
    Ruber::World::DocumentFactory.ancestors.should include(Qt::Object)
  end
  
  before do
    @factory = Ruber::World::DocumentFactory.new
  end
  
  describe '#document' do
    
    it 'returns a document having the object passed as second argument as parent' do
      obj = Qt::Object.new
      doc = @factory.document nil, obj
      doc.should be_a(Ruber::Document)
      doc.parent.should == obj
    end
    
    context 'when called with a file or URL as first argument' do
      
      it 'returns a new document for the given file, if no other document for it exists' do
        doc = @factory.document __FILE__
        doc.path.should == __FILE__
      end
      
      it 'returns an existing document for the same file, if it already exists' do
        old = @factory.document __FILE__
        new = @factory.document __FILE__
        new.should == old
      end
      
      it 'returns the existing file even if of the two calls to document one was passed a string and the other an URL' do
        old = @factory.document KDE::Url.new(__FILE__)
        new = @factory.document __FILE__
        new.should == old
      end
      
      it 'does not attempt to return a document which has been closed' do
        old = @factory.document __FILE__
        old.close
        new = @factory.document __FILE__
        new.should_not == old
      end
      
      it 'returns an existing document even if it was created without a file and saved with the new name later' do
        old = @factory.document nil
        url = KDE::Url.new __FILE__
        flexmock(old).should_receive(:url).and_return url
        old.instance_eval{emit document_url_changed(self)}
        new = @factory.document __FILE__
        new.should == old
      end
      
      it 'returns an existing document even if it was created for another file then
      saved with the new name later' do
        old = @factory.document File.join File.dirname(__FILE__), 'common.rb'
        url = KDE::Url.new __FILE__
        flexmock(old).should_receive(:url).and_return url
        old.instance_eval{emit document_url_changed(self)}
        new = @factory.document __FILE__
        new.should == old
      end
      
      it 'doesn\'t return a document which was created for the same file but was saved with another name later' do
        old = @factory.document __FILE__ 
        url = KDE::Url.new File.join(File.dirname(__FILE__), 'common.rb')
        flexmock(old).should_receive(:url).and_return url
        old.instance_eval{emit document_url_changed(self)}
        new = @factory.document __FILE__
        new.should_not == old
      end
      
      it 'returns nil if the file is a local file and it doesn\'t exist' do
        @factory.document('/xyz').should be_nil
        @factory.document(KDE::Url.new('/xyz')).should be_nil
      end
      
    end
    
    context 'when called with nil as first argument' do
      
      it 'always returns a new document' do
        old = @factory.document nil
        new = @factory.document nil
        new.should_not == old
      end
      
    end
    
    context 'when creating a new document' do
      
      it 'emits the document_created signal passing the document as argument' do
        docs = [Ruber::Document.new(__FILE__), Ruber::Document.new]
        flexmock(Ruber::Document).should_receive(:new).with(__FILE__,nil).once.and_return docs[0]
        flexmock(Ruber::Document).should_receive(:new).with(nil,nil).once.and_return docs[1]
        mk = flexmock do |m|
          m.should_receive(:document_created).with(docs[0]).once
          m.should_receive(:document_created).with(docs[1]).once
        end
        @factory.connect(SIGNAL('document_created(QObject*)')){|o| mk.document_created o}
        doc = @factory.document __FILE__
        @factory.document nil
        @factory.document __FILE__
      end
      
    end
    
  end
  
end
