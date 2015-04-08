require 'spec/framework'
require 'spec/common'

require 'ruber/editor/projected_document'

describe Ruber::ProjectedDocument do
  
  before do
    @doc = Ruber::Document.new Ruber[:world], __FILE__
    @prj_doc = Ruber::ProjectedDocument.new @doc, Ruber[:world].default_environment
  end
  
  describe '.new' do
    
    it 'takes a document and an environment as arguments' do
      prj_doc = Ruber::ProjectedDocument.new @doc, Ruber[:world].default_environment
      prj_doc.should be_a(Ruber::ProjectedDocument)
    end
    
  end
  
  describe '#same_document?' do
    
    context 'when the argument is a Document' do
      
      it 'returns true if the document associated with self is the document passed as argument' do
        @prj_doc.should be_same_document(@doc)
      end
      
      it 'returns false if the document associated with self is not the document passed as argument' do
        other_doc = Ruber::Document.new Ruber[:world]
        @prj_doc.should_not be_same_document(other_doc)
      end
      
    end
    
    context 'when the argument is a ProjectedDocument' do
      
      before do
        @env = Ruber::World::Environment.new nil
      end
      
      it 'returns true if the document associated with self is the same document associated with the argument' do
        other = Ruber::ProjectedDocument.new @doc, @env
        @prj_doc.should be_same_document(other)
      end
      
      it 'returns false if the document associated with self is not the same document associated with the argument' do
        other_doc = Ruber::Document.new Ruber[:world]
        other = Ruber::ProjectedDocument.new other_doc, @env
        @prj_doc.should_not be_same_document(other)
      end

      
    end
    
  end
  
  describe '#own_project' do
    
    it 'calls the associated document\'s #own_project method passing the associated environment as argument' do
      prj = Qt::Object.new
      flexmock(@doc).should_receive(:own_project).with(@prj_doc.environment).once.and_return prj
      @prj_doc.own_project.should == prj
    end
    
  end
  
  describe '#project' do
    
    it 'calls the associated document\'s #project method passing the associated environment as argument' do
      prj = Qt::Object.new
      flexmock(@doc).should_receive(:project).with(@prj_doc.environment).once.and_return prj
      @prj_doc.project.should == prj
    end
    
  end
  
  describe '#extension' do
    
    it 'calls the associated document\'s #extension method passing the associated environment as second argument' do
      ext = Qt::Object.new
      flexmock(@doc).should_receive(:extension).with(:xyz, @prj_doc.environment).once.and_return ext
      @prj_doc.extension(:xyz).should == ext
    end
    
  end

  describe '#create_view' do
    
    context 'when called with an argument' do
      
      it 'calls the associated document\'s #create_view method passing the associated environment and the argument as arguments' do
        view = Qt::Widget.new
        parent = Qt::Widget.new
        flexmock(@doc).should_receive(:create_view).with(@prj_doc.environment, parent).once.and_return view
        @prj_doc.create_view(parent).should == view
      end
      
    end
    
    context 'when called without arguments' do
      
      it 'calls the associated document\'s #create_view method passing the associated environment as argument' do
        view = Qt::Widget.new
        flexmock(@doc).should_receive(:create_view).with(@prj_doc.environment, nil).once.and_return view
        @prj_doc.create_view.should == view
      end
      
    end

  end
  
  describe '#method_missing' do
    
    it 'forwards the method call to the underlying document' do
      flexmock(@doc).should_receive(:xyz).once.with(1,2,3).and_return 4
      @prj_doc.xyz( 1, 2, 3).should == 4
    end
    
  end

  
end