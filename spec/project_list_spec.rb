require 'spec/common'

require 'flexmock'

require 'ruber/projects/project_list'
require 'ruber/plugin_specification'

class Ruber::ProjectList::FakeProject < Qt::Object
  
  signals 'closing(QObject*)'
  attr_reader :project_name, :project_file
  def initialize name = 'test', file = nil
    super()
    @project_file = file || Array.new(6){97 + rand(26)}.join
    @project_name = name
  end
  
  def deactivate;end
  
  def activate;end
    
    def close
      emit closing(self)
    end
end

describe Ruber::ProjectList do
  
  it 'should mix-in Enumerable' do
    Ruber::ProjectList.ancestors.include?(Enumerable).should be_true
  end
    
end

describe 'Ruber::ProjectList#project_for_file' do
  
  before do
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(KDE::Application.instance).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager).by_default
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @projects = Ruber::ProjectList.new manager, pdf
  end
  
  it 'returns nil if there\'s no current project' do
    flexmock(@projects).should_receive(:current).twice.and_return nil
    @projects.project_for_file(__FILE__, :active).should be_nil
    @projects.project_for_file(__FILE__, :all).should be_nil
  end
  
  it 'returns the current project if there\'s one and the file belongs to it' do
    prj = flexmock{|m| m.should_receive('project_files.file_in_project?').twice.with(__FILE__).and_return true}
    flexmock(@projects).should_receive(:current).twice.and_return prj
    @projects.project_for_file(__FILE__, :active).should == prj
    @projects.project_for_file(__FILE__, :all).should == prj
  end
  
  it 'returns nil if the file doesn\'t belong to the current project and the second argument is :active, even if the file belongs to another project' do
    active_prj = flexmock{|m| m.should_receive('project_files.file_in_project?').once.with(__FILE__).and_return false}
    prj = flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).and_return true}
    flexmock(@projects).should_receive(:current).once.and_return(active_prj)
    flexmock(@projects).should_receive(:each).and_yield(active_prj, prj)
    @projects.project_for_file(__FILE__, :active).should be_nil
  end
  
  it 'returns the first project to which the file belongs, if it doesn\'t belong to the current one and the second argument is :all' do
    active_prj = flexmock{|m| m.should_receive('project_files.file_in_project?').twice.with(__FILE__).and_return false}
    prjs = [
      flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).once.and_return false},
      active_prj,
      flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).once.and_return true},
      flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).never}
      ]
    flexmock(@projects).should_receive(:current).once.and_return(active_prj)
    projects = {
      '0' => prjs[0],
      '1' => prjs[1],
      '2' => prjs[2],
      '3' => prjs[3]
      }
    @projects.instance_variable_set(:@projects, projects)
    @projects.project_for_file(__FILE__, :all).should equal(prjs[2])
  end
    
  it 'returns nil if the second argument is :all and the file doesn\'t belong to any project' do
    active_prj = flexmock{|m| m.should_receive('project_files.file_in_project?').twice.with(__FILE__).and_return false}
    prjs = [
      flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).once.and_return false},
      active_prj,
      flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).once.and_return false},
      flexmock{|m| m.should_receive('project_files.file_in_project?').with(__FILE__).once.and_return false}
      ]
    flexmock(@projects).should_receive(:current).once.and_return(active_prj)
    projects = {
      '0' => prjs[0],
      '1' => prjs[1],
      '2' => prjs[2],
      '3' => prjs[3]
      }
    @projects.instance_variable_set(:@projects, projects)
    @projects.project_for_file(__FILE__, :all).should be_nil
  end
  
end

describe 'Ruber::ProjectList#each_project' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end

  
  it 'should yield all the projects in the list if called with a block' do
    prjs = Array.new(3){|i| Ruber::ProjectList::FakeProject.new("test#{i}")}
    prjs.each{|pr| @keeper.add_project pr}
    res = []
    @keeper.each_project{|pr| res << pr}
    res.sort_by{|pr| pr.project_file}.should == prjs.sort_by{|pr| pr.project_file}
  end
  
  it 'should return an enumerable which yields all the projects in the list if called without a block' do
    prjs = Array.new(3){|i| Ruber::ProjectList::FakeProject.new("test#{i}")}
    prjs.each{|pr| @keeper.add_project pr}
    m = flexmock do |mk|
      prjs.each{|prj| mk.should_receive(:test).once.with prj}
    end
    en = @keeper.each_project
    if RUBY_VERSION.match(/8/) then en.should be_an(Enumerable::Enumerator)
    else en.should be_an(Enumerator)
    end
    en.each{|prj| m.test prj}
  end
  
end

describe 'Ruber::ProjectList, when created' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    @pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, @pdf
  end
  
  it 'should call its initialize_plugin method' do
    @keeper.plugin_description.should == @pdf
  end
  
  it 'should have no project' do
    @keeper.projects.should be_empty
  end

  it 'should have no current project' do
    @keeper.current_project.should be_nil
  end

end

describe 'Ruber::Project#current_project=, when called with a non-nil argument' do

  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
    @prj = Ruber::ProjectList::FakeProject.new
    @keeper.instance_variable_get(:@projects)[@prj.project_file] = @prj
    @keeper.instance_variable_get(:@projects)['test'] = @prj
  end
  
  it 'should set the current project to its argument' do
    @keeper.current_project = @prj
    @keeper.current_project.should equal( @prj )
  end
  
  it 'should call the "deactivate" method of the old current project, if it\'s not nil' do
    @keeper.instance_variable_set(:@current_project, @prj)
    new_prj = Ruber::ProjectList::FakeProject.new 'Test1'
    @keeper.add_project new_prj
    flexmock(@prj).should_receive( :deactivate).once
    @keeper.current_project = new_prj
    @keeper.instance_variable_set :@current_project, nil
    lambda{@keeper.current_project = @prj}.should_not raise_error
  end
  
  it 'should emit the "current_project_changed(QObject*)" signal with the project as argument' do
    test = flexmock('test'){|m| m.should_receive(:current_project_changed).once.with(@prj)}
    @keeper.connect(SIGNAL('current_project_changed(QObject*)')){|o| test.current_project_changed(o)}
    @keeper.current_project = @prj
  end
  
  it 'should call the "activate" method of the new current project' do
    @keeper.instance_variable_set(:@current_project, @prj)
    new_prj = Ruber::ProjectList::FakeProject.new 'Test1'
    @keeper.add_project new_prj
    flexmock(new_prj).should_receive( :activate).once
    @keeper.current_project = new_prj
  end
  
  it 'should raise ArgumentError if the project is not in the project list' do
    @keeper.instance_variable_get(:@projects).clear
    lambda{@keeper.current_project = @prj}.should raise_error(ArgumentError, "Tried to set an unknown as current project")
  end
  
end

describe 'Ruber::Project#current_project=, when called with nil' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should set the current project to nil' do
    @keeper.current_project = nil
    @keeper.current_project.should be_nil
  end
  
  it 'should emit the "current_project_changed(QObject*)" signal with Qt::NilObject as argument' do
    test = flexmock('test'){|m| m.should_receive(:current_project_changed).once.with(nil)}
    @keeper.connect(SIGNAL('current_project_changed(QObject*)')){|o| test.current_project_changed(o)}
    @keeper.current_project = nil
  end
   
end

describe 'Ruber::ProjectList#add_project' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should add the project passed as argument to the list of projects' do
    prj = Ruber::ProjectList::FakeProject.new 'Test'
    @keeper.add_project prj
    @keeper.instance_variable_get(:@projects)[prj.project_file].should equal(prj)
  end
  
  it 'should return the project' do 
    prj = Ruber::ProjectList::FakeProject.new 'Test'
    @keeper.add_project( prj).should equal(prj)
  end
  
  it 'should emit the "project_added(QObject*)" signal passing the added project' do
    prj = Ruber::ProjectList::FakeProject.new 'Test'
    m = flexmock('test'){|mk| mk.should_receive(:project_added).once.with(prj)}
    @keeper.connect(SIGNAL('project_added(QObject*)')){|o| m.project_added(o)}
    @keeper.add_project prj
  end
  
  it 'should raise RuntimeError if the project is already in the list' do
    prj_file = File.expand_path('test.ruprj')
    prj1 = Ruber::ProjectList::FakeProject.new 'test1', prj_file
    prj2 = Ruber::ProjectList::FakeProject.new 'test2', prj_file
    @keeper.add_project prj1
    lambda{@keeper.add_project prj2}.should raise_error(RuntimeError, "A project with project file #{prj_file} is already open")
  end
  
end

describe 'Ruber::ProjectList, when a project in the list is closed' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should emit the "project_closing" signal, passing the project as argument' do
    prj = Ruber::ProjectList::FakeProject.new
    @keeper.add_project prj
    m = flexmock{|mk| mk.should_receive(:project_closing).once}
    @keeper.connect(SIGNAL('closing_project(QObject*)')){|o| m.project_closing(o)}
    prj.close
  end
  
  it 'should set the current project to nil if the closed project was the current one' do
    prj = Ruber::ProjectList::FakeProject.new
    @keeper.add_project prj
    @keeper.current_project = prj
    prj.close
    @keeper.current_project.should be_nil
  end
  
end

describe 'Ruber::ProjectList#close_current_project' do
  
  include FlexMock::ArgumentTypes
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
    @prj = Ruber::ProjectList::FakeProject.new{self.object_name = 'project'}
    @keeper.add_project = @prj
    @keeper.current_project= @prj
  end
  
  it 'should set the current project to nil' do
    flexmock(@keeper).should_receive(:current_project=).with(nil).once
    @keeper.close_current_project
  end
   
  it 'should emit the "closing_project(QObject*)" signal after setting the current_project to nil, passing the project as argument' do
    test = flexmock("test"){|m| m.should_receive(:project_closed).once.with(on{|a| a == @prj and !a.disposed?})}
    flexmock(Ruber).should_receive(:[]).and_return(flexmock{|m| m.should_ignore_missing})
    @keeper.connect(SIGNAL('closing_project(QObject*)')){|o| test.project_closed(o)}
    @keeper.close_current_project
  end
  
  it 'should do nothing if the current project is nil' do
    @keeper.instance_variable_set(:@current_project, nil)
    lambda{@keeper.close_current_project}.should_not raise_error
  end
  
end

describe 'Ruber::ProjectList#new_project' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should create a new empty project and return it' do
    prj = Ruber::ProjectList::FakeProject.new 'test.ruprj', 'Test'
    flexmock(Ruber::Project).should_receive(:new).once.with('test.ruprj', 'Test').and_return prj
    res = @keeper.new_project 'test.ruprj', 'Test'
    res.should equal(prj)
  end
  
  it 'should add the new project to the project list' do
    prj = Ruber::ProjectList::FakeProject.new 'Test', 'test.ruprj'
    flexmock(Ruber::Project).should_receive(:new).once.with('test.ruprj', 'Test').and_return prj
    @keeper.new_project 'test.ruprj', 'Test'
    @keeper.instance_variable_get(:@projects)['test.ruprj'].should equal(prj)
  end
  
  it 'should emit the "project_added(QObject*)" signal with the new project as argument' do
    prj = Ruber::ProjectList::FakeProject.new 'Test', 'test.ruprj'
    flexmock(Ruber::Project).should_receive(:new).once.with('test.ruprj', 'Test').and_return prj
    m = flexmock('test'){|mk| mk.should_receive(:project_added).once.with(prj)}
    @keeper.connect(SIGNAL('project_added(QObject*)')){|o| m.project_added(o)}
    @keeper.new_project 'test.ruprj', 'Test'
  end
  
end

describe 'Ruber::Project#project' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should return the project corresponding to the file passed as argument, if it is in the list' do
    prj = Ruber::ProjectList::FakeProject.new 'Test', 'test.ruprj'
    @keeper.instance_variable_get(:@projects)[prj.project_file] = prj
    @keeper.project('test.ruprj').should equal(prj)
  end
  
  it 'should load the project from the file passed as argument if it isn\'t in the list' do
    prj = Ruber::ProjectList::FakeProject.new 'Test', 'test.ruprj'
    flexmock(Ruber::Project).should_receive(:new).once.with('test.ruprj').and_return prj
    @keeper.project('test.ruprj').should equal(prj)
  end
  
  it 'should emit the "project_added(QObject*)" signal, passing the project as argument, if the project isn\'t in the list' do
    prj = Ruber::ProjectList::FakeProject.new 'Test', 'test.ruprj'
    flexmock(Ruber::Project).should_receive(:new).once.with('test.ruprj').and_return prj
    m = flexmock{|mk| mk.should_receive(:project_added).once.with(prj)}
    @keeper.connect(SIGNAL('project_added(QObject*)')){|o| m.project_added(o)}
    @keeper.project 'test.ruprj'
  end
  
end

describe 'Ruber::Project#[]' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should return the project corresponding to the given file, if the argument is a string starting with /, if such a project exists' do
    prj = Ruber::ProjectList::FakeProject.new 'Test', '/test.ruprj'
    @keeper.add_project prj
    @keeper['/test.ruprj'].should equal(prj)
  end
  
  it 'should return the project with the given name if the argument is a string not starting with /, if such a project exists' do
    prj = Ruber::ProjectList::FakeProject.new 'xyz', '/test.ruprj'
    @keeper.add_project prj
    @keeper['xyz'].should equal(prj)
  end
  
  it 'should return nil if the requested project doesn\'t exist' do
    prj = Ruber::ProjectList::FakeProject.new 'xyz', '/test.ruprj'
    @keeper.add_project prj
    @keeper['abc'].should be_nil
    @keeper['/xyz.ruprj'].should be_nil
  end
  
end

describe 'Ruber::ProjectList#save_settings' do
  
  before do
    app = Qt::Object.new
    manager = flexmock('components'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
    pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
    @keeper = Ruber::ProjectList.new manager, pdf
  end
  
  it 'should call the save method of each open project' do
    projects = @keeper.instance_variable_get(:@projects)
    5.times do |i|
      projects[i] = flexmock(i.to_s){|m| m.should_receive(:save).once}
    end
    @keeper.save_settings
  end
  
end

describe Ruber::ProjectList do
  
  describe '#query_close' do
    
    before do
      app = Qt::Object.new
      manager = flexmock('components'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(app)
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager)
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
      pdf = Ruber::PluginSpecification.full({:name => :projects, :class => Ruber::ProjectList})
      @keeper = Ruber::ProjectList.new manager, pdf
      @values = 5.times.map{|i| flexmock(:project_name => i.to_s)}
      prjs = @keeper.instance_variable_get(:@projects)
      @values.each{|v| prjs[v.project_name] = v}
      def prjs.values
        super.sort_by{|p| p.project_name}
      end
    end
    
    it 'calls the query_close method of all the projects and returns true if they all return true' do
      @values.each{|pr| pr.should_receive(:query_close).once.and_return true}
      @keeper.query_close.should be_true
    end
    
    it 'stops iterating through the projects and returns false if one of the project\'s query_close method returns false' do
      @values[0].should_receive(:query_close).once.and_return true
      @values[1].should_receive(:query_close).once.and_return true
      @values[2].should_receive(:query_close).once.and_return false
      @values[3].should_receive(:query_close).never
      @values[4].should_receive(:query_close).never
      @keeper.query_close.should be_false
    end
    
  end
end