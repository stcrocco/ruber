require 'spec/framework'
require './spec/common'
require 'ruber/world/project_factory'

require 'tempfile'
require 'tmpdir'

describe Ruber::World::ProjectFactory do
  
  before do
    @factory = Ruber::World::ProjectFactory.new
  end
  
  describe '#project' do
    
    context 'when called with a file name as argument' do
      
      before do
        @file = Tempfile.new ['project_factory_test', '.ruprj']
        @file.write YAML.dump({:general => {:project_name => 'project_factory_test'}})
        @file.flush
      end
      
      after do
        @file.close!
      end
      
      it 'returns a new project associated with the file if no other project is associated with it' do
        prj = @factory.project @file.path
        prj.should be_a(Ruber::Project)
        prj.project_file.should == @file.path
      end
      
      it 'returns an existing project associated with the same file, if that project exists' do
        old = @factory.project @file.path
        new = @factory.project @file.path
        new.should == old
      end
      
      it 'emits the project_created signal passing the project as argument if a new project was created' do
        prj = Ruber::Project.new @file.path
        flexmock(Ruber::Project).should_receive(:new).with(@file.path, nil).once.and_return prj
        mk = flexmock{|m| m.should_receive(:test).once.with(prj)}
        @factory.connect(SIGNAL('project_created(QObject*)')){|pr| mk.test pr}
        @factory.project @file.path
      end
      
      it 'doesn\'t return an existing project which has been closed' do
        old = @factory.project @file.path
        old.close
        new = @factory.project @file.path
        new.should_not == old
      end
      
    end
    
  end
  
  context 'when called with a file name and a project name as arguments' do
    
    it 'returns a new project associated with the file if no other project is associated with it' do
      file = File.join Dir.tmpdir, 'project_factory_test.ruprj'
      prj = @factory.project file, 'project_factory_test'
      prj.should be_a(Ruber::Project)
      prj.project_file.should == file
    end
    
    it 'returns the existing project associated with the file if there is such a project and the name of the project is equal to the second argument' do
      file = File.join Dir.tmpdir, 'project_factory_test.ruprj'
      old = @factory.project file, 'project_factory_test'
      prj = @factory.project file, 'project_factory_test'
      prj.should == old
    end
    
    it 'emits the project_created signal passing the project as argument if a new project was created' do
      name = 'project_factory_test'
      file = File.join Dir.tmpdir, 'project_factory_test.ruprj'
      prj = Ruber::Project.new file, name
      flexmock(Ruber::Project).should_receive(:new).once.with(file, name).and_return prj
      mk = flexmock{|m| m.should_receive(:test).once.with(prj)}
      @factory.connect(SIGNAL('project_created(QObject*)')){|pr| mk.test pr}
      @factory.project file, name
    end
    
    it 'raises ProjectFactory::MismatchingNameError if there\'s a project associated with the same file but the project name is different from the second argument' do
      file = File.join Dir.tmpdir, 'project_factory_test.ruprj'
      old_name = 'project_factory_test'
      old = @factory.project file, old_name
      new_name = 'project_factory_test_other_name'
      lambda{@factory.project file, new_name}.should raise_error(Ruber::World::ProjectFactory::MismatchingNameError, "A project associated with #{file} exists, but the corresponding project name is #{old_name} instead of #{new_name}")
    end
    
    it 'doesn\'t return an existing project which has been closed' do
      file = File.join Dir.tmpdir, 'project_factory_test.ruprj'
      old = @factory.project file, 'project_factory_test'
      old.close false
      new = @factory.project file, 'project_factory_test'
      new.should_not == old
    end

    
  end
  
end