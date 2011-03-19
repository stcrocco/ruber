require 'spec/framework'
require 'spec/common'

require 'ruber/world/world'

require 'tmpdir'
require 'tempfile'
require 'fileutils'

describe Ruber::World::World do
  
  it 'includes Ruber::PluginLike' do
    Ruber::World::World.ancestors.should include(Ruber::PluginLike)
  end
  
  it 'derives from Qt::Object' do
    Ruber::World::World.ancestors.should include(Qt::Object)
  end
  
  before do
    @world = Ruber[:components].load_component 'world'
  end
  
  describe 'when created' do
    
    before do
      @psf = Ruber::PluginSpecification.full  File.expand_path('lib/ruber/world/plugin.yaml')
      flexmock(Ruber[:components]).should_receive(:add).by_default
    end
    
    it 'takes the component manager and the plugin specification file as arguments' do
      res = nil
      lambda{res = Ruber::World::World.new Ruber[:components], @psf}.should_not raise_error
      res.should be_a(Ruber::World::World)
    end
    
    it 'sets the component manager as parent' do
      Ruber::World::World.new(Ruber[:components], @psf).parent.should == Ruber[:components]
    end
    
    it 'registers itself with the component manager' do
      flexmock(Ruber[:components]).should_receive(:add).with( Ruber::World::World).once
      world = Ruber::World::World.new Ruber[:components], @psf
    end
    
  end
  
  describe '#new_document' do
    
    it 'returns a new pristine document' do
      doc1 = @world.new_document
      doc2 = @world.new_document
      doc1.should_not == doc2
      doc1.should be_pristine
    end
    
    it 'makes the document child of the world' do
      @world.new_document.parent.should == @world
    end
    
  end
  
  describe '#document' do
  
    it 'returns a new document for the given file or URL, if no other document for it exists' do
      doc = @world.document __FILE__
      doc.path.should == __FILE__
    end
    
    it 'makes the document child of self' do
      @world.document(__FILE__).parent.should == @world
    end
    
    it 'returns an existing document for the same file, if it already exists' do
      old = @world.document __FILE__
      new = @world.document __FILE__
      new.should == old
    end
    
    it 'returns the existing file even if of the two calls to document one was passed a string and the other an URL' do
      old = @world.document KDE::Url.new(__FILE__)
      new = @world.document __FILE__
      new.should == old
    end
    
    it 'does not attempt to return a document which has been closed' do
      old = @world.document __FILE__
      old.close
      new = @world.document __FILE__
      new.should_not == old
    end
    
    it 'returns an existing document even if it was created without a file and saved with the new name later' do
      old = @world.document nil
      url = KDE::Url.new __FILE__
      flexmock(old).should_receive(:url).and_return url
      old.instance_eval{emit document_url_changed(self)}
      new = @world.document __FILE__
      new.should == old
    end
    
    it 'returns an existing document even if it was created for another file then
    saved with the new name later' do
      old = @world.document File.join File.dirname(__FILE__), 'common.rb'
      url = KDE::Url.new __FILE__
      flexmock(old).should_receive(:url).and_return url
      old.instance_eval{emit document_url_changed(self)}
      new = @world.document __FILE__
      new.should == old
    end
    
    it 'doesn\'t return a document which was created for the same file but was saved with another name later' do
      old = @world.document __FILE__ 
      url = KDE::Url.new File.join(File.dirname(__FILE__), 'common.rb')
      flexmock(old).should_receive(:url).and_return url
      old.instance_eval{emit document_url_changed(self)}
      new = @world.document __FILE__
      new.should_not == old
    end
    
    it 'returns nil if the file is a local file and it doesn\'t exist' do
      @world.document('/xyz').should be_nil
      @world.document(KDE::Url.new('/xyz')).should be_nil
    end
    
  end
  
  describe '#project' do
    
    context 'when called with a file name as argument' do
      
      before do
        @file = Tempfile.new ['project_factory_test', '.ruprj']
        @file.write YAML.dump({:general => {:project_name => 'project_factory_test'}})
        @file.flush
      end
      
      after do
        path = @file.path
        @file.close!
        FileUtils.rm_f path
      end
      
      it 'returns a new project associated with the file if no other project is associated with it' do
        prj = @world.project @file.path
        prj.should be_a(Ruber::Project)
        prj.project_file.should == @file.path
      end
      
      it 'returns an existing project associated with the same file, if that project exists' do
        old = @world.project @file.path
        new = @world.project @file.path
        new.should == old
      end
      
      it 'doesn\'t return an existing project which has been closed' do
        old = @world.project @file.path
        old.close
        new = @world.project @file.path
        new.should_not == old
      end
      
    end
    
  end
  
  describe '#new_project' do
    
    it 'returns a new project associated with the file if no other project is associated with it' do
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      prj = @world.new_project file, 'world_new_project_test'
      prj.should be_a(Ruber::Project)
      prj.project_file.should == file
    end
    
    it 'returns the existing project associated with the file if there is such a project and the name of the project is equal to the second argument' do
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      old = @world.new_project file, 'world_new_project_test'
      prj = @world.new_project file, 'world_new_project_test'
      prj.should == old
    end
    
    it 'raises ExistingProjectFileError if the given project file already exists' do
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      flexmock(File).should_receive(:exist?).with(file).and_return true
      lambda{@world.new_project(file, "Test")}.should raise_error(Ruber::World::World::ExistingProjectFileError, "#{file} already exists")
    end
        
    it 'doesn\'t return an existing project which has been closed' do
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      old = @world.new_project file, 'world_new_project_test'
      old.close false
      new = @world.new_project file, 'world_new_project_test'
      new.should_not == old
    end
    
  end
  
  describe 'environment' do
    
    context 'when called with a project as argument' do
      
      before do
        file = File.join Dir.tmpdir, 'world_environment_test.ruprj'
        @prj = @world.new_project file, 'Test'
      end
      
      context 'if an environment for the given project doesn\'t already exists' do
      
        it 'creates a new environment for the given project' do
          env = @world.environment(@prj)
          env.should be_a(Ruber::World::Environment)
          env.project.should == @prj
        end
        
      end
      
      context 'if an environment for the given project already exists' do
        
        it 'returns that environment' do
          env = @world.environment @prj
          new_env = @world.environment @prj
          new_env.should equal(env)
        end
        
      end
      
    end
        
  end
  
end