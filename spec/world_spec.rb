require 'spec/framework'
require 'spec/common'

require 'ruber/world/world'

require 'tmpdir'
require 'tempfile'
require 'fileutils'

describe Ruber::World::World do
  
  before :all do
    class KDE::TabWidget
      def show
      end
    end
  end
  
  after :all do
    class KDE::TabWidget
      remove_method :show
    end
  end
  
  before do
    #needed because otherwise the config manager would complain when running the
    #next test because the option had already been added
    Ruber[:config].remove_setting :workspace, :close_buttons
    Ruber[:config].remove_setting :workspace, :middle_button_close
    @psf = Ruber::PluginSpecification.full  File.expand_path('lib/ruber/world/plugin.yaml')
    @world = Ruber::World::World.new Ruber[:components], @psf
    #remove the default document from the game
    @world.default_environment.documents[0].close
  end
    
  it 'includes Ruber::PluginLike' do
    Ruber::World::World.ancestors.should include(Ruber::PluginLike)
  end
  
  it 'derives from Qt::Object' do
    Ruber::World::World.ancestors.should include(Qt::Object)
  end
  
  describe 'when created' do
    
    before do
      @psf = Ruber::PluginSpecification.full  File.expand_path('lib/ruber/world/plugin.yaml')
      flexmock(Ruber[:components]).should_receive(:add).by_default
    end
        
    it 'sets the application as parent' do
      @world.parent.should == Ruber[:app]
    end
    
    it 'registers itself with the component manager' do
      Ruber[:components][:world].should be_an_instance_of(Ruber::World::World)
    end
    
    it 'creates a default environment associated with no project' do
      env = @world.default_environment
      env.should be_a(Ruber::World::Environment)
      env.project.should be_nil
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
    
    it 'emits the document_created signal passing the document as argument' do
      doc = Ruber::Document.new
      flexmock(Ruber::Document).should_receive(:new).once.and_return doc
      mk = flexmock{|m| m.should_receive(:test).once.with(doc)}
      @world.connect(SIGNAL('document_created(QObject*)')){|doc| mk.test doc}
      @world.new_document
    end
    
    it 'add the document to the list of documents' do
      docs = Array.new{@world.new_document}
      list = @world.documents
      docs.each{|d| list.should include(d)}
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
    
    it 'emits the document_created signal passing the document as argument if a new document has been created' do
      doc = Ruber::Document.new __FILE__
      flexmock(Ruber::Document).should_receive(:new).once.with(__FILE__, @world).and_return doc
      mk = flexmock{|m| m.should_receive(:test).once.with(doc)}
      @world.connect(SIGNAL('document_created(QObject*)')){|doc| mk.test doc}
      @world.document __FILE__
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
  
  context 'when a document is closed' do
    
    it 'emits the closing_document signal passing the document as argument' do
      doc = @world.new_document
      mk = flexmock{|m| m.should_receive(:test).with(doc.object_id).once}
      @world.connect(SIGNAL('closing_document(QObject*)')){|d| mk.test d.object_id}
      doc.close
    end
    
  end
  
  context 'when the active editor changes' do
    
    context 'if the editor associated with the new document is different from the one associated with the previously active environment' do
      
      before do
        @env = @world.default_environment
        @world.active_environment = @env
        @docs = Array.new(2){@world.new_document}
        @views = @docs.map{|doc| @env.editor_for! doc}
        @env.activate_editor @views[1]
      end
      
      it 'changes the active document' do
        @env.activate_editor @views[0]
        @world.active_document.should == @docs[0]
      end
      
      it 'emits the active_editor_changed signal passing the new active editor as argument' do
        mk = flexmock{|m| m.should_receive(:test).with(@views[0].object_id).once}
        @world.connect(SIGNAL('active_editor_changed(QWidget*)')) do |view|
          mk.test view.object_id
        end
        @env.activate_editor @views[0]
        
      end
      
      it 'emits the active_document_changed signal passing the new active document as argument' do
        mk = flexmock{|m| m.should_receive(:test).with(@docs[0].object_id).once}
        @world.connect(SIGNAL('active_document_changed(QObject*)')) do |doc|
          mk.test doc.object_id
        end
        @env.activate_editor @views[0]
      end
      
    end
    
    context 'if the editor associated with the new document is already active' do
      
      before do
        @env = @world.default_environment
        @world.active_environment = @env
        @docs = Array.new(2){@world.new_document}
        @views = Array.new(2){@env.editor_for! @docs[0], :existing => :never}
        @env.activate_editor @views[1]
      end
      
      it 'emits the active_editor_changed signal passing the new active editor as argument' do
        mk = flexmock{|m| m.should_receive(:test).with(@views[0].object_id).once}
        @world.connect(SIGNAL('active_editor_changed(QWidget*)')) do |view|
          mk.test view.object_id
        end
        @env.activate_editor @views[0]
      end
      
      it 'does not emit the active_document_changed signal' do
        mk = flexmock{|m| m.should_receive(:test).never}
        @world.connect(SIGNAL('active_document_changed(QObject*)')) do |doc|
          mk.test doc.object_id
        end
        @env.activate_editor @views[0]
      end
      
    end
    
    context 'if there\'s no new active editor' do
      
      before do
        @env = @world.default_environment
        @world.active_environment = @env
        @docs = Array.new(2){@world.new_document}
        @views = @docs.map{|doc| @env.editor_for! doc}
        @env.activate_editor @views[1]
      end
      
      it 'sets the active document to nil' do
        @env.activate_editor nil
        @world.active_document.should be_nil
      end
      
      it 'emits the active_editor_changed signal passing nil as argument' do
        mk = flexmock{|m| m.should_receive(:test).with(nil).once}
        @world.connect(SIGNAL('active_editor_changed(QWidget*)')) do |view|
          mk.test view
        end
        @env.activate_editor nil
      end

      
      it 'emits the the active_document_changed signal passing nil as argument' do
        mk = flexmock{|m| m.should_receive(:test).with(nil)}
        @world.connect(SIGNAL('active_document_changed(QObject*)')) do |doc|
          mk.test doc
        end
        @env.activate_editor nil
      end
      
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
      
      it 'emits the project_created signal passing the project as argument if a new project has been created' do
        prj = Ruber::Project.new @file.path
        flexmock(Ruber::Project).should_receive(:new).once.with(@file.path, nil).and_return prj
        mk = flexmock{|m| m.should_receive(:test).once.with(prj)}
        @world.connect(SIGNAL('project_created(QObject*)')){|pr| mk.test pr}
        @world.project @file.path
      end
      
      it 'creates a new environment for the project if a new project has been created' do
        prj = @world.project @file.path
        @world.environments.find{|env| env.project == prj}.should_not be_nil
      end
      
      it 'raises Ruber::AbstractProject::InvalidProjectFile if the project file doesn\'t exist' do
        lambda{@world.project '/xyz.ruprj'}.should raise_error(Ruber::AbstractProject::InvalidProjectFile)
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
    
    it 'adds the environment associated with the project to the environment list' do
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      prj = @world.new_project file, 'world_new_project_test'
      env = @world.environment prj
      env.should be_a(Ruber::World::Environment)
      env.project.should == prj
    end
    
    it 'emits the project_created_signal passing the project as argument' do
      name = 'world_new_project_test'
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      prj = Ruber::Project.new file, name
      flexmock(Ruber::Project).should_receive(:new).once.with(file, name).and_return prj
      mk = flexmock{|m| m.should_receive(:test).once.with(prj)}
      @world.connect(SIGNAL('project_created(QObject*)')){|pr| mk.test pr}
      @world.new_project file, name
    end
    
    it 'raises ExistingProjectFileError if the given project file already exists' do
      file = File.join Dir.tmpdir, 'world_new_project_test.ruprj'
      flexmock(File).should_receive(:exist?).with(file).and_return true
      lambda{@world.new_project(file, "Test")}.should raise_error(Ruber::World::World::ExistingProjectFileError, "#{file} already exists")
    end
        
  end
  
  describe 'when a project is being closed' do
    
    it 'emits the closing_project signal passing the project as argument' do
      file = File.join Dir.tmpdir, 'world_closing_project_test.ruprj'
      prj = @world.new_project file, 'Test'
      mk = flexmock{|m| m.should_receive(:test).once.with(prj.object_id)}
      @world.connect(SIGNAL('closing_project(QObject*)')){|pr| mk.test pr.object_id}
      prj.close(false)
    end
    
    it 'removes the project from the list of projects' do
      file = File.join Dir.tmpdir, 'world_closing_project_test.ruprj'
      prj = @world.new_project file, 'Test'
      prj.close(false)
    end
    
  end
  
  describe '#environment' do
    
    before do
      @file = File.join Dir.tmpdir, 'world_environment_test.ruprj'
      @prj = @world.new_project @file, 'Test'
    end
    
    after do
      FileUtils.rm_f @file
    end
    
    context 'if an environment for the given project doesn\'t already exists' do
    
      it 'returns nil' do
        @world.environment('x').should be_nil
      end
      
    end
    
    context 'if an environment for the given project already exists' do
      
      it 'returns that environment' do
        env = @world.environment @prj
        new_env = @world.environment @prj
        new_env.should equal(env)
      end
      
      it 'doesn\'t return an environment which has been closed' do
        env = @world.environment @prj
        env.close
        new_env = @world.environment @prj
        new_env.should_not == env
      end
        
    end

  end
  
  describe '#active_environment=' do
    
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_environment_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    context 'if there is not an active environment' do
      
      after do
        @world.instance_variable_set :@active_environment, nil
      end
      
      context 'and the argument is an environment' do
        
        it 'marks the given environment as active environment' do
          @world.active_environment = @envs[1]
          @world.active_environment.should == @envs[1]
        end
        
        it 'emits the active_environment_changed signal passing the new environment as argument' do
          mk = flexmock{|m| m.should_receive(:active_environment_changed).once.with @envs[0]}
          @world.connect(SIGNAL('active_environment_changed(QObject*)')){|e| mk.active_environment_changed e}
          @world.active_environment = @envs[0]
        end
        
        it 'emits the active_environment_changed_2 signal passing the new environment and nil as arguments' do
          mk = flexmock{|m| m.should_receive(:active_environment_changed).once.with @envs[0], nil}
          @world.connect(SIGNAL('active_environment_changed_2(QObject*,QObject*)')){|e1, e2| mk.active_environment_changed e1, e2}
          @world.active_environment = @envs[0]
        end
        
        it 'activates the given environment' do
          flexmock(@envs[0]).should_receive(:activate).once
          @world.active_environment = @envs[0]
        end
        
      end
      
    end

    context 'if there is an active environment' do
      
      before do
        @world.instance_variable_set :@active_environment, @envs[0]
      end
      
      after do
        @world.instance_variable_set :@active_environment, @envs[0]
      end
      
      context 'and the argument is an environment' do
        
        it 'deactivates the old active environment' do
          flexmock(@envs[0]).should_receive(:deactivate).once
          @world.active_environment = @envs[1]
        end
        
        it 'marks the given environment as active environment' do
          @world.active_environment = @envs[1]
          @world.active_environment.should == @envs[1]
        end
        
        it 'emits the active_environment_changed signal passing the new environment as argument' do
          mk = flexmock{|m| m.should_receive(:active_environment_changed).once.with @envs[1]}
          @world.connect(SIGNAL('active_environment_changed(QObject*)')){|e| mk.active_environment_changed e}
          @world.active_environment = @envs[1]
        end
        
        it 'emits the active_environment_changed_2 signal passing the new environment and the old environment as arguments' do
          mk = flexmock{|m| m.should_receive(:active_environment_changed).once.with @envs[1], @envs[0]}
          @world.connect(SIGNAL('active_environment_changed_2(QObject*,QObject*)')){|e1, e2| mk.active_environment_changed e1, e2}
          @world.active_environment = @envs[1]
        end
        
        it 'activates the given environment' do
          flexmock(@envs[1]).should_receive(:activate).once
          @world.active_environment = @envs[1]
        end
        
      end
      
      context 'and the argument is an nil' do
        
        it 'deactivates the old active environment' do
          flexmock(@envs[0]).should_receive(:deactivate).once
          @world.active_environment = nil
        end
        
        it 'sets the active environment to nil' do
          @world.active_environment = nil
          @world.active_environment.should be_nil
        end
        
        it 'emits the active_environment_changed signal passing nil as argument' do
          mk = flexmock{|m| m.should_receive(:active_environment_changed).once.with nil}
          @world.connect(SIGNAL('active_environment_changed(QObject*)')){|e| mk.active_environment_changed e}
          @world.active_environment = nil
        end
        
        it 'emits the active_environment_changed_2 signal passing the nil and the old active environment as arguments' do
          mk = flexmock{|m| m.should_receive(:active_environment_changed).once.with nil, @envs[0]}
          @world.connect(SIGNAL('active_environment_changed_2(QObject*,QObject*)')){|e1, e2| mk.active_environment_changed e1, e2}
          @world.active_environment = nil
        end
        
        it 'doesn\'t attempt to activate the new environment' do
          lambda{@world.active_environment = nil}.should_not raise_error
        end
        
      end
      
      it 'does nothing if the argument is the same as the active environment' do
        @world.active_environment = nil
        mk=flexmock{|m| m.should_receive(:test).never}
        @world.connect(SIGNAL('active_environment_changed(QObject*)')){|e| mk.test e}
        @world.active_environment = nil
        @world.instance_variable_set :@active_environment, @envs[1]
        @world.active_environment = @envs[1]
      end

    end
    
  end
  
  context 'when an environment is being closed' do
    
    after do
      FileUtils.rm_r File.join( Dir.tmpdir, "world_environment_closing_test.ruprj")
    end
    
    it 'sets the active environment to nil if the environment being closed is the active one' do
      file = File.join Dir.tmpdir, "world_environment_closing_test.ruprj"
      prj = @world.new_project file, "Test"
      env = @world.environment prj
      @world.active_environment = env
      env.close
      @world.active_environment.should be_nil
    end
    
    it 'does\'t change the active environment if the active project is not the one being closed' do
      file = File.join Dir.tmpdir, "world_environment_closing_test.ruprj"
      prj = @world.new_project file, "Test"
      env = @world.environment prj
      @world.active_environment = @world.default_environment
      env.close
      @world.active_environment.should == @world.default_environment
    end
    
  end
  
  describe '#active_project=' do
    
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    context 'if there is not an active project' do
      
      after do
        @world.instance_variable_set :@active_environment, nil
      end
      
      context 'and the argument is a project' do
        
        it 'calls the #active_environment= method with the environment associated with the project as argument' do
          flexmock(@world).should_receive(:active_environment=).with(@envs[1]).once
          @world.active_project = @prjs[1]
        end
        
        it 'emits the active_project_changed signal passing the new active project as argument' do
          mk = flexmock{|m| m.should_receive(:active_project_changed).once.with @prjs[0]}
          @world.connect(SIGNAL('active_project_changed(QObject*)')){|prj| mk.active_project_changed prj}
          @world.active_project = @prjs[0]
        end
        
        it 'emits the active_project_changed_2 signal passing the new project and nil as arguments' do
          mk = flexmock{|m| m.should_receive(:active_project_changed).once.with @prjs[0], nil}
          @world.connect(SIGNAL('active_project_changed_2(QObject*,QObject*)')){|p1, p2| mk.active_project_changed p1, p2}
          @world.active_project = @prjs[0]
        end
        
        it 'activates the given project' do
          flexmock(@prjs[0]).should_receive(:activate).once
          @world.active_project = @prjs[0]
        end
        
      end
      
    end
    
    context 'if there is an active project' do
      
      before do
        @world.instance_variable_set :@active_environment, @envs[0]
      end
      
      after do
        @world.instance_variable_set :@active_environment, @envs[0]
      end
      
      context 'and the argument is a project' do
        
        it 'calls the active_environment= method with the environment associated with the project' do
          flexmock(@world).should_receive(:active_environment=).once.with @envs[1]
          @world.active_project = @prjs[1]
        end
        
        it 'deactivates the old active projecy' do
          flexmock(@prjs[0]).should_receive(:deactivate).once
          @world.active_project = @prjs[1]
        end
        
        it 'emits the active_project_changed signal passing the new environment as argument' do
          mk = flexmock{|m| m.should_receive(:active_project_changed).once.with @prjs[1]}
          @world.connect(SIGNAL('active_project_changed(QObject*)')){|e| mk.active_project_changed e}
          @world.active_project = @prjs[1]
        end
        
        it 'emits the active_project_changed_2 signal passing the new environment and the old environment as arguments' do
          mk = flexmock{|m| m.should_receive(:active_project_changed).once.with @prjs[1], @prjs[0]}
          @world.connect(SIGNAL('active_project_changed_2(QObject*,QObject*)')){|e1, e2| mk.active_project_changed e1, e2}
          @world.active_project = @prjs[1]
        end
        
        it 'activates the given project' do
          flexmock(@prjs[1]).should_receive(:activate).once
          @world.active_project = @prjs[1]
        end
        
      end
      
      context 'and the argument is an nil' do
        
        it 'calls the active_environment= method with nil' do
          flexmock(@world).should_receive(:active_environment=).once.with @world.default_environment
          @world.active_project = nil
        end
        
        it 'deactivates the old active environment' do
          flexmock(@prjs[0]).should_receive(:deactivate).once
          @world.active_project = nil
        end
        
        it 'emits the active_project_changed signal passing nil as argument' do
          mk = flexmock{|m| m.should_receive(:active_project_changed).once.with nil}
          @world.connect(SIGNAL('active_project_changed(QObject*)')){|e| mk.active_project_changed e}
          @world.active_project = nil
        end
        
        it 'emits the active_project_changed_2 signal passing the nil and the old active environment as arguments' do
          mk = flexmock{|m| m.should_receive(:active_project_changed).once.with nil, @prjs[0]}
          @world.connect(SIGNAL('active_project_changed_2(QObject*,QObject*)')){|e1, e2| mk.active_project_changed e1, e2}
          @world.active_project = nil
        end
        
        it 'doesn\'t attempt to activate the new project' do
          lambda{@world.active_project = nil}.should_not raise_error
        end
        
      end
      
      it 'does nothing if the argument is the same as the active project' do
        @world.active_project = nil
        mk=flexmock{|m| m.should_receive(:test).never}
        @world.connect(SIGNAL('active_project_changed(QObject*)')){|e| mk.test e}
        @world.active_project = nil
        @world.instance_variable_set :@active_environment, @envs[1]
        @world.active_project = @prjs[1]
      end
      
    end
    
  end
  
  describe '#active_project' do
    
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    it 'returns the project associated with the active environment if it exists' do
      @world.active_environment = @envs[1]
      @world.active_project.should == @prjs[1]
      @world.active_environment = @world.default_environment
      @world.active_project.should be_nil
    end
    
    it 'returns nil if there\'s no active project' do
      @world.active_project.should be_nil
    end
    
  end
  
  describe '#active_document' do
    
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    it 'returns the document associated with the active editor' do
      @world.active_environment = @envs[1]
      doc = @world.new_document
      ed = @envs[1].editor_for! doc
      @envs[1].activate_editor ed
      @world.active_document.should == doc
    end
    
    it 'returns nil if there\'s no active document' do
      @world.active_document.should be_nil
    end
    
  end
  
  describe '#environments' do
    
    it 'returns an array containing all the environments, including the default one' do
      prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      envs = 2.times.map{|i| @world.environment prjs[i]}
      @world.environments.should == [@world.default_environment] + envs
    end
    
  end
  
  describe '#each_environment' do
    
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    context 'if called with a block' do
      
      it 'calls the block once for each environment, passing the environment as argument' do
        mk = flexmock do |m|
          m.should_receive(:test).with(@world.default_environment).once
          m.should_receive(:test).with(@envs[0]).once
          m.should_receive(:test).with(@envs[1]).once
        end
        @world.each_environment{|e| mk.test e}
      end
      
      it 'returns self' do
        @world.each_environment{}.should == @world
      end
      
    end
    
    context 'if called without a block' do
      
      it 'returns an enumerator which iterates on all the environments' do
        mk = flexmock do |m|
          m.should_receive(:test).with(@world.default_environment).once
          m.should_receive(:test).with(@envs[0]).once
          m.should_receive(:test).with(@envs[1]).once
        end
        enum = @world.each_environment
        enum.should be_an(Enumerator)
        enum.each{|e| mk.test e}
      end
      
    end
    
  end
  
  describe '#projects' do
    
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    it 'returns a ProjectList containing all the projects' do
      list = @world.projects
      list.should be_a(Ruber::World::ProjectList)
      list.should == @prjs
    end
    
  end
  
  describe '#each_project' do
    before do
      @prjs = 2.times.map do |i|
        file = File.join Dir.tmpdir, "world_current_project_test_#{i}.ruprj"
        @world.new_project file, "Test #{i}"
      end
      @envs = 2.times.map{|i| @world.environment @prjs[i]}
    end
    
    context 'if called with a block' do
      
      it 'calls the block once for each project, passing the project as argument' do
        mk = flexmock do |m|
          m.should_receive(:test).with(@prjs[0]).once
          m.should_receive(:test).with(@prjs[1]).once
        end
        @world.each_project{|prj| mk.test prj}
      end
      
      it 'returns self' do
        @world.each_project{}.should == @world
      end
      
    end
    
    context 'if called without a block' do
      
      it 'returns an enumerator which iterates on all the projects' do
        mk = flexmock do |m|
          m.should_receive(:test).with(@prjs[0]).once
          m.should_receive(:test).with(@prjs[1]).once
        end
        enum = @world.each_project
        enum.should be_an(Enumerator)
        enum.each{|e| mk.test e}
      end
      
    end
    
  end

  describe '#documents' do
    
    before do
      @docs = 8.times.map{@world.new_document}
    end
    
    it 'returns a DocumentList containing all the open documents' do
      res = @world.documents
      res.should be_instance_of(Ruber::World::DocumentList)
      res.should == @docs
    end
    
    it 'doesn\'t include documents which have been closed in the list' do
      @docs[1].close
      @world.documents.should == [@docs[0]] + @docs[2..-1]
    end
    
  end
  
  describe '#each_document' do
    
    before do
      @docs = 8.times.map{@world.new_document}
    end
    
    context 'if called with a block' do
    
      it 'calls the block once for each document, passing the document as argument' do
          mk = flexmock do |m|
            @docs.each{|d| m.should_receive(:test).once.with d}
          end
          @world.each_document{|doc| mk.test doc}
        end
        
        it 'returns self' do
          @world.each_document{}.should == @world
        end
        
      end
    
    context 'if called without a block' do
      
      it 'returns an enumerator which iterates on all the documents' do
        mk = flexmock do |m|
          @docs.each{|d| m.should_receive(:test).once.with d}
        end
        enum = @world.each_document
        enum.should be_an(Enumerator)
        enum.each{|doc| mk.test doc}
      end
    
    end
    
  end
  
  describe '#load_settings' do
    
    it 'makes the tabs in the environments\' tab widgets closeable or not according to the workspace/close_buttons setting' do
      file = File.join Dir.tmpdir, 'world_load_settings_test.ruprj'
      prj = @world.new_project file, 'TEST'
      flexmock(Ruber[:config]).should_receive(:[]).with(:workspace, :close_buttons).once.and_return true
      @world.send(:load_settings)
      @world.environments.each{|e| e.tab_widget.tabs_closable.should be_true}
      flexmock(Ruber[:config]).should_receive(:[]).with(:workspace, :close_buttons).once.and_return false
      @world.send(:load_settings)
      @world.environments.each{|e| e.tab_widget.tabs_closable.should be_false}
    end
    
  end
  
  describe '#save_settings' do
    
    after do
      Ruber[:world].projects.dup.each{|prj| prj.close false}
    end
    
    it 'calls the #save_settings method of each document' do
      docs = Array.new(5){@world.new_document}
      docs.each{|doc| flexmock(doc).should_receive(:save_settings).once}
      @world.save_settings
    end
    
    it 'calls the #save method of each project' do
      files = Array.new(5)do 
        file = Tempfile.new ['', '.ruprj']
        file.write YAML.dump(:general => {:project_name => random_string(10)})
        file.flush
        file
      end
      projects = files.map do |f|
        prj = Ruber[:world].project f.path
        flexmock(prj).should_receive(:save).once
        prj
      end
      @world.save_settings
    end
    
  end
  
  describe '#query_close' do
    
    before do
      @docs = Array.new(5){@world.new_document}
      @docs.each{|doc| flexmock(doc.own_project).should_receive(:query_close).by_default.and_return(true)}
      flexmock(Ruber[:main_window]).should_receive(:save_documents).and_return(true).by_default
      files = Array.new(5)do 
        file = Tempfile.new ['', '.ruprj']
        file.write YAML.dump(:general => {:project_name => random_string(10)})
        file.flush
        file
      end
      @projects = files.map do |f|
        prj = Ruber[:world].project f.path
        flexmock(prj).should_receive(:query_close).by_default.and_return(:true)
        prj
      end
    end
    
    after do
      #needed to avoid callinf main_window#save settings when closing projects
      flexmock(Ruber[:main_window]).should_receive(:save_documents).and_return true
      Ruber[:world].projects.dup.each{|prj| prj.close false}
    end
    
    it 'calls the query_close method of the project associated with each document' do
      @docs.each do |doc|
        flexmock(doc.own_project).should_receive(:query_close).once.and_return true
      end
      @world.query_close
    end
    
    it 'returns false if the query_close method of a project associated with a document returns false' do
      @docs.each_with_index do |doc, i|
        res = (i !=3)
        flexmock(doc.own_project).should_receive(:query_close).and_return res
      end
      @world.query_close.should == false
    end
    
    it 'calls the save_documents method of the main window' do
      flexmock(Ruber[:main_window]).should_receive(:save_documents).once.with(@docs).and_return false
      @world.query_close
    end
    
    it 'returns false if the main window\'s save_documents method returns false' do
      flexmock(Ruber[:main_window]).should_receive(:save_documents).once.with(@docs).and_return false
      @world.query_close.should == false
    end
    
    it 'calls the query_close method of each project' do
      @projects.each do |prj|
        flexmock(prj).should_receive(:query_close).once.and_return true
      end
      @world.query_close
    end
    
    it 'returns false if the query_close method of a project returns false' do
      @projects.each_with_index do |prj, i|
        res = (i !=3)
        flexmock(prj).should_receive(:query_close).and_return res
      end
      @world.query_close.should == false
    end
    
    it 'returns true if the documents\' and projects\' query_close method and the main window\'s save_documents methods all return true' do
      @world.query_close.should == true
    end
    
  end
  
  describe '#close_all' do
    
    before do
      @projects = Array.new(3) do |i|
        @world.new_project File.join(Dir.tmpdir, "#{random_string}.ruprj"), "Test #{i}" 
      end
      @docs = Array.new(5){@world.new_document}
    end
    
    context 'when called the first argument is :all' do
      
      context 'if the second argument is :save' do
        
        before do
          @projects.each{|prj| flexmock(prj).should_receive(:close).by_default}
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).by_default
          end
        end
        
        it 'calls the close method of each project passing true as argument' do
          @projects.each do |prj|
            flexmock(prj).should_receive(:close).with(true).once
          end
          @world.close_all :all, :save
        end
        
        it 'calls the close method of each document passing true as argument' do
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).with(true).once
          end
          @world.close_all :all, :save
        end
        
      end
      
      context 'if the second argument is :discard' do
        
        before do
          @projects.each{|prj| flexmock(prj).should_receive(:close).by_default}
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).by_default
          end
        end
        
        it 'calls the close method of each project passing false as argument' do
          @projects.each do |prj|
            flexmock(prj).should_receive(:close).with(false).once
          end
          @world.close_all :all, :discard
        end
        
        it 'calls the close method of each document passing false as argument' do
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).with(false).once
          end
          @world.close_all :all, :discard
        end
        
      end
      
    end
    
    context 'when called the first argument is :projects' do
      
      context 'if the second argument is :save' do
        
        before do
          @projects.each{|prj| flexmock(prj).should_receive(:close).by_default}
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).by_default
          end
        end
        
        it 'calls the close method of each project passing true as argument' do
          @projects.each do |prj|
            flexmock(prj).should_receive(:close).with(true).once
          end
          @world.close_all :projects, :save
        end
        
        it 'doesn\'t close the documents' do
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).never
          end
          @world.close_all :projects, :save
        end
        
      end
      
      context 'if the second argument is :discard' do
        
        before do
          @projects.each{|prj| flexmock(prj).should_receive(:close).by_default}
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).by_default
          end
        end
        
        it 'calls the close method of each project passing false as argument' do
          @projects.each do |prj|
            flexmock(prj).should_receive(:close).with(false).once
          end
          @world.close_all :projects, :discard
        end
        
        it 'doesn\'t close the documents' do
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).never
          end
          @world.close_all :projects, :discard
        end
        
      end
      
    end
    
    context 'when called the first argument is :documents' do
      
      context 'if the second argument is :save' do
        
        before do
          @projects.each{|prj| flexmock(prj).should_receive(:close).by_default}
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).by_default
          end
        end
        
        it 'doesn\'t close projects' do
          @projects.each do |prj|
            flexmock(prj).should_receive(:close).never
          end
          @world.close_all :documents, :save
        end
        
        it 'calls the close method of each document passing true as argument' do
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).with(true).once
          end
          @world.close_all :documents, :save
        end
        
      end
      
      context 'if the second argument is :discard' do
        
        before do
          @projects.each{|prj| flexmock(prj).should_receive(:close).by_default}
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).by_default
          end
        end
        
        it 'doesn\'t close the projects' do
          @projects.each do |prj|
            flexmock(prj).should_receive(:close).never
          end
          @world.close_all :documents, :discard
        end
        
        it 'calls the close method of each document passing false as argument' do
          @docs.each do |doc|
            flexmock(doc).should_receive(:close).with(false).once
          end
          @world.close_all :documents, :discard
        end
        
      end
      
    end
    
    
  end
  
end
