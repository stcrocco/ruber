require './spec/framework'
require './spec/common'

require 'set'
require 'stringio'
require 'flexmock/argument_types'
require 'pathname'
require 'ostruct'
require 'forwardable'
require 'dictionary'

require 'ruber/project'
require 'ruber/plugin'
require 'ruber/plugin_specification'

# class TestComponentManager < Qt::Object
#   
#   extend Forwardable
#   
#   def_delegators :@data, :[], :<<
#   def_delegator :@data, :each, :each_component
#   
#   signals 'component_loaded(QObject*)', 'unloading_component(QObject*)'
#   
#   def initialize
#     super
#     @data = []
#   end
#   
#   def emit_signal sig, obj
#     emit method(sig).call(obj)
#   end
#   
# end

# class Application < Qt::Object
#   signals 'plugins_changed()'
# end

unless defined? OS
  OS = OpenStruct
end

shared_examples_for 'an_abstract_project_spec_method' do
  
  include FlexMock::ArgumentTypes
  
#   before do
#     @comp = TestComponentManager.new
#     @fake_app = Application.new
#     @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
#     @mw = Qt::Widget.new
#     flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
#     flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
#     flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
#   end
  
  after do
    FileUtils.rm_f 'test.ruprj'
  end
  
end

describe 'Ruber::AbstractProject, when created' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  before do
    contents = <<-EOS
:general:
 :project_name: Test
    EOS
    @dir = make_dir_tree ['f1.ruprj'], '/tmp', {'f1.ruprj'=>contents}
    @file = File.join @dir, 'f1.ruprj'
  end
  
  after do
    FileUtils.rm_rf @dir
  end
  
  it 'should accept a parent, a file name and optionally the project name' do
    lambda{Ruber::AbstractProject.new nil, backend(@file)}.should_not raise_error
    FileUtils.rm_rf @dir
    lambda{Ruber::AbstractProject.new nil, backend(@file), 'project name'}.should_not raise_error
  end
  
  it 'should use the first argument as parent' do
    parent = Qt::Object.new
    prj = Ruber::AbstractProject.new parent, backend(@file)
    prj.parent.should equal(parent)
  end
  
  it 'sets the dialog_class instance variable to Ruber::ProjectDialog' do
    parent = Qt::Object.new
    prj = Ruber::AbstractProject.new parent, backend(@file)
    prj.instance_variable_get(:@dialog_class).should == Ruber::ProjectDialog
  end
  
  it 'should store the path of the project file as is if it\'s absolute' do
    path = @file
    prj = Ruber::AbstractProject.new nil, backend(path)
    prj.project_file.should == path
    path = File.join Dir.pwd, 'test.ruprj'
    prj = Ruber::AbstractProject.new nil, backend( path), 'Test'
    prj.project_file.should == path
  end
  
  it 'should raise ArgumentError if the file doesn\'t exist and the project name is not given' do
    lambda{Ruber::AbstractProject.new(nil, backend,'test.ruprj')}.should raise_error(ArgumentError)
  end
  
  it 'should raise ArgumentError if the file exists and the project name is given' do
    lambda{Ruber::AbstractProject.new nil, backend, @file, 'project name'}.should raise_error(ArgumentError)
  end
    
  it 'should store the project name if the file doesn\'t exist' do
    path = File.join Dir.pwd, 'test.ruprj'
    prj = Ruber::AbstractProject.new nil, Ruber::YamlSettingsBackend.new( path), 'Test Project'
    prj.project_name.should == 'Test Project'
  end
  
  it 'should read the project name from the file, if it exists' do
    prj = Ruber::AbstractProject.new nil, backend( @file)
    prj.project_name.should == 'Test'
  end
  
  it 'should call the "register_with_project" method of the plugins, passing itself as argument' do
    pdf1 = OpenStruct.new({:project_extensions => {}, :project_options => {}, :name => :plug1, :project_widgets => []})
    pdf2 = OpenStruct.new({:project_extensions => {}, :project_options => {}, :name => :plug2, :project_widgets => []})
    plugin1 = flexmock('plugin1', :plugin_description => pdf1)
    plugin2 = flexmock('plugin2', :plugin_description => pdf2)
    @comp << plugin1 << plugin2
    plugin1.should_receive(:register_with_project).once.with(Ruber::AbstractProject)
    plugin2.should_receive(:register_with_project).once.with(Ruber::AbstractProject)
    path = File.join Dir.pwd, 'test.ruprj'
    prj = Ruber::AbstractProject.new nil, Ruber::YamlSettingsBackend.new( path), 'Test'
  end
  
  it 'should connect the signal \'component_loaded\' of the component manager to a block which calls the register_with_project method of the plugin' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    o = Qt::Object.new
    flexmock(o).should_receive(:register_with_project).once.with(prj)
    @comp.emit_signal :component_loaded, o
  end
  
  it 'should connect the signal \'unloading_component\' of the component manager to a block which calls the remove_from_project method of the plugin' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    o = Qt::Object.new
    flexmock(o).should_receive(:remove_from_project).once.with(prj)
    @comp.emit_signal :unloading_component, o
  end
  
end

describe 'Ruber::AbstractProject#match_rule?' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'returns true if the object\'s scope includes the project\'s scope and false otherwise' do
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    flexmock(prj).should_receive(:scope).and_return(:global)
    prj.match_rule?(OS.new(:scope => [:global])).should be_true
    prj.match_rule?(OS.new(:scope => [:document])).should be_false
    prj.match_rule?(OS.new(:scope => [:global, :document])).should be_true
  end
  
end

describe 'Ruber::AbstractProject#scope' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'raises NoMethodError' do
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    lambda{prj.scope}.should raise_error(NoMethodError)
  end
  
end

describe 'Ruber::AbstractProject#add_extension' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'should add the given extension to the list of extensions' do
    ext = Qt::Object.new
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    prj.add_extension :test_ext, ext
    prj.project_extension(:test_ext).should equal(ext)
  end
  
  it 'should raise ArgumentError if an extension with that name already exists' do
    ext1 = Qt::Object.new
    ext2 = Qt::Object.new
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    prj.add_extension :test_ext, ext1
    lambda{prj.add_extension(:test_ext, ext2)}.should raise_error(ArgumentError, 'An extension called \'test_ext\' already exists')
  end
  
end

describe 'Ruber::AbstractProject#remove_extension' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'should remove the extension with the given name from the list' do
    ext1 = Qt::Object.new
    ext2 = Qt::Object.new
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    prj.add_extension :ext1, ext1
    prj.add_extension :ext2, ext2
    prj.remove_extension :ext2
    prj.instance_variable_get(:@project_extensions).should_not include(:ext2)
    prj.ext1.should equal(ext1)
  end
  
  it 'should call the "remove_from_project" method of the extension, if it provides it' do
    ext1 = Qt::Object.new
    def ext1.remove_from_project
    end
    ext2 = Qt::Object.new
    flexmock(ext1).should_receive(:remove_from_project).once
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    prj.add_extension :e1, ext1
    prj.add_extension :e2, ext2
    prj.remove_extension :e1
    lambda{prj.remove_extension :e2}.should_not raise_error
  end
  
  it 'should do nothing if a project extension with that name doesn\'t exist' do
    ext1 = Qt::Object.new
    ext2 = Qt::Object.new
    prj = Ruber::AbstractProject.new(nil, backend(File.join(Dir.pwd, 'project.ruprj')), 'Test')
    prj.add_extension :ext1, ext1
    prj.add_extension :ext2, ext2
    old = prj.instance_variable_get(:@project_extensions).dup
    prj.remove_extension :ext3
    prj.instance_variable_get(:@project_extensions).should == old
  end
  
end

describe 'Ruber::AbstractProject#[]=' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  before do
    contents = <<-EOS
:general:
 :project_name: Test
:g1:
 :o1: 3
:g2:
 :o2: xyz
 :o3: [a, b]
    EOS
    @dir = make_dir_tree ['test.ruprj'], '/tmp', {'test.ruprj' => contents}
    @file = File.join @dir, 'test.ruprj'
    @options = [
      OS.new({:name => :o1, :group => :g1, :default => 0}),
      OS.new({:name => :o2, :group => :g2, :default => 'abc'}),
      OS.new({:name => :o3, :group => :g2, :default => []}),
    ]
    @prj = Ruber::AbstractProject.new nil, backend(@file)
    @options.each{|o| @prj.add_option o}
  end
  
  after do
    FileUtils.rm_rf @dir
  end
  
  it 'should change the value of the option whose name is passed as first argument' do
    @prj[:g1, :o1]= 6
    @prj[:g2, :o2] = 'ABC'
    @prj[:g2, :o3] = :x
    @prj[:g1, :o1].should == 6
    @prj[:g2, :o2].should == 'ABC'
    @prj[:g2, :o3].should == :x
  end
  
  it 'should emit the "option_changed(QString, QString)" signal if the option is modified, passing the group and the name of the option (converted to strings) as argument' do
    test = flexmock('test') do |mk|
      mk.should_receive(:option_changed).once.with('g1', 'o1')
      mk.should_receive(:option_changed).once.with('g2', 'o2')
      mk.should_receive(:option_changed).once.with('g2', 'o3')
    end
    @prj.connect(SIGNAL('option_changed(QString, QString)')){|g, n| test.option_changed g, n}
    @prj[:g1, :o1]= 6
    @prj[:g2, :o2] = 'ABC'
    @prj[:g2, :o3] = :x
  end
  
  it 'should not emit the option_changed signal if the new value of the option is the same as the old (according to eql?)' do
    test = flexmock('test') do |mk|
      mk.should_receive(:option_changed).with('g1', 'o1').never
      mk.should_receive(:option_changed).with('g2', 'o2').never
      mk.should_receive(:option_changed).with('g2', 'o3').never
    end
    @prj[:g1, :o1]= 5
    @prj[:g2, :o2] = 'xyz'
    @prj[:g2, :o3] = :a
    @prj.connect(SIGNAL('option_changed(QString, QString)')){|g, n| test.option_changed g, n}
    @prj[:g1, :o1]= 5
    @prj[:g2, :o2] = 'xyz'
    @prj[:g2, :o3] = :a

  end
  
end

describe 'Ruber::AbstractProject#project_directory' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'should return the absolute path of the project directory' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    prj.project_directory.should == Dir.pwd
  end 
  
end

describe 'Ruber::AbstractProject#method_missing' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'should return the project extension object with the same name as the method, if it exists' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    p1 = flexmock('p1')
    prj.instance_variable_get(:@project_extensions)[:p1] = p1
    prj.p1.should == p1
  end
  
  it 'should raise ArgumentError if any arguments are passed to the method' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    p1 = flexmock('p1')
    prj.instance_variable_get(:@project_extensions)[:p1] = p1
    lambda{prj.p1 'x'}.should raise_error(ArgumentError, "wrong number of arguments (1 for 0)")
  end
  
  it 'should raise ArgumentError if there\'s no project extension with the name of the method' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    p1 = flexmock('p1')
    prj.instance_variable_get(:@project_extensions)[:p1] = p1
    lambda{prj.p2}.should raise_error(ArgumentError, "No project extension with name p2")
  end
  
end

describe 'Ruber::AbstractProject#project_extension' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'should return the project extension with the given name, if it exists' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    p1 = flexmock('p1')
    prj.instance_variable_get(:@project_extensions)[:p1] = p1
    prj.project_extension(:p1).should == p1
  end
  
  it 'should return nil if no project extension with that name exists' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test.prj'
    prj.project_extension(:p1).should be_nil
  end
  
end

describe Ruber::AbstractProject do
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  describe '#each_extension' do
    
    before do
      @prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      @exts = {:a => 1, :b => 2, :c => 3}
      @prj.instance_variable_set(:@project_extensions, @exts)
    end
    
    describe ', when called with a block' do
      
      it 'calls the block for each extension, passing it the name of the extension and the object itself as arguments' do
        res = {}
        @prj.each_extension{|i, j| res[i] = j}
        res.should == @exts
      end
      
    end
    
    describe ', when called without a block' do
      
      it 'returns an enumerator which, whose each method calls the block for each extension, passing it the name of the extension and the object itself as arguments' do
        res = {}
        enum = @prj.each_extension
        enum.should be_a(Enumerator)
        enum.each{|i, j| res[i] = j}
        res.should == @exts
      end
      
    end
    
  end
  
  describe '#extensions' do
    
    before do
      @prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      @exts = {:a => "1", :b => "2", :c => "3"}
      @prj.instance_variable_set(:@project_extensions, @exts)
    end
    
    it 'returns a hash containing the extensions with their names' do
      @prj.extensions.should == @exts
    end
    
    it 'returns a hash which can be modified without modifying the internal list of extensions' do
      @prj.extensions.should_not be_the_same_as(@exts)
    end
      
  end
  
  describe '#has_extension?' do
    
    before do
      @prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      @exts = {:a => "1", :b => "2", :c => "3"}
      @prj.instance_variable_set(:@project_extensions, @exts)
    end
    
    it 'returns true if the project contains an extension with the given name' do
      @prj.has_extension?(:a).should == true
    end
    
    it 'returns false if the project doesn\'t contain an extension with the given name' do
      @prj.has_extension?(:x).should == false
    end
    
  end

end

describe 'Ruber::AbstractProject#close' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  include FlexMock::ArgumentTypes
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end

  describe ', when the argument is true' do
    
    it 'calls the "save" method' do
      prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      flexmock(prj).should_receive(:save).once
      prj.close true
    end
    
    it 'returns false if save returns false' do
      prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      flexmock(prj).should_receive(:save).once.and_return false
      prj.close(true).should be_false
    end
    
    it 'returns true if save returns true' do
      prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      flexmock(prj).should_receive(:save).once.and_return true
      prj.close(true).should be_true
    end
    
  end
  
  describe ', when the argument is false' do
    
    it 'doesn\'t call the "save" method' do
      prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      flexmock(prj).should_receive(:save).never
      prj.close false
    end
    
    it 'always returns true' do
      prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      prj.close(false).should be_true
    end
    
  end
  
  it 'should emit the "closing(QObject*)" signal, passing itself as argument' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    m = flexmock{|mk| mk.should_receive(:project_closing).with(prj.object_id).once}
    prj.connect(SIGNAL('closing(QObject*)')){|pr| m.project_closing pr.object_id}
    prj.close
  end
  
  it 'should remove all extensions' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    prj.add_extension :e1, Qt::Object.new{|o| o.extend Ruber::Extension}
    prj.add_extension :e2, Qt::Object.new{|o| o.extend Ruber::Extension}
    flexmock(prj).should_receive(:remove_extension).with(:e1).once
    flexmock(prj).should_receive(:remove_extension).with(:e2).once
    prj.close
  end
  
  it 'removes the connection with the block which register a component with the project' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    flexmock(@comp).should_receive(:named_disconnect).once.with("register_component_with_project #{prj.object_id}")
    flexmock(@comp).should_receive(:named_disconnect).with(any)
    prj.close
  end
  
  it 'removes the connection with the block which removes a component from the project' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    flexmock(@comp).should_receive(:named_disconnect).once.with("remove_component_from_project #{prj.object_id}")
    flexmock(@comp).should_receive(:named_disconnect).with(any)
    prj.close
  end
  
  it 'doesn\'t dispose of the project' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    prj.close
    prj.should_not be_disposed
  end
    
end

describe 'Ruber::AbstractProject#save' do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'emits the "saving()" signal' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    m = flexmock{|mk| mk.should_receive(:save).once}
    prj.connect(SIGNAL(:saving)){m.save}
    flexmock(prj).should_receive(:write) #to avoid actually creating a file
    prj.save
  end
  
  it 'calls the save_settings method of each extension' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    flexmock(prj).should_receive(:write) #to avoid actually creating a file
    5.times do |i|
      prj.instance_variable_get(:@project_extensions)[i.to_s] = flexmock{|m| m.should_receive(:save_settings).once}
    end
    prj.save
  end
  
  it 'calls the write method after saving the extensions' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    m = flexmock{|mk| mk.should_receive(:save).once.ordered}
    prj.instance_variable_get(:@project_extensions)[:x] = flexmock{|mk| mk.should_receive(:save_settings).once.ordered}
    prj.connect(SIGNAL(:saving)){m.save}
    flexmock(prj).should_receive(:write).once.ordered
    prj.save
  end
  
  it 'returns true if the project was saved correctly and false if an error occurs in the write method' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    flexmock(prj).should_receive(:write).once
    prj.save.should be_true
    flexmock(prj).should_receive(:write).once.and_raise(Exception)
    prj.save.should be_false
  end
  
  it 'propagates any exception raised from methods connected to the "saving()" signal' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    m = flexmock{|mk| mk.should_receive(:save).once.and_raise(Exception, "A slot raised an error")}
    prj.connect(SIGNAL(:saving)){m.save}
    flexmock(prj).should_receive(:write) #to avoid actually creating a file
    lambda{prj.save}.should raise_error(Exception, "A slot raised an error")
  end
  
end

describe Ruber::AbstractProject, "#write" do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  it 'should emit the "settings_changed()" signal' do
    prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
    mk = flexmock{|m| m.should_receive(:settings_changed).once}
    prj.connect(SIGNAL(:settings_changed)){mk.settings_changed}
    prj.write
  end
  
end

describe Ruber::AbstractProject do
  
  it_should_behave_like 'an_abstract_project_spec_method'
  
  def backend file
    Ruber::YamlSettingsBackend.new file
  end
  
  before do
    @prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
  end

  describe "#query_close" do
  
    before do
      @exts = Dictionary.new
      5.times{|i| @exts[i.to_s] = flexmock}
      @prj.instance_variable_set :@project_extensions, @exts
    end

    it 'calls the query_close method of all the extensions and returns true if they all return true' do
      @exts.each{|n, e| e.should_receive(:query_close).once.and_return true}
      @prj.query_close.should be_true
    end
      
    it 'stops iterating through the extensions and returns false if one of the extensions\' query_close method returns false' do
      @exts['0'].should_receive(:query_close).once.and_return true
      @exts['1'].should_receive(:query_close).once.and_return true
      @exts['2'].should_receive(:query_close).once.and_return false
      @exts['3'].should_receive(:query_close).never
      @exts['4'].should_receive(:query_close).never
      @prj.query_close.should be_false
    end
    
  end
  
  describe '#files' do
    
    it 'retruns an empty array' do
      prj = Ruber::AbstractProject.new nil, backend(File.join(Dir.pwd, 'test.ruprj')), 'Test'
      prj.files.should == []
    end
    
  end
  
end

describe Ruber::Project do
  
  it 'should inherit from Ruber::AbstractProject' do
    Ruber::Project.ancestors.should include(Ruber::AbstractProject)
  end
  
  it 'should include the Ruber::Activable module' do
    Ruber::Project.ancestors.should include(Ruber::Activable)
  end
  
end

describe Ruber::Project do
  
  describe 'when created' do
    
    before do
      @comp = TestComponentManager.new
      @projects = Qt::Object.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
      @dir = nil
    end
    
    after do
      FileUtils.rm_rf @dir if @dir
    end
    
    it 'uses the projects component as parent' do
      prj = Ruber::Project.new @file, 'Test'
      prj.parent.should equal(@projects)
    end
    
    it 'uses Ruber::ProjectBackend as backend' do
      prj = Ruber::Project.new @file, 'Test'
      prj.instance_variable_get(:@backend).should be_a(Ruber::ProjectBackend)
    end
    
    it 'raises Ruber::AbstractProject::InvalidProjectFile if the file exists and is not a valid project file' do
      @dir = make_dir_tree ['f1.ruprj'], '/tmp', {'f1.ruprj'=> "project_name: {"}
      lambda{Ruber::Project.new File.join(@dir, 'f1.ruprj')}.should raise_error(Ruber::AbstractProject::InvalidProjectFile)
    end
    
    it 'considers a relative file relative to the current directory' do
      prj = Ruber::Project.new 'test.ruprj', 'Test'
      prj.project_file.should == @file
    end
    
    it 'is not active' do
      Ruber::Project.new(@file, 'Test').should_not be_active
    end
    
  end
  
  describe ', when closing' do
    
    before do
      @comp = TestComponentManager.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
    end
    
    it 'should deactivate itself' do
      prj = Ruber::Project.new @file, 'Test'
      flexmock(prj).should_receive(:deactivate).once
      flexmock(prj.instance_variable_get(:@backend)).should_receive(:write)
      prj.close
    end
    
    it 'should call super' do
      prj = Ruber::Project.new @file, 'Test'
      flexmock(prj).should_receive(:save).once
      prj.close true
    end
    
    it 'disposes of itself' do
      prj = Ruber::Project.new @file, 'Test'
      prj.close false
      prj.should be_disposed
    end

    
    describe ', if super returns true' do
      
      it 'returns true' do
        prj = Ruber::Project.new @file, 'Test'
        prj.close(false).should == true
      end
    
    end
    
    describe ', if super returns false' do
      
      it 'returns false' do
        prj = Ruber::Project.new @file, 'Test'
        flexmock(prj).should_receive(:write).once.and_raise(Exception)
        prj.close(true).should == false
      end
    
    end
      
  end
  
  describe '#activate' do
    
    before do
      @comp = TestComponentManager.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
    end
    
    it 'sets the "active" state to true' do
      prj = Ruber::Project.new @file, 'Test'
      prj.activate
      prj.should be_active
    end
    
    it 'emits the "activated()" signal if previously the project wasn\'t active' do
      prj = Ruber::Project.new @file, 'Test'
      m = flexmock('test'){|mk| mk.should_receive(:project_activated).once}
      prj.connect(SIGNAL('activated()')){m.project_activated}
      prj.activate
    end
    
    it 'doesn\'t emit the "activated()" signal if the project was already active' do
      prj = Ruber::Project.new @file, 'Test'
      prj.activate
      m = flexmock('test'){|mk| mk.should_receive(:project_activated).never}
      prj.connect(SIGNAL('activated()')){m.project_activated}
      prj.activate
    end
    
  end
  
  describe '#deactivate' do
    
    before do
      @comp = TestComponentManager.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
    end
    
    it 'sets the "active" state to false' do
      prj = Ruber::Project.new @file, 'Test'
      prj.activate
      prj.deactivate
      prj.should_not be_active
    end
    
    it 'emits the "deactivated()" signal if the project was active' do
      prj = Ruber::Project.new @file, 'Test'
      prj.activate
      m = flexmock('test'){|mk| mk.should_receive(:project_deactivated).once}
      prj.connect(SIGNAL('deactivated()')){m.project_deactivated}
      prj.deactivate
    end
    
    it 'doesn\'t emit the "deactivated()" signal if the project was already inactive' do
      prj = Ruber::Project.new @file, 'Test'
      m = flexmock('test'){|mk| mk.should_receive(:project_deactivated).never}
      prj.connect(SIGNAL('deactivated()')){m.project_deactivated}
      prj.deactivate
    end
    
  end
  
  describe '#scope' do
    before do
      @comp = TestComponentManager.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
    end
    
    it 'returns :global' do
      Ruber::Project.new(@file, 'Test').scope.should == :global
    end
  end
  
  describe '#add_option' do
    
    before do
      @comp = TestComponentManager.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
      @prj = Ruber::Project.new(@file, 'Test')
    end
    
    it 'sets the type of the option to :global if it is nil' do
      opt = OS.new(:name => :o, :group => :g, :default => 3)
      back = @prj.instance_variable_get :@backend
      flexmock(back).should_receive(:[]).once.with(OS.new(:name => :o, :group => :g, :default => 3, :type => :global))
      lambda{@prj.add_option opt}.should_not raise_error
    end
    
    it 'calls super' do
      opt = OS.new(:name => :o, :group => :g, :default => 3, :type => :user)
      @prj.add_option opt
      vars = @prj.instance_variable_get(:@known_options)
      vars[[:g, :o]].should == opt
      @prj[:g, :o].should == 3
    end
    
  end
  
  describe '#files' do
    
    before do
      @comp = TestComponentManager.new
      @fake_app = Application.new
      @dlg = flexmock('dialog', :read_settings => nil, :dispose => nil)
      @mw = Qt::Widget.new
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(  @comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return( @fake_app).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return( @mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return( @projects).by_default
      @file = File.join Dir.pwd, 'test.ruprj'
      @prj = Ruber::Project.new(@file, 'Test')
    end
    
    it 'returns an array containing the files belonging to the project' do
      files = %w[/a /b /c]
      project_files = flexmock{|m| m.should_receive(:project_files).once.and_return files}
      @prj.instance_variable_get(:@project_extensions)[:project_files] = project_files
      @prj.files.should == %w[/a /b /c] 
    end

  end
    
end

describe Ruber::ProjectDialog do
  
  describe 'widget_from_class' do
    
    it 'passes the project to the widget\'s class new method' do
      mw = Qt::Widget.new
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return mw
      prj = flexmock('project')
      box = Qt::CheckBox.new
      flexmock(Qt::CheckBox).should_receive(:new).once.with(prj).and_return box
      dlg = Ruber::ProjectDialog.new prj, [], [OpenStruct.new(:class_obj => Qt::CheckBox, :caption => 'General')]
    end
    
  end
  
end

describe Ruber::ProjectConfigWidget do
  
  it 'derives from Qt::Widget' do
    Ruber::ProjectConfigWidget.ancestors.should include(Qt::Widget)
  end
  
  describe ', when created' do
    
    it 'passes nil to the superclass constructor' do
      w = Ruber::ProjectConfigWidget.new 'x'
      w.parent.should be_nil
    end
    
    it 'accepts one argument and stores it in the "project" attribute' do
      prj = flexmock('project')
      w = Ruber::ProjectConfigWidget.new prj
      w.project.should == prj
    end
    
  end
  
end