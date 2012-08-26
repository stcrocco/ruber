require 'spec/common'

require 'ruber/component_manager'
require 'ruber/plugin'
require 'ruber/plugin_specification'
require 'ruber/config/config'

include FlexMock::ArgumentTypes

describe 'Ruber::ComponentManager#w, when created' do
  
  before do
    @manager = Ruber::ComponentManager.new
  end
  
  it 'should add itself to the list of features' do
    @manager.instance_variable_get(:@features).should == {:components => @manager}
  end
  
  it 'should add itself to the "components" hash, under the :components key' do
    @manager[:components].should equal(@manager)
  end
  
  it 'should have a plugin_description method which returns the plugin description' do
    res = @manager.plugin_description
    res.should be_a(Ruber::PluginSpecification)
    res.name.should == :components
    res.features.should == [:components]
    res.class_obj.should == Ruber::ComponentManager
  end
  
  it 'should have a plugin_name and component_name methods which return :components' do
    @manager.plugin_name.should == :components
    @manager.component_name.should == :components
  end
  
end

describe 'Ruber::ComponentManager#[]' do
  
  it 'should return the entry stored in the @features instance variable with the same name as the argument' do
    man = Ruber::ComponentManager.new
    mk = flexmock('test component')
    man.instance_variable_get(:@components)[:test] = mk
    features = man.instance_variable_get(:@features)
    features[:x] = man
    features[:test] = mk
    features[:y] = mk
    man[:components].should equal(man)
    man[:x].should equal(man)
    man[:test].should equal(mk)
    man[:y].should equal(mk)
  end
  
end

describe 'Ruber::ComponentManager#each_component' do
  
  context 'if the argument is :normal or missing' do
    
    it 'calls the block passing each component in turn, in loading order' do
      man = Ruber::ComponentManager.new
      components = 5.times.map{|i| flexmock(i.to_s, :component_name => i.to_s, :plugin_description => OpenStruct.new({:features => []}))}
      m = flexmock do |mk|
        components.each{|c| mk.should_receive(:test).once.with(c).globally.ordered}
      end
      man.instance_variable_get(:@components).clear
      components.each{|c| man.add c}
      man.each_component(:normal){|i| m.test i}
      m = flexmock do |mk|
        components.each{|c| mk.should_receive(:test).once.with(c).globally.ordered}
      end
      man.each_component{|i| m.test i}
    end
    
  end
  
  context 'if the argument is :reverse' do
    
    it 'should call the block passing each component in turn, in loading order' do
      man = Ruber::ComponentManager.new
      components = 5.times.map{|i| flexmock(i.to_s, :component_name => i.to_s, :plugin_description => OpenStruct.new({:features => []}))}
      m = flexmock do |mk|
        components.reverse_each{|c| mk.should_receive(:test).once.with(c).globally.ordered}
      end
      man.instance_variable_get(:@components).clear
      components.each{|c| man.add c}
      man.each_component(:reverse){|i| m.test i}
    end
  
  end
  
end

describe 'Ruber::ComponentManager#components' do
  
  it 'calls the block passing each component in turn, in reverse loading order' do
    man = Ruber::ComponentManager.new
    components = 5.times.map{|i| flexmock(i.to_s, :component_name => i.to_s, :plugin_description => OpenStruct.new({:features => []}))}
    man.instance_variable_get(:@components).clear
    components.each{|c| man.add c}
    man.components.should == components
  end
  
end

describe 'Ruber::ComponentManager#each_plugin' do
  
  context 'when the argument is :normal or missing' do
    
    it 'calls the block passing each plugin in turn, in loading order' do
      man = Ruber::ComponentManager.new
      components = 5.times.map{|i| flexmock("component #{i}", :component_name => :"#{i}",:plugin_description => OpenStruct.new({:features => []}))}
      m = flexmock("test")
      plugins = [1, 3, 4]
      components.each_with_index do |c, i|
        is_plugin = plugins.include?(i)
        c.should_receive(:is_a?).with(Ruber::Plugin).and_return( is_plugin)
        if is_plugin then m.should_receive(:test).with(c).once.globally.ordered
        else m.should_receive(:test).with(c).never
        end
      end
      components.each{|c| man.add c}
      man.each_plugin(:normal){|i| m.test i}
      components.each_with_index do |c, i|
        is_plugin = plugins.include?(i)
        c.should_receive(:is_a?).with(Ruber::Plugin).and_return( is_plugin)
        if is_plugin then m.should_receive(:test).with(c).once.globally.ordered
        else m.should_receive(:test).with(c).never
        end
      end
      man.each_plugin(:normal){|i| m.test i}
    end
  
  end
  
  context 'when the argument is :reverse' do
    
    it 'should call the block passing each plugin in turn, in reverse loading order' do
      man = Ruber::ComponentManager.new
      components = 5.times.map{|i| flexmock("component #{i}", :component_name => :"#{i}",:plugin_description => OpenStruct.new({:features => []}))}
      m = flexmock("test")
      plugins = [1, 3, 4]
      components.each_with_index do |c, i|
        is_plugin = plugins.include?(i)
        c.should_receive(:is_a?).with(Ruber::Plugin).and_return( is_plugin)
        if is_plugin then m.should_receive(:test).with(c).once.globally.ordered
        else m.should_receive(:test).with(c).never
        end
      end
      components.reverse_each{|c| man.add c}
      man.each_plugin(:reverse){|i| m.test i}
    end

  end
 
end

describe 'Ruber::ComponentManager#plugins' do
  
  it 'should return an array containing all the loading plugins, in loading order' do
    man = Ruber::ComponentManager.new
    components = 5.times.map{|i| flexmock("component #{i}", :component_name => :"#{i}",:plugin_description => OpenStruct.new({:features => []}))}
    m = flexmock("test")
    plugins = [1, 3, 4]
    components.each_with_index do |c, i|
      is_plugin = plugins.include?(i)
      c.should_receive(:is_a?).with(Ruber::Plugin).and_return( is_plugin)
    end
    components.reverse_each{|c| man.add c}
    man.plugins.should == [components[4], components[3], components[1]]
  end
  
end

describe 'Ruber::ComponentManager#add' do
  
  before do
    @manager = Ruber::ComponentManager.new
  end
  
  it 'should add the argument at the end of the component list' do
    plug = flexmock('plugin', :component_name => :test, :plugin_description => OpenStruct.new({:features => []}))
    @manager.add plug
    @manager.instance_variable_get(:@components)[:test].should equal(plug)
    @manager.instance_variable_get(:@components).keys.last.should == :test
  end
  
  it 'should add the argument to the list of features for each of its features' do
    pdf = OpenStruct.new({:features => [:test, :x, :y]})
    plug = flexmock('plugin', :component_name => :test, :plugin_description => pdf)
    @manager.add plug
    @manager.instance_variable_get(:@features).should == {:components => @manager, :test => plug, :x => plug, :y => plug}
  end
  
end

describe 'Ruber::ComponentManager.load_component' do
  
  before(:all) do
    cls = Class.new(Qt::Object) do 
      attr_accessor :plugin_description 
      def initialize manager, pdf
        super()
      end
      
      def setup;end
    end
    Object.const_set(:TestComponent, cls)
  end
  
  before do
    @manager = Ruber::ComponentManager.new
  end
  
  after(:all) do
    Object.send :remove_const, :TestComponent
  end
  
  it 'should add the component directory to KDE::StandardDirs if an instance of the application exists' do
      yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    dir = File.expand_path('lib/ruber/main_window')
    flexmock(KDE::Application).should_receive(:instance).and_return Qt::Object.new
    #needed because resource_dirs return directory names ending in /, while 
    #File.expand_path doesn't
    dir = File.join dir, ''
    file = File.join dir, 'plugin.yaml'
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    @manager.load_component 'main_window'
    KDE::Global.dirs.resource_dirs('pixmap').should include(dir)
    KDE::Global.dirs.resource_dirs('data').should include(dir)
    KDE::Global.dirs.resource_dirs('appdata').should include(dir)
  end
  
  it 'should not add the component directory to KDE::StandardDirs if no instance of the application exist' do
      yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    dir = File.expand_path('lib/ruber/projects')
    flexmock(KDE::Application).should_receive(:instance).and_return nil
    #needed because resource_dirs return directory names ending in /, while 
    #File.expand_path doesn't
    dir = File.join dir, ''
    file = File.join dir, 'plugin.yaml'
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    @manager.load_component 'projects'
    KDE::Global.dirs.resource_dirs('pixmap').should_not include(dir)
    KDE::Global.dirs.resource_dirs('data').should_not include(dir)
    KDE::Global.dirs.resource_dirs('appdata').should_not include(dir)
  end

  
  it 'should read the full PSF from the plugin.yaml file contained in the directory with the same name as the component, in the same directory as the component_manager.rb file' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    pdf = Ruber::PluginSpecification.full YAML.load(yaml)
    flexmock(Ruber::PluginSpecification).should_receive(:full).once.with(file).and_return pdf
    @manager.load_component 'test'
  end
  
  it 'should raise SystemCallError if the file couldn\'t be found' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    lambda{@manager.load_component 'test'}.should raise_error(SystemCallError)
  end
  
  it 'should raise ArgumentError if the file isn\'t a valid YAML file' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
        yaml = <<-EOS
name: {
    EOS
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    lambda{@manager.load_component 'test'}.should raise_error(ArgumentError)
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if the file isn\'t a valid PSF, then re-raise the exception' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    yaml = '{}'
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    lambda{@manager.load_component 'test'}.should raise_error(Ruber::PluginSpecification::PSFError)
  end
  
  it 'should store the component directory in the "directory" attribute of the PSF' do
    dir = File.expand_path 'lib/ruber/test'
    file = File.join dir, 'plugin.yaml'
    yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    flexmock(File).should_receive(:read).with(file).and_return yaml
    pdf = Ruber::PluginSpecification.full(YAML.load(yaml))
    flexmock(Ruber::PluginSpecification).should_receive(:full).with(file).once.and_return pdf
    comp = TestComponent.new(@manager, pdf)
    flexmock(TestComponent).should_receive(:new).once.with(@manager, pdf).and_return(comp)
    @manager.load_component 'test'
  end
  
  it 'should create an instance of the class mentioned in the PSF, passing the component manager and the pdf as argument' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    flexmock(File).should_receive(:read).with(file).and_return yaml
    pdf = Ruber::PluginSpecification.full(YAML.load(yaml))
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    comp = TestComponent.new(@manager, pdf)
    flexmock(TestComponent).should_receive(:new).once.with(@manager, pdf).and_return(comp)
    @manager.load_component 'test'
  end
  
  it 'should not call the load_settings method of the component if no components with name :config exist' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    flexmock(File).should_receive(:read).with(file).and_return yaml
    comp = TestComponent.new @manager, Ruber::PluginSpecification.full(YAML.load(yaml))
    flexmock(TestComponent).should_receive(:new).once.and_return(comp)
    flexmock(comp).should_receive(:send).with(:setup)
    flexmock(comp).should_receive(:send).with(:load_settings).never
    @manager.load_component 'test'
  end
  
  it 'should emit the "component_loaded(QObject*)" signal as the last thing' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    @manager.instance_variable_get(:@components)[:config] = TestComponent.new @manager, OpenStruct.new
    comp = TestComponent.new @manager, Ruber::PluginSpecification.full(YAML.load(yaml))
    def comp.load_settings;end
    flexmock(TestComponent).should_receive(:new).once.globally.ordered.with(@manager, Ruber::PluginSpecification).and_return(comp)
    m = flexmock{|mk| mk.should_receive(:component_added).with(comp).once.globally.ordered}
    @manager.connect(SIGNAL('component_loaded(QObject*)')){|c| m.component_added(c)}
    @manager.load_component 'test'
  end
  
  it 'should return the component' do
    file = File.expand_path 'lib/ruber/test/plugin.yaml'
    yaml = <<-EOS
name: test
class: TestComponent
type: global
    EOS
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    comp = TestComponent.new @manager, Ruber::PluginSpecification.full(YAML.load(yaml))
    flexmock(TestComponent).should_receive(:new).once.with(@manager, Ruber::PluginSpecification).and_return(comp)
    @manager.load_component( 'test').should equal(comp)

  end
  
end

describe 'Ruber::ComponentManager#load_plugin' do
  
    before(:all) do
    cls = Class.new(Qt::Object) do 
      attr_accessor :plugin_description 
      def initialize pdf
        super()
        @plugin_description = pdf
      end
      
      define_method(:setup){}
      define_method(:load_settings){}
      define_method(:delayed_initialize){}
    end
    Object.const_set(:TestPlugin, cls)
  end
  
  before do
    @manager = Ruber::ComponentManager.new
    @dir = File.expand_path "~/test"
    @file = File.join @dir, 'plugin.yaml'
    @yaml = <<-EOS
name: test
class: TestPlugin
type: global
    EOS
    @pdf = Ruber::PluginSpecification.full YAML.load(@yaml)
    flexmock(File).should_receive(:read).with(@file).and_return(@yaml).by_default
  end
  
  after(:all) do
    Object.send :remove_const, :TestPlugin
  end
  
  it 'should add the plugin directory to KDE::StandardDirs' do
    @dir = File.expand_path(File.dirname(__FILE__))
    #needed because resource_dirs return directory names ending in /, while 
    #File.expand_path doesn't
    @dir = File.join @dir, ''
    @file = File.join @dir, 'plugin.yaml'
    flexmock(File).should_receive(:read).with(@file).once.and_return @yaml
    @manager.load_plugin @dir
    KDE::Global.dirs.resource_dirs('pixmap').should include(@dir)
    KDE::Global.dirs.resource_dirs('data').should include(@dir)
    KDE::Global.dirs.resource_dirs('appdata').should include(@dir)
  end
 
  it 'should read the full PSF from the plugin.yaml file contained in the directory passed as argument' do
    flexmock(File).should_receive(:read).with(@file).once.and_return @yaml
    pdf = Ruber::PluginSpecification.full YAML.load(@yaml)
    flexmock(Ruber::PluginSpecification).should_receive(:full).once.with(YAML.load(@yaml), @dir).and_return pdf
    @manager.load_plugin @dir
  end
  
  it 'should raise SystemCallError if the plugin file doesn\'t exist' do
    dir = File.expand_path "~/test"
    file = File.join dir, 'plugin.yaml'
    yaml = <<-EOS
name: test
class: TestPlugin
type: global
    EOS
    flexmock(File).should_receive(:read).once.with(@file).and_raise(SystemCallError.new(0))
    lambda{@manager.load_plugin @dir}.should raise_error(SystemCallError)
  end
  
  it 'should raise ArgumentError if the plugin file isn\'t a valid YAML file' do
    dir = File.expand_path "#{ENV['HOME']}/test"
        yaml = <<-EOS
name: {
    EOS
    file = File.join dir, 'plugin.yaml'
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    lambda{@manager.load_plugin @dir}.should raise_error(ArgumentError)
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if the file isn\'t a valid PSF' do
    dir = File.expand_path "#{ENV['HOME']}/test"
    yaml = '{}'
    file = File.join dir, 'plugin.yaml'
    flexmock(File).should_receive(:read).with(file).once.and_return yaml
    lambda{@manager.load_plugin @dir}.should raise_error(Ruber::PluginSpecification::PSFError)
  end
  
  it 'should create an instance of the class mentioned in the PSF, passing the PluginSpecification object as argument, and return it' do
    pdf = Ruber::PluginSpecification.full(YAML.load(@yaml))
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    plug = TestPlugin.new(pdf)
    flexmock(TestPlugin).should_receive(:new).once.with(pdf).and_return(plug)
    res = @manager.load_plugin @dir
    res.should equal(plug)
  end
  
  it 'should emit the "component_loaded(QObject*)" signal, passing the plugin as argument' do
    pdf = Ruber::PluginSpecification.full(YAML.load(@yaml))
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    plug = TestPlugin.new(pdf)
    flexmock(TestPlugin).should_receive(:new).once.with(pdf).and_return(plug)
    m = flexmock{|mk| mk.should_receive(:component_loaded).once.with(plug)}
    @manager.connect(SIGNAL('component_loaded(QObject*)')){|o| m.component_loaded o}
    @manager.load_plugin @dir
  end
  
  it 'should emit the "feature_loaded(QString, QObject*)" signal for each feature provided by the plugin' do
    pdf = Ruber::PluginSpecification.full(YAML.load(@yaml))
    pdf.features << :x << :y
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    plug = TestPlugin.new(pdf)
    flexmock(TestPlugin).should_receive(:new).once.with(pdf).and_return(plug)
    m = flexmock do |mk| 
      mk.should_receive(:feature_loaded).with('test', plug).once
      mk.should_receive(:feature_loaded).with('x', plug).once
      mk.should_receive(:feature_loaded).with('y', plug).once
    end
    @manager.connect(SIGNAL('feature_loaded(QString, QObject*)')){|s, o| m.feature_loaded s, o}
    @manager.load_plugin @dir
  end
  
  it 'calls the new plugin\'s delayed_initialize method, after emitting the feature_loaded signals' do
    pdf = Ruber::PluginSpecification.full(YAML.load(@yaml))
    pdf.features << :x << :y
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    plug = TestPlugin.new(pdf)
    flexmock(TestPlugin).should_receive(:new).once.with(pdf).and_return(plug)
    m = flexmock do |mk| 
      mk.should_receive(:feature_loaded).with('test', plug).once.ordered(:signals)
      mk.should_receive(:feature_loaded).with('x', plug).once.ordered(:signals)
      mk.should_receive(:feature_loaded).with('y', plug).once.ordered(:signals)
    end
    @manager.connect(SIGNAL('feature_loaded(QString, QObject*)')){|s, o| m.feature_loaded s, o}
    flexmock(plug).should_receive(:delayed_initialize).once.ordered
    @manager.load_plugin @dir
  end
  
  it 'calls the new plugin\'s delayed_initialize method even if it\'s private' do
    pdf = Ruber::PluginSpecification.full(YAML.load(@yaml))
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    plug = TestPlugin.new(pdf)
    flexmock(TestPlugin).should_receive(:new).once.with(pdf).and_return(plug)
    class << plug
      private :delayed_initialize
    end
    flexmock(plug).should_receive(:delayed_initialize).once
    @manager.load_plugin @dir
  end
  
  it 'should create a signal "unloading_*(QObject*)" for each feature provided by the plugin' do
    pdf = Ruber::PluginSpecification.full(YAML.load(@yaml))
    pdf.features << :x << :y
    flexmock(Ruber::PluginSpecification).should_receive(:full).and_return pdf
    plug = TestPlugin.new(pdf)
    flexmock(TestPlugin).should_receive(:new).once.with(pdf).and_return(plug)
    m = flexmock do |mk| 
      mk.should_receive(:unloading_x).with(plug).once
      mk.should_receive(:unloading_y).with(plug).once
      mk.should_receive(:unloading_test).with(plug).once
    end
    @manager.load_plugin @dir
    @manager.connect(SIGNAL('unloading_x(QObject*)')){|o| m.unloading_x o}
    @manager.connect(SIGNAL('unloading_y(QObject*)')){|o| m.unloading_y o}
    @manager.connect(SIGNAL('unloading_test(QObject*)')){|o| m.unloading_test o}
    @manager.instance_eval{emit unloading_x(plug)}
    @manager.instance_eval{emit unloading_y(plug)}
    @manager.instance_eval{emit unloading_test(plug)}
  end
  
end

describe 'Ruber::ComponentManager.sort_plugins' do
  
  it 'should sort the plugins alphabetically if no dependencies exist' do
    pdfs = [
      {:name => :c, :deps => []},
      {:name => :a, :deps => []},
      {:name => :s, :deps => []},
      {:name => :m, :deps => []}
      ].map{|i| OpenStruct.new i}
    res = Ruber::ComponentManager.sort_plugins(pdfs)
    res.map{|i| i.name}.should == [:a, :c, :m, :s]
  end
  
  it 'should return an array sorted according to dependencies' do
    pdfs = [
      {:name => :c, :deps => [:s, :a]},
      {:name => :a, :deps => [:x]},
      {:name => :s, :deps => []},
      {:name => :m, :deps => [:x, :c]},
      {:name => :x, :deps => []}
      ].map{|i| OpenStruct.new i}
    res = Ruber::ComponentManager.sort_plugins(pdfs)
    res.map{|i| i.name}.should == [:s, :x, :a, :c, :m]
  end
  
  it 'should raise Ruber::ComponentManager::UnresolvedDep if a dependency can\'t be resolved' do
    pdfs = [
      {:name => :c, :deps => [:s, :a]},
      {:name => :a, :deps => [:x]},
      {:name => :s, :deps => []},
      {:name => :m, :deps => [:x, :r]},
      {:name => :x, :deps => []},
      {:name => :l, :deps => [:r, :t]}
      ].map{|i| OpenStruct.new i}
    lambda{Ruber::ComponentManager.sort_plugins(pdfs)}.should raise_error(Ruber::ComponentManager::UnresolvedDep){|e| e.missing.should == {:r => [:m, :l], :t => [:l]}}
  end
  
  it 'should raise Ruber::ComponentManager::CircularDep if there are circular dependencies' do
    pdfs = [
      {:name => :c, :deps => [:s, :a]},
      {:name => :a, :deps => [:x]},
      {:name => :s, :deps => []},
      {:name => :x, :deps => [:c]},
      ].map{|i| OpenStruct.new i}
    circ = [[:a, :x], [:x, :c], [:c, :a]]
    lambda{Ruber::ComponentManager.sort_plugins(pdfs)}.should raise_error(Ruber::ComponentManager::CircularDep){|e| circ.should include(e.circular_deps)}
  end
  
  it 'should not count features passed as second argument' do
    pdfs = [
      {:name => :c, :deps => [:s, :a, :b]},
      {:name => :a, :deps => [:x, :l]},
      {:name => :s, :deps => []},
      {:name => :m, :deps => [:x, :c]},
      {:name => :x, :deps => [:l, :b]}
      ].map{|i| OpenStruct.new i}
    res = Ruber::ComponentManager.sort_plugins(pdfs, [:b, :l])
    res.map{|i| i.name}.should == [:s, :x, :a, :c, :m]
  end
  
end

describe 'Ruber::ComponentManager.resolve_features' do
  
  it 'should return an array of pdfs where the dependencies have been changed according to the features provided by the plugins' do
    pdfs = [
      {:name => :c, :deps => [:s, :a, :d], :features => [:c]},
      {:name => :a, :deps => [:x, :r], :features => [:a]},
      {:name => :s, :deps => [], :features => [:s, :r]},
      {:name => :m, :deps => [:x, :c, :d], :features => [:m]},
      {:name => :x, :deps => [], :features => [:x, :d]}
    ].map{|i| OpenStruct.new i}
    res = Ruber::ComponentManager.resolve_features pdfs
    res[0].deps.should =~ [:s, :a, :x]
    res[1].deps.should =~ [:x, :s]
    res[2].deps.should == []
    res[3].deps.should =~ [:x, :c]
    res[4].deps.should == []
  end
  
  it 'should raise Ruber::ComponentManager::UnresolvedDep if some features can\'t be found' do
    pdfs = [
      {:name => :c, :deps => [:s, :a, :d, :y], :features => [:c]},
      {:name => :a, :deps => [:x, :r], :features => [:a]},
      {:name => :s, :deps => [], :features => [:s, :r]},
      {:name => :m, :deps => [:x, :c, :d, :z, :y], :features => [:m]},
      {:name => :x, :deps => [], :features => [:x, :d]}
    ].map{|i| OpenStruct.new i}
    lambda{Ruber::ComponentManager.resolve_features pdfs}.should raise_error(Ruber::ComponentManager::UnresolvedDep){|e| e.missing.should == {:c => [:y], :m => [:z, :y]}}
  end
  
  it 'should also take into account pdfs passed as second argument in the resolution' do
    pdfs = [
      {:name => :c, :deps => [:s, :a, :d, :y, :k], :features => [:c]},
      {:name => :a, :deps => [:x, :r], :features => [:a]},
      {:name => :s, :deps => [], :features => [:s, :r]},
      {:name => :m, :deps => [:x, :c, :d, :z, :y], :features => [:m]},
      {:name => :x, :deps => [], :features => [:x, :d]}
    ].map{|i| OpenStruct.new i}
    extra = [
      {:name => :A, :features => [:A, :z]},
      {:name => :B, :features => [:B, :y, :k]}
    ].map{|i| OpenStruct.new i}
    res = Ruber::ComponentManager.resolve_features pdfs, extra
    res[0].deps.should =~ [:s, :a, :x, :B]
    res[1].deps.should =~ [:x, :s]
    res[2].deps.should == []
    res[3].deps.should =~ [:x, :c, :A, :B]
    res[4].deps.should == []
  end
  
  it 'should not modifiy the pdfs passed as argument' do
    pdfs = [
      {:name => :c, :deps => [:s, :a, :d], :features => [:c]},
      {:name => :a, :deps => [:x, :r], :features => [:a]},
      {:name => :s, :deps => [], :features => [:s, :r]},
      {:name => :m, :deps => [:x, :c, :d], :features => [:m]},
      {:name => :x, :deps => [], :features => [:x, :d]}
    ].map{|i| OpenStruct.new i}
    res = Ruber::ComponentManager.resolve_features pdfs
    res.each_with_index{|pl, i| pl.should_not equal(pdfs[i])}
  end
  
end

describe 'Ruber::ComponentManager#load_plugins' do
  
  before do
    @manager = Ruber::ComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(Qt::Object.new).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    @data = %q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p1, plugin.yaml]]]}
    @tree = YAML.load @data
    @dir = nil
    Object.const_set :P1, Class.new(Ruber::Plugin)
    Object.const_set :P2, Class.new(Ruber::Plugin)
    Object.const_set :P3, Class.new(Ruber::Plugin)
  end
  
  after do
    FileUtils.rm_r @dir if @dir
    Object.send :remove_const, :P1
    Object.send :remove_const, :P2
    Object.send :remove_const, :P3
  end
   
  it 'should find the plugins in the given directories and load them in the alphabetically order if there aren\'t dependencies among them' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
      }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins(%w[p2 p1 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
    @manager.plugins.map{|i| i.class}.should == [P1, P2, P3]
  end
  
  it 'should work with both strings and symbols' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins([:p2, :p1, :p3], %w[d1 d2].map{|d| File.join(@dir, d)})
    @manager.plugins.map{|i| i.class}.should == [P1, P2, P3]
    
  end
  
  it 'should find the plugins in the given directories and load them in dependecy order' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p3, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, type: global}'
      }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
    @manager.plugins.map{|i| i.class}.should == [P2, P3, P1]
  end
  
  it 'should resolve dependencies among the plugins' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p4, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, features: [:p4], type: global}'
      }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
    @manager.plugins.map{|i| i.class}.should == [P2, P3, P1]
  end
  
  it 'should load the plugins using the pdfs with the unresolved dependencies' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p4, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, features: [:p4], type: global}'
      }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
    @manager[:p1].plugin_description.deps.should == [:p4]
  end
  
  it 'should use the already-loaded plugins, if any, to compute dependencies' do
    Object.const_set :P4, Class.new(Ruber::Plugin)
    Object.const_set :P5, Class.new(Ruber::Plugin)
    loaded =  [{:name => :p4, :class => P4, :type => :global}, {:name => :p5, :class => P5, :features => [:p6], :type => :global}].map{|i| Ruber::PluginSpecification.full i}
    P4.new loaded[0]
    P5.new loaded[1]
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p4, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, deps: p6, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
    lambda{@manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})}.should_not raise_error
  end
  
  it 'should raise Ruber::ComponentManager::MissingPlugins if some plugins couldn\'t be found' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    lambda{@manager.load_plugins(%w[p1 p2 p3 p4 p5], %w[d1 d2].map{|d| File.join(@dir, d)})}.should raise_error(Ruber::ComponentManager::MissingPlugins) do |e|
      e.missing.should =~ ['p4', 'p5']
    end
  end
  
  it 'should raise Ruber::ComponentManager::InvalidPSF if the PSF for some plugins was invalid' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, type: global, class: P1',
      'd1/p2/plugin.yaml' => '{class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    lambda{@manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})}.should raise_error(Ruber::ComponentManager::InvalidPSF) do |e|
      e.files.should =~ %w[d1/p1/plugin.yaml d1/p2/plugin.yaml].map{|f| File.join @dir, f}
    end
  end
  
  it 'should raise an exception if loading a plugin raises an exception and no block is given' do
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: X1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    lambda{@manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})}.should raise_error(NameError)
  end
  
  it 'should call the block if an exception occurs while loading a plugin and return false as soon as the block returns false' do
    P1.class_eval{def initialize pdf; raise NoMethodError;end}
    P3.class_eval{def initialize pdf; raise ArgumentError;end}
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    m = flexmock do |mk|
      mk.should_receive(:test).with(Ruber::PluginSpecification, NoMethodError).once.and_return(true)
      mk.should_receive(:test).with(Ruber::PluginSpecification, ArgumentError).once.and_return(false)
    end
    (@manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)}){|pl, e|m.test pl, e}).should be_false
  end
  
  it 'should call the block if an exception occurs while loading a plugin and stop loading plugins and return true if the block returns :skip' do
    P1.class_eval{def initialize pdf; raise NoMethodError;end}
    P2.class_eval{def initialize pdf; raise ArgumentError;end}
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    m = flexmock do |mk|
      mk.should_receive(:test).with(Ruber::PluginSpecification, NoMethodError).once.and_return(true)
      mk.should_receive(:test).with(Ruber::PluginSpecification, ArgumentError).once.and_return(:skip)
    end
    flexmock(P3).should_receive(:new).never
    (@manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)}){|pl, e|m.test pl, e}).should be_true
  end
  
  it 'should call the block if an exception occurs while loading a plugin, stop calling it for following errors and return true if the block returns :silent' do
    P1.class_eval{def initialize pdf; raise NoMethodError;end}
    P2.class_eval{def initialize pdf; raise ArgumentError;end}
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
    }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    m = flexmock do |mk|
      mk.should_receive(:test).with(Ruber::PluginSpecification, NoMethodError).once.and_return(:silent)
      mk.should_receive(:test).with(Ruber::PluginSpecification, ArgumentError).never
    end
    (@manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)}){|pl, e|m.test pl, e}).should be_true
    @manager.plugins.last.should be_a(P3)
  end
  
  it 'should return true if no error occurs' do
        contents = {
      'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
      'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
      }
    @dir = make_dir_tree(@tree, '/tmp/', contents)
    @manager.load_plugins(%w[p2 p1 p3], %w[d1 d2].map{|d| File.join(@dir, d)}).should be_true
  end
  
end

describe 'Ruber::ComponentManager#shutdown' do
  
  before do
#     @cls = Class.new(Qt::Object) do
#       include Ruber::PluginLike
#       def initialize pdf
#         super Ruber[:app]
#         initialize_plugin pdf
#       end
# #       def connect *args
# #       end
#       
#       def is_a? cls
#         true
#       end
#     end
    @manager = Ruber::ComponentManager.new
    
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(Qt::Object.new).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    @config = Qt::Object.new
    flexmock(@config).should_receive(:save_settings).by_default
    flexmock(@config).should_receive(:write).by_default
    flexmock(@config).should_receive(:shutdown).by_default
    @manager.instance_variable_get(:@components)[:config] = @config
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
  end
  
  it 'should call the "save_settings" method of each plugin, except for itself' do
    comps = @manager.instance_variable_get(:@components)
    components = 5.times.map{|i| Ruber::Plugin.new(Ruber::PluginSpecification.full({:name => "c#{i}", :type => :core}))}
    components.reverse_each{|o| flexmock(o).should_receive(:save_settings).once.globally.ordered}
    flexmock(@manager).should_receive(:save_settings).never
    @manager.shutdown
  end
  
  it 'calls the write method of the config object after the plugins\' save_settings method' do
    comps = @manager.instance_variable_get(:@components)
    components = 5.times.map{|i| Ruber::Plugin.new(Ruber::PluginSpecification.full({:name => "c#{i}", :type => :global}))}
    components.each{|o| flexmock(o).should_receive(:save_settings).once.ordered('components')}
    flexmock(@config).should_receive(:write).once.ordered
    @manager.shutdown
  end
  
#   it 'should emit the "unloading_*(QObject*)" for features provided by plugins' do
#     comps = @manager.instance_variable_get(:@components)
#     features = @manager.instance_variable_get(:@features)
#     plugin_pdfs = [
#       {:name => :p1, :features => [:x]},
#       {:name => :p2, :features => [:y, :z]}
#       ].map{|i| Ruber::PluginSpecification.full(i)}
#     component_pdfs = [ {:name => :c1}, {:name => :c2} ].map{|i| Ruber::PluginSpecification.full(i)}
#     components = component_pdfs.map do |c| 
#       comp = Ruber::Plugin.new c
#       flexmock(comp).should_receive(:is_a?).with(Ruber::Plugin).and_return false
#       comp
#     end
#     plugins = plugin_pdfs.map{|pl| Ruber::Plugin.new pl}
#     (components + plugins).reverse_each{|i| flexmock(i).should_receive(:shutdown).once.globally.ordered}
#     plugins.reverse_each{|pl| flexmock(pl).should_receive( :delete_later ).globally.ordered}
#     @manager.class.class_eval do
#       signals( *%w[p1 x p2 y z].map{|s| "unloading_#{s}(QObject*)"})
#     end
#     m = flexmock do |mk|
#       %w[x y z].each do |x| 
#         mk.should_receive("unloading_#{x}".to_sym).once.with(features[x.to_sym])
#         @manager.connect(SIGNAL("unloading_#{x}(QObject*)")){|o| mk.send("unloading_#{x}", o)}
#       end
#     end
#     @manager.shutdown
#   end
#   
#   it 'should emit the "unloading_component(QObject*)" signal for each component except itself, in reverse loading order' do
#     comps = @manager.instance_variable_get(:@components)
#     components = 5.times.map do |i| 
#       flexmock(@manager).should_receive("unloading_c#{i}")
#       Ruber::Plugin.new(Ruber::PluginSpecification.full({:name => "c#{i}"}))
#     end
#     m = flexmock do |mk|
#       components.reverse_each{|c| mk.should_receive(:test).with(c).once.globally.ordered}
#       mk.should_receive(:test).once.with(@config)
#     end
#     @manager.connect( SIGNAL('unloading_component(QObject*)')){|o| m.test o}
#     @manager.shutdown
#   end
#   
  it 'should call the "shutdown" methods of all the components, except itself, in reverse loading order' do
    comps = @manager.instance_variable_get(:@components)
    components = 5.times.map do |i| 
      flexmock(@manager).should_receive("unloading_c#{i}")
      Ruber::Plugin.new(Ruber::PluginSpecification.full({:name => "c#{i}", :type => :global}))
    end
    components.reverse_each{|o| flexmock(o).should_receive(:shutdown).once.globally.ordered}
    @manager.shutdown
  end
#   
#   it 'should call the "delete_later" method of all plugins, after having call the "shutdown" methods' do
#     cls = Class.new(Qt::Object) do
#       include Ruber::PluginLike
#       def initialize pdf
#         super Ruber[:app]
#         initialize_plugin pdf
#       end
#       
#       def is_a? cls
#         false
#       end
#     end
#     
#     components = 3.times.map{|i| cls.new(Ruber::PluginSpecification.full({:name => "c#{i}"}))}
#     plugins=3.times.map{|i| Ruber::Plugin.new(Ruber::PluginSpecification.full({:name => "p#{i}"}))}
#     (components + plugins).reverse_each{|i| flexmock(i).should_receive(:shutdown).once.globally.ordered}
#     plugins.reverse_each{|pl| flexmock(pl).should_receive( :delete_later ).globally.ordered}
#     @manager.class.class_eval do
#       signals( *%w[p0 p1 p2].map{|s| "unloading_#{s}(QObject*)"})
#     end
#     @manager.shutdown
#   end
#   
#   it 'should remove all plugins from the list of components' do
#     cls = Class.new(Qt::Object) do
#       include Ruber::PluginLike
#       def initialize pdf
#         super Ruber[:app]
#         initialize_plugin pdf
#       end
#       
#       def is_a? cls
#         false
#       end
#     end
#     
#     components = 3.times.map{|i| cls.new(Ruber::PluginSpecification.full({:name => "c#{i}"}))}
#     components.unshift @config
#     plugins=3.times.map{|i| Ruber::Plugin.new(Ruber::PluginSpecification.full({:name => "p#{i}"}))}
#     comps = @manager.instance_variable_get(:@components)
#     (components + plugins).reverse_each{|i| flexmock(i).should_receive(:shutdown).once.globally.ordered}
#     plugins.reverse_each{|pl| flexmock(pl).should_receive( :delete_later ).globally.ordered}
#     @manager.class.class_eval do
#       signals( *%w[p0 p1 p2].map{|s| "unloading_#{s}(QObject*)"})
#     end
#     @manager.shutdown
#     @manager.instance_variable_get(:@components).values.sort_by{|o| o.object_id}.should == ([@manager] + components).sort_by{|o| o.object_id}
#   end
#   
#   it 'should remove all features provided by plugins' do
#     plugin_pdfs = [
#       {:name => :p0},
#       {:name => :p1, :features => [:x, :y]},
#       {:name => :p2, :features => [:w, :z]}
#       ].map{|i| Ruber::PluginSpecification.full(i)}
#     component_pdfs = [
#       {:name => :c0, :features => [:a, :b]},
#       {:name => :c1, :features => [:c]}
#       ].map{|i| Ruber::PluginSpecification.full(i)}
#     cls = Class.new(Qt::Object) do
#       include Ruber::PluginLike
#       def initialize pdf
#         super Ruber[:app]
#         initialize_plugin pdf
#       end
#       
#       def is_a? cls
#         false
#       end
#     end
#     components = component_pdfs.map{|i| cls.new(i)}
#     plugins = plugin_pdfs.map{|i| Ruber::Plugin.new(i)}
#     (components + plugins).reverse_each{|i| flexmock(i).should_receive(:shutdown).once.globally.ordered}
#     plugins.reverse_each{|pl| flexmock(pl).should_receive( :delete_later ).globally.ordered}
#     @manager.class.class_eval do
#       signals( *%w[p0 p1 p2 x y w z].map{|s| "unloading_#{s}(QObject*)"})
#     end
#     @manager.shutdown
#     @manager.instance_variable_get(:@features).should == {:components => @manager, :c0 => components[0], :a => components[0], :b => components[0], :c1 => components[1], :c => components[1]}
#   end
  
end

describe 'Ruber::ComponentManager#unload_plugin' do

  before do
    @cls = Class.new(Qt::Object) do
      include Ruber::PluginLike
      def initialize pdf
        super Ruber[:app]
        initialize_plugin pdf
      end
      def is_a? cls
        false
      end
    end
    @manager = Ruber::ComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(Qt::Object.new).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    
    plugin_pdfs = [
      {:name => :p0, :type => :global},
      {:name => :p1, :features => [:x, :y], :type => :global},
      {:name => :p2, :features => [:w, :z], :type => :global}
      ].map{|i| Ruber::PluginSpecification.full(i)}
    component_pdfs = [
      {:name => :c0, :features => [:a, :b], :type => :core},
      {:name => :c1, :features => [:c], :type => :core}
      ].map{|i| Ruber::PluginSpecification.full(i)}
    @components = component_pdfs.map{|i| @cls.new(i)}
    @plugins = plugin_pdfs.map{|i| Ruber::Plugin.new(i)}
    @manager.class.class_eval do
      signals( *%w[p0 p1 p2 x y w z].map{|s| "unloading_#{s}(QObject*)"})
    end

  end
  
  it 'should emit the "unloading_*(QObject*)" signal for each feature provided by the plugin' do
    m = flexmock do |mk| 
      mk.should_receive(:unloading_p1).once.with(@plugins[1])
      mk.should_receive(:unloading_x).once.with(@plugins[1])
      mk.should_receive(:unloading_y).once.with(@plugins[1])
    end
    @manager.class.class_eval do
      signals( *%w[p0 p1 p2 x y w z].map{|s| "unloading_#{s}(QObject*)"})
    end
    %w[p1 x y].each{|f| @manager.connect(SIGNAL("unloading_#{f}(QObject*)")){|o| m.send("unloading_#{f}", o)}}
    @manager.unload_plugin :p1
  end
  
  it 'should emit the "unloading_component(QObject*) signal passing the plugin as argument' do
    m = flexmock{|mk| mk.should_receive(:unloading_component).once.with(@plugins[1])}
    @manager.connect(SIGNAL("unloading_component(QObject*)")){|o| m.unloading_component o}
    @manager.unload_plugin :p1
  end
  
  it 'should call the "unload" method of the plugin after emitting the unloading_component signal' do
    m = flexmock{|mk| mk.should_receive(:unloading_component).once.with(@plugins[1]).globally.ordered}
    @manager.connect(SIGNAL("unloading_component(QObject*)")){|o| m.unloading_component o}
    flexmock(@plugins[1]).should_receive(:unload).once.globally.ordered
    @manager.unload_plugin :p1
  end
  
  it 'should call the "delete_later" method of the plugin after calling shutdown' do
    flexmock(@plugins[1]).should_receive(:shutdown).once.globally.ordered
    flexmock(@plugins[1]).should_receive(:delete_later).once.globally.ordered
    @manager.unload_plugin :p1
  end
  
  it 'should remove the plugin from the list of components and its features from the list of features' do
    @manager.unload_plugin :p1
    @manager.instance_variable_get(:@features).keys.should =~ [:p0, :p2, :w, :z, :c0, :a, :b, :c1, :c, :components]
    @manager.instance_variable_get(:@components).keys.map(&:to_s).should =~ [:p0, :p2, :c0, :c1, :components].map(&:to_s)
  end
  
  it 'raises ArgumentError if there\'s no plugin with that name' do
    lambda{@manager.unload_plugin(:xyz)}.should raise_error(ArgumentError, "No plugin with name xyz")
  end
  
  it 'should raise ArgumentError if the name corresponds to a component instead of a plugin' do
    lambda{@manager.unload_plugin(:c1)}.should raise_error(ArgumentError, "A component can't be unloaded")
  end
  
end

describe 'Ruber::ComponentManager#query_close' do
  
  before do
    @manager = Ruber::ComponentManager.new
  end
  
  it 'should call the query_close method of every component, except itself' do
    h = @manager.instance_variable_get(:@components)
    5.times do |i|
      mk = flexmock(:name => :"c#{i}"){|m| m.should_receive(:query_close).once.and_return true}
      h << [mk.name, mk]
    end
    @manager.query_close
  end
  
  it 'should return false as soon as one of the components\' query_close method returns false' do
    h = @manager.instance_variable_get(:@components)
    5.times do |i|
      mk = flexmock("c#{i}", :name => "c#{i}")
      if i > 2 then mk.should_receive(:query_close).once.and_return true
      elsif i == 2 then mk.should_receive(:query_close).once.and_return false
      else mk.should_receive(:query_close).never
      end
      h << [mk.name, mk]
    end
    @manager.query_close.should be_false
  end
  
  it 'should return true if all components\' query_close methods return true' do
    h = @manager.instance_variable_get(:@components)
    5.times do |i|
      mk = flexmock(:name => :"c#{i}"){|m| m.should_receive(:query_close).once.and_return true}
      h << [mk.name, mk]
    end
    @manager.query_close.should be_true
  end
  
end

describe Ruber::ComponentManager do
  
  before do
    @manager = Ruber::ComponentManager.new
  end
  
  describe '#session_data' do
    
    it 'calls the session_data of each other component' do
      h = @manager.instance_variable_get(:@components)
      5.times do |i|
        mk = flexmock(:name => i.to_s){|m| m.should_receive(:session_data).once.with_no_args.and_return({})}
        h << [mk.name, mk]
      end
      @manager.session_data
    end
    
    it 'returns a hash obtained by merging the hashes returned by each components\' session_data method' do
      h = @manager.instance_variable_get(:@components)
      5.times do |i|
        mk = flexmock(:name => i.to_s){|m| m.should_receive(:session_data).once.and_return({i.to_s => i})}
        h << [mk.name, mk]
      end
      res = @manager.session_data
      res.should == {'0' => 0, '1' => 1, '2' => 2, '3' => 3, '4' => 4}
    end
    
  end
  
  describe '#restore_session' do
    
    it 'calls the restore_session of each other component passing it the argument' do
      cfg = KDE::ConfigGroup.new
      h = @manager.instance_variable_get(:@components)
      5.times do |i|
        mk = flexmock(:name => i.to_s){|m| m.should_receive(:restore_session).once.with(cfg)}
        h << [mk.name, mk]
      end
      @manager.restore_session cfg
    end
    
  end

  
end

# describe 'Ruber::ComponentManager.find_plugins' do
#   
#   before do
#     @manager = Ruber::ComponentManager.new
#   end
#   
#   it 'should return a hash containing the full path of the plugin directories in the given directories as values and the plugin names as keys, if the second argument is false' do
#     dir = make_dir_tree YAML.load(%q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p4, plugin.yaml]]]})
#     exp = {:p1 => 'd1/p1', :p2 => 'd1/p2', :p3 => 'd2/p3', :p4 => 'd2/p4'}.map{|p, d| [p, File.join(dir, d)]}.to_h
#     dirs = %w[d1 d2].map{|d| File.join dir, d}
#     Ruber::ComponentManager.find_plugins(dirs).should == exp
#     Ruber::ComponentManager.find_plugins(dirs, false).should == exp
#     FileUtils.rm_r dir
#   end
#   
#   it 'should return a hash containing the names of the plugins (as symbols) as keys and the corresponding PluginSpecification (with the directory set to the plugin file) as values' do
#     contents = {
#       'd1/p1/plugin.yaml' => '{name: p1, type: global }',
#       'd1/p2/plugin.yaml' => '{name: p2, type: global}',
#       'd2/p3/plugin.yaml' => '{name: p3, type: global}',
#       'd2/p4/plugin.yaml' => '{name: p4, type: global}',
#     }
#     dir = make_dir_tree YAML.load(%q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p4, plugin.yaml]]]}), '/tmp', contents
#     exp = %w[d1/p1 d1/p2 d2/p3 d2/p4].map do |d| 
#       pdf = File.join d, 'plugin.yaml'
#       data = YAML.load contents[pdf]
#       [File.basename(d).to_sym, Ruber::PluginSpecification.intro(data)]
#     end.to_h
#     dirs = %w[d1 d2].map{|d| File.join dir, d}
#     res = Ruber::ComponentManager.find_plugins(dirs, true)
#     res.should == exp
#     res[:p1].directory.should == File.join(dirs[0], 'p1')
#     res[:p2].directory.should == File.join(dirs[0], 'p2')
#     res[:p3].directory.should == File.join(dirs[1], 'p3')
#     res[:p4].directory.should == File.join(dirs[1], 'p4')
#     FileUtils.rm_r dir
#   end
#   
#   it 'should return only the file in the earliest directory, if more than one directory contain the same plugin' do
#     dir = make_dir_tree YAML.load(%q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p1, plugin.yaml]]]})
#     exp = {:p1 => 'd1/p1', :p2 => 'd1/p2', :p3 => 'd2/p3'}.map{|p, d| [p, File.join(dir, d)]}.to_h
#     dirs = %w[d1 d2].map{|d| File.join dir, d}
#     Ruber::ComponentManager.find_plugins(dirs).should == exp
#     Ruber::ComponentManager.find_plugins(dirs, false).should == exp
#     FileUtils.rm_r dir
#         contents = {
#       'd1/p1/plugin.yaml' => '{name: p1, type: global}',
#       'd1/p2/plugin.yaml' => '{name: p2, type: global}',
#       'd2/p3/plugin.yaml' => '{name: p3, type: global}',
#       'd2/p1/plugin.yaml' => '{name: p1, type: global}',
#     }
#     dir = make_dir_tree YAML.load(%q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p1, plugin.yaml]]]}), '/tmp', contents
#     exp = %w[d1/p1 d1/p2 d2/p3].map do |d| 
#       pdf = File.join d, 'plugin.yaml'
#       data = YAML.load contents[pdf]
#       [File.basename(d).to_sym, Ruber::PluginSpecification.intro(data)]
#     end.to_h
#     dirs = %w[d1 d2].map{|d| File.join dir, d}
#     Ruber::ComponentManager.find_plugins(dirs, true).should == exp
#     FileUtils.rm_r dir
#   end
#   
# end

describe 'Ruber::ComponentManager.fill_dependencies' do
  
  it 'should return an empty array if plugins passed as first argument only don\'t have dependencies' do
    pdfs = [{:name => :p1, :type => :global}, {:name => :p2, :type => :global}, {:name => :p3 , :type => :global}, {:name => :p4, :type => :global}].map{|pl| Ruber::PluginSpecification.intro(pl)}
    Ruber::ComponentManager.fill_dependencies(pdfs[0..1], pdfs).should == []
  end
  
  it 'should return an empty array if the plugins passed as first argument only depend on features having the names of other of those plugins' do
    pdfs = [{:name => :p1, :deps => :p2, :type => :global}, {:name => :p2, :deps => :p3, :type => :global}, {:name => :p3, :type => :global}, {:name => :p4, :type => :global}].map{|pl| Ruber::PluginSpecification.intro(pl)}
    Ruber::ComponentManager.fill_dependencies(pdfs[0..2], pdfs).should == []
  end
  
  it 'should return an emtpy arra if the plugins passed as first argument only depend on features provided by of other plugins in the first argument' do
    pdfs = [{:name => :p1, :deps => :f2, :type => :global}, {:name => :p2, :deps => :f3, :features => :f2, :type => :global}, {:name => :p3, :features => [:f3, :f5], :type => :global}, {:name => :p4, :type => :global}].map{|pl| Ruber::PluginSpecification.intro(pl)}
    Ruber::ComponentManager.fill_dependencies(pdfs[0..2], pdfs).should == []
  end
  
  it 'should return an array containing the names of the plugins in the second argument whose name matches dependencies in the first argument not satisfied otherwise' do
    pdfs = [{:name => :p1, :deps => [:f2, :p4], :type => :global}, {:name => :p2, :deps => :p3, :features => :f2, :type => :global}, {:name => :p3, :type => :global}, {:name => :p4, :type => :global}, {:name => :p5, :type => :global}].map{|pl| Ruber::PluginSpecification.intro(pl)}
    Ruber::ComponentManager.fill_dependencies(pdfs[0..1], pdfs).map{|i| i.to_s}.should =~ [:p3, :p4].map{|i| i.to_s}
  end
  
  it 'should return an array containing the dependencies\' dependencies, if any' do
    pdfs = [
      {:name => :p1, :deps => [:f2, :p4], :type => :global},
      {:name => :p2, :deps => :p3, :features => :f2, :type => :global},
      {:name => :p3, :deps => :p6, :type => :global},
      {:name => :p4, :deps => :p5, :type => :global},
      {:name => :p5, :type => :global},
      {:name => :p6, :type => :global}
    ]
    pdfs.map!{|pl| Ruber::PluginSpecification.intro(pl)}
    Ruber::ComponentManager.fill_dependencies(pdfs[0..1], pdfs).map{|i| i.to_s}.should =~ [:p3, :p4, :p5, :p6].map{|i| i.to_s}
  end
  
  it 'should not add a plugin with the same name of a feature as a dependecy if another plugin already provides that feature' do
    pdfs = [
      {:name => :p1, :deps => [:f2, :p4], :type => :global},
      {:name => :p2, :deps => :p3, :features => :f2, :type => :global},
      {:name => :p3, :deps => :p6, :features => :p5, :type => :global},
      {:name => :p4, :deps => :p5, :type => :global},
      {:name => :p5, :deps => :p7, :type => :global},
      {:name => :p6, :type => :global},
      {:name => :p7, :type => :global}
    ]
    pdfs.map!{|pl| Ruber::PluginSpecification.intro(pl)}
    Ruber::ComponentManager.fill_dependencies(pdfs[0..1], pdfs).map{|i| i.to_s}.should =~ [:p3, :p4, :p6].map{|i| i.to_s}
  end
  
  it 'should raise UnresolvedDep if some dependencies can\'t be resolved' do
    pdfs = [
      {:name => :p1, :deps => [:f2, :p4, :p7], :type => :global},
      {:name => :p2, :deps => :p3, :features => :f2, :type => :global},
      {:name => :p3, :deps => :p6, :features => :p5, :type => :global},
      {:name => :p4, :deps => :p5, :type => :global},
      {:name => :p5, :deps => :p7, :type => :global},
    ]
    pdfs.map!{|pl| Ruber::PluginSpecification.intro(pl)}
    lambda{Ruber::ComponentManager.fill_dependencies(pdfs[0..1], pdfs)}.should raise_error(Ruber::ComponentManager::UnresolvedDep) do |e|
      e.missing.should == {:p7 => [:p1], :p6 => [:p3]}
    end
  end
  
end