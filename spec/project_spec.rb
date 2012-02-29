require './spec/framework'
require './spec/common'

require 'set'
require 'stringio'
require 'flexmock/argument_types'
require 'pathname'
require 'ostruct'
require 'forwardable'
require 'dictionary'
require 'fileutils'

require 'ruber/project'
require 'ruber/plugin'
require 'ruber/plugin_specification'


unless defined? OS
  OS = OpenStruct
end

shared_examples_for 'an_abstract_project_spec_method' do
  
  include FlexMock::ArgumentTypes
  
  after do
    FileUtils.rm_f 'test.ruprj'
  end
  
end

describe Ruber::AbstractProject do
  
  before do
    @file = File.join '/tmp', 'f1.ruprj'
    File.open(@file, 'w') do |f|
      f.write YAML.dump({:general => {:project_name => 'Test'}})
    end
    @prj = Ruber::AbstractProject.new nil, backend
  end
    
  after do
    FileUtils.rm_rf @file if @file
  end
  
  def backend
    Ruber::YamlSettingsBackend.new @file 
  end
  
  after do
    FileUtils.rm_rf @file if @file
  end
  
  context 'when created' do
    
    context 'if the backend doesn\'t contain the general/project_name setting' do
      
      before do
        FileUtils.rm_rf @file
      end
      
      it 'accepts the parent object, the backend and a project name as arguments' do
        lambda{Ruber::AbstractProject.new nil, backend, 'Test'}.should_not raise_error
      end
      
      it 'raises ArgumentError if the project name is not given' do
        lambda{Ruber::AbstractProject.new(nil, backend)}.should raise_error(ArgumentError, "You need to specify a project name for a new project")
      end
      
      it 'sets the backend\'s general/project_name setting to the value passed as third argument' do
        prj = Ruber::AbstractProject.new nil, backend, 'Test'
        prj[:general, :project_name].should == 'Test'
      end
      
      it 'sets the project_name attribute to the value passed as third argument' do
        prj = Ruber::AbstractProject.new nil, backend, 'Test'
        prj.project_name.should == 'Test'
      end
      
    end
    
    context 'if the backend contains the general/project_name setting' do
      
      it 'accepts the parent object and the backend as arguments' do
        lambda{Ruber::AbstractProject.new nil, backend}.should_not raise_error
      end
      
      it 'raises ArgumentError if the project name is given' do
        lambda{Ruber::AbstractProject.new nil, backend, 'Test'}.should raise_error(ArgumentError, "You can't specify a file name for an already existing project")
      end
      
      it 'raises Ruber::AbstractProject::InvalidProjectFile if the project file exists but  doesn\'t contain the project_name setting' do
        File.open(@file, 'w') {|f| f.write '{}'}
        error_msg = "The project file #@file isn't valid because it doesn't contain a project name entry"
        lambda{Ruber::AbstractProject.new(nil, backend)}.should raise_error(Ruber::AbstractProject::InvalidProjectFile, error_msg )
      end
      
      it 'sets the project_name attribute to the general/project_name setting contained in the backend' do
        prj = Ruber::AbstractProject.new nil, backend
        prj.project_name.should == 'Test'
      end

    end
    
    it 'uses the first argument as parent object' do
      parent = Qt::Object.new
      prj = Ruber::AbstractProject.new parent, backend
      prj.parent.should equal(parent)
    end
  
    it 'sets the dialog_class instance variable to Ruber::ProjectDialog' do
      parent = Qt::Object.new
      prj = Ruber::AbstractProject.new parent, backend
      prj.instance_variable_get(:@dialog_class).should == Ruber::ProjectDialog
    end
    
    it 'sets the project_file attribute to the path of the file associated with the backend' do
      prj = Ruber::AbstractProject.new nil, backend
      prj.project_file.should == @file
    end
      
    it 'connects the signal \'component_loaded\' of the component manager to a block which calls the register_with_project method of the plugin' do
      # Avoid projects created in previous tests reacting to the same signal
      ObjectSpace.each_object(Ruber::AbstractProject) do |pr|
        Ruber[:components].disconnect SIGNAL('component_loaded(QObject*)'), nil, nil
      end
      # Avoid document projects reacting to the same signal
      Ruber[:world].close_all :documents
      prj = Ruber::AbstractProject.new nil, backend
      o = Qt::Object.new
      # Needed because the main window requires this
      def o.plugin_name; :x;end
      flexmock(o).should_receive(:register_with_project).once.with(prj)
      Ruber[:components].instance_eval{ emit component_loaded(o)}
    end
    
    it 'connects the signal \'unloading_component\' of the component manager to a block which calls the remove_from_project method of the plugin' do
      # Avoid projects created in previous tests reacting to the same signal
      ObjectSpace.each_object(Ruber::AbstractProject) do |pr|
        Ruber[:components].disconnect SIGNAL('unloading_component(QObject*)'), nil, nil
      end
      # Avoid document projects reacting to the same signal
      Ruber[:world].close_all :documents
      prj = Ruber::AbstractProject.new nil, backend
      o = Qt::Object.new
      # Needed because the main window requires this
      def o.plugin_name; :x;end
      flexmock(o).should_receive(:remove_from_project).once.with(prj)
      Ruber[:components].instance_eval{emit unloading_component(o)}
    end
    
  end
  
  describe '#match_rule?' do
    
    before do
      @file = File.join '/tmp', 'f1.ruprj'
      File.open(@file, 'w') do |f|
        f.write YAML.dump({:general => {:project_name => 'Test'}})
      end
      @prj = Ruber::AbstractProject.new nil, backend
    end
    
    after do
      FileUtils.rm_rf @file if @file
    end
    
    it 'returns true if the argument\'s scope includes the project\'s scope' do
      flexmock(@prj).should_receive(:scope).and_return(:global)
      @prj.match_rule?(OS.new(:scope => [:global])).should be_true
      @prj.match_rule?(OS.new(:scope => [:global, :document])).should be_true
    end
    
    it 'returns false if the argument\'s scope doesn\'t include the project\'s scope' do
      flexmock(@prj).should_receive(:scope).and_return(:global)
      @prj.match_rule?(OS.new(:scope => [:document])).should be_false
    end
    
  end
  
  describe '#scope' do
  
    it 'raises NoMethodError' do
      lambda{@prj.scope}.should raise_error(NoMethodError)
    end
  
  end
  
  describe '#add_extension' do
  
    it 'adds the given extension to the list of extensions' do
      ext = Qt::Object.new
      @prj.add_extension :test_ext, ext
      @prj.project_extension(:test_ext).should equal(ext)
    end
    
    it 'raises ArgumentError if an extension with that name already exists' do
      ext1 = Qt::Object.new
      ext2 = Qt::Object.new
      @prj.add_extension :test_ext, ext1
      lambda{@prj.add_extension(:test_ext, ext2)}.should raise_error(ArgumentError, 'An extension called \'test_ext\' already exists')
    end
    
  end
  
  describe '#remove_extension' do
    
    it 'removes the extension with the given name from the list' do
      ext1 = Qt::Object.new
      ext2 = Qt::Object.new
      @prj.add_extension :ext1, ext1
      @prj.add_extension :ext2, ext2
      @prj.remove_extension :ext2
      @prj.instance_variable_get(:@project_extensions).should_not include(:ext2)
      @prj.ext1.should equal(ext1)
    end
    
    it 'calls the "remove_from_project" method of the extension, if it provides it' do
      ext1 = Qt::Object.new
      def ext1.remove_from_project
      end
      ext2 = Qt::Object.new
      flexmock(ext1).should_receive(:remove_from_project).once
      @prj.add_extension :e1, ext1
      @prj.add_extension :e2, ext2
      @prj.remove_extension :e1
      lambda{@prj.remove_extension :e2}.should_not raise_error
    end
    
    it 'does nothing if a project extension with that name doesn\'t exist' do
      ext1 = Qt::Object.new
      ext2 = Qt::Object.new
      @prj.add_extension :ext1, ext1
      @prj.add_extension :ext2, ext2
      old = @prj.instance_variable_get(:@project_extensions).dup
      @prj.remove_extension :ext3
      @prj.instance_variable_get(:@project_extensions).should == old
    end
    
  end
  
  describe '#[]=' do
    
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
      File.open(@file, 'w'){|f| f.write contents}
      @options = [
        OS.new({:name => :o1, :group => :g1, :default => 0}),
        OS.new({:name => :o2, :group => :g2, :default => 'abc'}),
        OS.new({:name => :o3, :group => :g2, :default => []}),
      ]
      @prj = Ruber::AbstractProject.new nil, backend
      @options.each{|o| @prj.add_option o}
    end
    
    it 'changes the value of the option whose group and name are passed as first arguments' do
      @prj[:g1, :o1]= 6
      @prj[:g2, :o2] = 'ABC'
      @prj[:g2, :o3] = :x
      @prj[:g1, :o1].should == 6
      @prj[:g2, :o2].should == 'ABC'
      @prj[:g2, :o3].should == :x
    end
    
    it 'emits the "option_changed(QString, QString)" signal if the option is modified, passing the group and the name of the option (converted to strings) as arguments' do
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
    
    it 'doesn\'t emit the option_changed signal if the new value of the option is the same as the old (according to eql?)' do
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
  
  describe '#project_directory' do
    
    it 'returns the absolute path of the project directory' do
      @prj.project_directory.should == '/tmp'
    end
    
  end
  
  describe '#method_missing' do
    
    it 'returns the project extension object with the same name as the method, if it exists' do
      p1 = flexmock('p1')
      @prj.instance_variable_get(:@project_extensions)[:p1] = p1
      @prj.p1.should == p1
    end
    
    it 'raises ArgumentError if any arguments are passed to the method' do
      p1 = flexmock('p1')
      @prj.instance_variable_get(:@project_extensions)[:p1] = p1
      lambda{@prj.p1 'x'}.should raise_error(ArgumentError, "wrong number of arguments (1 for 0)")
    end
    
    it 'raises NoMethodError if there\'s no project extension with the name of the method' do
      p1 = flexmock('p1')
      @prj.instance_variable_get(:@project_extensions)[:p1] = p1
      lambda{@prj.p2}.should raise_error(NoMethodError)
    end
    
  end
  
  describe '#extension' do
  
    it 'returns the extension with the given name, if it exists' do
      p1 = flexmock('p1')
      @prj.instance_variable_get(:@project_extensions)[:p1] = p1
      @prj.extension(:p1).should == p1
    end
    
    it 'returns nil if no extension with that name exists' do
      @prj.project_extension(:p1).should be_nil
    end
    
  end
  
  describe '#extensions' do
    
    before do
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
  
  describe '#each_extension' do
    
    before do
      @exts = {:a => 1, :b => 2, :c => 3}
      @prj.instance_variable_set(:@project_extensions, @exts)
    end
    
    context 'when called with a block' do
      
      it 'calls the block for each extension, passing it the name of the extension and the object itself as arguments' do
        res = {}
        @prj.each_extension{|i, j| res[i] = j}
        res.should == @exts
      end
      
    end
      
    context ' when called without a block' do
      
      it 'returns an enumerator which, whose each method calls the block for each extension, passing it the name of the extension and the object itself as arguments' do
        res = {}
        enum = @prj.each_extension
        enum.should be_a(Enumerator)
        enum.each{|i, j| res[i] = j}
        res.should == @exts
      end
      
    end

  end
  
  describe '#close' do
    
    include FlexMock::ArgumentTypes
    
    context 'when the argument is true' do
      
      it 'calls the "save" method' do
        flexmock(@prj).should_receive(:save).once
        @prj.close true
      end
      
      it 'returns false if save returns false' do
        flexmock(@prj).should_receive(:save).once.and_return false
        @prj.close(true).should be_false
      end
      
      it 'returns true if save returns true' do
        flexmock(@prj).should_receive(:save).once.and_return true
        @prj.close(true).should be_true
      end
      
    end
    
    context 'when the argument is false' do
    
      it 'doesn\'t call the "save" method' do
        flexmock(@prj).should_receive(:save).never
        @prj.close false
      end
      
      it 'always returns true' do
        @prj.close(false).should be_true
      end
      
    end

    it 'emits the "closing(QObject*)" signal, passing itself as argument' do
      m = flexmock{|mk| mk.should_receive(:project_closing).with(@prj.object_id).once}
      @prj.connect(SIGNAL('closing(QObject*)')){|pr| m.project_closing pr.object_id}
      @prj.close
    end
    
    it 'removes all extensions' do
      @prj.add_extension :e1, Qt::Object.new{|o| o.extend Ruber::Extension}
      @prj.add_extension :e2, Qt::Object.new{|o| o.extend Ruber::Extension}
      flexmock(@prj).should_receive(:remove_extension).with(:e1).once
      flexmock(@prj).should_receive(:remove_extension).with(:e2).once
      @prj.close
    end
    
    it 'removes the connection with the block which register a component with the project' do
      flexmock(Ruber[:components]).should_receive(:named_disconnect).once.with("register_component_with_project #{@prj.object_id}")
      flexmock(Ruber[:components]).should_receive(:named_disconnect).with(any)
      @prj.close
    end
    
    it 'removes the connection with the block which removes a component from the project' do
      flexmock(Ruber[:components]).should_receive(:named_disconnect).once.with("remove_component_from_project #{@prj.object_id}")
      flexmock(Ruber[:components]).should_receive(:named_disconnect).with(any)
      @prj.close
    end
    
    it 'doesn\'t dispose of the project' do
      @prj.close
      @prj.should_not be_disposed
    end
    
  end
  
  describe '#save' do

    it 'emits the "saving()" signal' do
      m = flexmock{|mk| mk.should_receive(:save).once}
      @prj.connect(SIGNAL(:saving)){m.save}
      @prj.save
    end
    
    it 'calls the save_settings method of each extension' do
      flexmock(@prj).should_receive(:write) #to avoid actually creating a file
      5.times do |i|
        @prj.instance_variable_get(:@project_extensions)[i.to_s] = flexmock{|m| m.should_receive(:save_settings).once}
      end
      @prj.save
    end
    
    it 'calls the write method after saving the extensions' do
      m = flexmock{|mk| mk.should_receive(:save).once.ordered}
      @prj.instance_variable_get(:@project_extensions)[:x] = flexmock{|mk| mk.should_receive(:save_settings).once.ordered}
      @prj.connect(SIGNAL(:saving)){m.save}
      flexmock(@prj).should_receive(:write).once.ordered
      @prj.save
    end
    
    it 'returns true if the project was saved correctly and false if an error occurs in the write method' do
      flexmock(@prj).should_receive(:write).once
      @prj.save.should be_true
    end
    
    it 'returns false if an error occurs in the #write method' do
      flexmock(@prj).should_receive(:write).once.and_raise(Exception)
      @prj.save.should be_false
    end
    
    it 'propagates any exception raised from methods connected to the "saving()" signal' do
      m = flexmock{|mk| mk.should_receive(:save).once.and_raise(Exception, "A slot raised an error")}
      @prj.connect(SIGNAL(:saving)){m.save}
      flexmock(@prj).should_receive(:write) #to avoid actually creating a file
      lambda{@prj.save}.should raise_error(Exception, "A slot raised an error")
    end
    
  end
  
  describe '#write' do
    
    it 'emits the "settings_changed()" signal' do
      mk = flexmock{|m| m.should_receive(:settings_changed).once}
      @prj.connect(SIGNAL(:settings_changed)){mk.settings_changed}
      @prj.write
    end

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
    
    it 'returns an empty array' do
      @prj.files.should == []
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
  
  before do
    @dir = nil
    @file = File.join '/tmp', 'test.ruprj'
    File.open(@file, 'w') do |f|
      f.write YAML.dump({:general => {:project_name => 'Test'}})
    end
  end
  
  after do
    FileUtils.rm_rf @file if @file
    FileUtils.rm_rf @dir if @dir
  end
  
  context 'when created' do
        
    it 'uses the world component as parent' do
      prj = Ruber::Project.new @file
      prj.parent.should equal(Ruber[:world])
    end
    
    it 'uses Ruber::ProjectBackend as backend' do
      prj = Ruber::Project.new @file
      prj.instance_variable_get(:@backend).should be_a(Ruber::ProjectBackend)
    end
    
    it 'raises Ruber::AbstractProject::InvalidProjectFile if the file exists and is not a valid project file' do
      @dir = make_dir_tree ['f1.ruprj'], '/tmp', {'f1.ruprj'=> "project_name: {"}
      lambda{Ruber::Project.new File.join(@dir, 'f1.ruprj')}.should raise_error(Ruber::AbstractProject::InvalidProjectFile)
    end
    
    it 'considers a relative file relative to the current directory' do
      prj = Ruber::Project.new 'test.ruprj', 'Test'
      prj.project_file.should == File.join(Dir.pwd, 'test.ruprj')
    end
    
    it 'is not active' do
      Ruber::Project.new(@file).should_not be_active
    end
    
  end
  
  context 'when closing' do
    
    before do
      @prj = Ruber::Project.new @file 
    end
    
    it 'should deactivate itself' do
      flexmock(@prj).should_receive(:deactivate).once
      flexmock(@prj.instance_variable_get(:@backend)).should_receive(:write)
      @prj.close
    end
    
    it 'should call super' do
      flexmock(@prj).should_receive(:save).once
      @prj.close true
    end
    
    it 'disposes of itself' do
      @prj.close false
      @prj.should be_disposed
    end
    
    context 'and if super returns true' do
      
      it 'returns true' do
        @prj.close(false).should == true
      end
    
    end
    
    context 'and super returns false' do
      
      it 'returns false' do
        flexmock(@prj).should_receive(:write).once.and_raise(Exception)
        @prj.close(true).should == false
      end
    
    end
      
  end
  
  describe '#activate' do
    
    before do
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
      @file = File.join Dir.pwd, 'test.ruprj'
    end
    
    it 'returns :global' do
      Ruber::Project.new(@file, 'Test').scope.should == :global
    end
  end
  
  describe '#add_option' do
    
    before do
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
      @dir = make_dir_tree %w[f1.rb f2.rb f3.rb f4.xyz f5.xyz f6.xyz]
      @file = File.join @dir, 'test.ruprj'
      @prj = Ruber::Project.new(@file, 'Test')
      @prj[:general, :project_files] = {:extensions => ['*.rb'], :include => [], :exclude => []}
    end
    
    after do
      FileUtils.rm_rf @dir
    end
    
    it 'returns a ProjectFiles object containing all the files in the project' do
      res = @prj.files
      res.should be_a(Ruber::ProjectFiles)
      exp = Dir.entries(@dir).select{|f| f.end_with?('.rb')}.map{|f| File.join @dir, f}
      res.should == Set.new(exp)
    end
    
    it 'takes into account files added after previous calls to this method' do
      @prj.files
      file = File.join @dir, 'f8.rb'
      `touch #{file}`
      @prj.instance_variable_get(:@dir_scanner).instance_eval{emit file_added(file)}
      exp = exp = Dir.entries(@dir).select{|f| f.end_with?('.rb')}.map{|f| File.join @dir, f}
      @prj.files.should == Set.new(exp)
    end
    
    it 'takes into account files removed after previous calls to this method' do
      @prj.files
      file = File.join @dir, 'f1.rb'
      `rm #{file}`
      @prj.instance_variable_get(:@dir_scanner).instance_eval{emit file_removed(file)}
      exp = exp = Dir.entries(@dir).select{|f| f.end_with?('.rb')}.map{|f| File.join @dir, f}
      @prj.files.should == Set.new(exp)
    end
    
    it 'takes into account rule changes after previous calls to this method' do
      @prj.files
      @prj[:general, :project_files] = {:extensions => ['*.xyz'], :include => [], :exclude => []}
      exp = exp = Dir.entries(@dir).select{|f| f.end_with?('.xyz')}.map{|f| File.join @dir, f}
      @prj.files.should == Set.new(exp)
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