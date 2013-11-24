require 'spec/common'
require 'ruber/component_loader'
require 'tempfile'

describe Ruber::ComponentLoader do
  
  before :all do
    @loader_cls = Class.new{include Ruber::ComponentLoader}
  end
  
  before do
    @loader = @loader_cls.new
  end
  
  after do
    FileUtils.rm_rf @dir if @dir
  end

  describe '#find_plugins' do
    
    before do
      tree = [
        ['d1', ['p1', 'plugin.yaml'], ['p2', 'plugin.yaml']],
        ['d2', ['p3', 'plugin.yaml'], ['p4', 'plugin.yaml']]
      ]
      contents = {
        'd1/p1/plugin.yaml' => '{name: p1, type: global }',
        'd1/p2/plugin.yaml' => '{name: p2, type: global}',
        'd2/p3/plugin.yaml' => '{name: p3, type: global}',
        'd2/p4/plugin.yaml' => '{name: p4, type: global}',
      }
      @dir = make_dir_tree tree, '/tmp', contents
      @dirs = %w[d1 d2].map{|d| File.join @dir, d}
      exp = {:p1 => 'd1/p1', :p2 => 'd1/p2', :p3 => 'd2/p3', :p4 => 'd2/p4'}
      @exp = exp.map{|p, d| [p, File.join(@dir, d, 'plugin.yaml')]}.to_h
    end
    
    context 'when the second argument is false' do
      
      it 'returns a hash containing the full path of the plugin files as values and the plugin names as keys' do
        @loader.find_plugins(@dirs).should == @exp
        @loader.find_plugins(@dirs, false).should == @exp
      end
      
    end
    
    context 'when the second argument is true' do
      
      before do
        @exp.each_key do |k|
          data = YAML.load File.read(@exp[k])
          @exp[k] = Ruber::PluginSpecification.intro(data)
        end
      end
      
      it 'returns a hash containing the names of the plugins (as symbols) as keys and the corresponding PluginSpecification (with the directory set to the plugin file) as values' do
        res = @loader.find_plugins(@dirs, true)
        res.should == @exp
        res[:p1].directory.should == File.join(@dirs[0], 'p1')
        res[:p2].directory.should == File.join(@dirs[0], 'p2')
        res[:p3].directory.should == File.join(@dirs[1], 'p3')
        res[:p4].directory.should == File.join(@dirs[1], 'p4')
        FileUtils.rm_r @dir
      end
      
      it 'doesn\'t return full plugin specifications' do
        res = @loader.find_plugins(@dirs, true)
        res.each_value{|psf| psf.should be_intro_only}
      end
      
    end
        
    it 'should return only the file in the earliest directory, if more than one directory contain the same plugin' do
      dir = File.join @dirs[0], 'p3'
      FileUtils.mkdir dir
      file = File.join dir, 'plugin.yaml'
      File.open(file, 'w'){|f| f.write('{name: p3, type: global }')}
      @loader.find_plugins(@dirs)[:p3].should == file
      @loader.find_plugins(@dirs, true)[:p3].directory.should == dir
    end
    
  end
  
  describe '#resolve_features' do
    
    before do
      @psfs = [
        {:name => :c, :deps => [:s, :a, :d], :features => [:c]},
        {:name => :a, :deps => [:x, :r], :features => [:a]},
        {:name => :s, :deps => [], :features => [:s, :r]},
        {:name => :m, :deps => [:x, :c, :d], :features => [:m]},
        {:name => :x, :deps => [], :features => [:x, :d]}
      ].map{|i| OpenStruct.new i}
    end
    
    it 'returns an array of psfs where the dependencies have been changed according to the features provided by the plugins' do
      res = @loader.resolve_features @psfs
      res[0].deps.should =~ [:s, :a, :x]
      res[1].deps.should =~ [:x, :s]
      res[2].deps.should == []
      res[3].deps.should =~ [:x, :c]
      res[4].deps.should == []
    end
    
    it 'raises Ruber::ComponentLoader::UnresolvedDep if some features can\'t be found' do
      @psfs[0].deps << :y
      @psfs[3].deps += [:z, :y]
      lambda{@loader.resolve_features @psfs}.should raise_error(Ruber::UnresolvedDep){|e| e.missing.should == {:c => [:y], :m => [:z, :y]}}
    end
    
    it 'also searches the psfs passed as second argument' do
      @psfs[0].deps += [:y, :k]
      @psfs[3].deps += [:z, :y]
      extra = [
        {:name => :A, :features => [:A, :z]},
        {:name => :B, :features => [:B, :y, :k]}
      ].map{|i| OpenStruct.new i}
      res = @loader.resolve_features @psfs, extra
      res[0].deps.should =~ [:s, :a, :x, :B]
      res[1].deps.should =~ [:x, :s]
      res[2].deps.should == []
      res[3].deps.should =~ [:x, :c, :A, :B]
      res[4].deps.should == []
    end
    
    it 'doesn\' change the psfs passed as argument' do
      res = @loader.resolve_features @psfs
      res.each_with_index{|pl, i| pl.should_not equal(@psfs[i])}
    end
    
  end
  
  describe '#fill_dependencies' do
    
    before do
      psfs = [
        {:name => :p1, :type => :global},
        {:name => :p2, :type => :global},
        {:name => :p3 , :type => :global},
        {:name => :p4, :type => :global}
      ]
      @psfs = psfs.map{|pl| Ruber::PluginSpecification.intro(pl)}
    end
    
    it 'returns an empty array if the plugins passed as first argument don\'t have dependencies' do
      @loader.fill_dependencies(@psfs[0..1], @psfs).should == []
    end
    
    it 'returns an empty array if the plugins passed as first argument only depend on features having the name of other of those plugins' do
      @psfs[0].deps = [:p2]
      @psfs[1].deps = [:p3]
      @loader.fill_dependencies(@psfs[0..2], @psfs).should == []
    end
    
    it 'returns an emtpy array if the plugins passed as first argument only depend on features provided by of other plugins in the first argument' do
      @psfs[0].deps = [:f2]
      @psfs[1].deps = [:f3]
      @psfs[1].features << :f2
      @psfs[2].features << :f3 << :f5
      @loader.fill_dependencies(@psfs[0..2], @psfs).should == []
    end
    
    it 'returns an array containing the names of the plugins in the second argument whose name matches dependencies in the first argument not satisfied otherwise' do
      @psfs[0].deps << :f2 << :p4
      @psfs[1].deps << :p3
      @psfs[1].features << :f2
      @psfs << Ruber::PluginSpecification.intro(:name => :p5, :type => :global)
      res = @loader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
      res.should =~ [:p3, :p4]
    end
    
    it 'return an array also containing the dependencies\' dependencies, if any' do
      @psfs[0].deps << :f2 << :p4
      @psfs[1].deps << :p3
      @psfs[1].features << :f2
      @psfs[2].deps << :p6
      @psfs[2].deps << :p5
      @psfs << Ruber::PluginSpecification.intro(:name => :p5, :type => :global)
      @psfs << Ruber::PluginSpecification.intro(:name => :p6, :type => :global)
      res = @loader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
      res.should =~ [:p3, :p4, :p5, :p6]
    end
    
    it 'doesn\'t add a plugin to satisfy a dependency already satisifed by another plugin' do
      @psfs[0].deps << :f2 << :p4
      @psfs[1].deps << :p3
      @psfs[1].features << :f2
      @psfs[2].deps << :p6
      @psfs[2].features << :p5
      @psfs[3].deps << :p5
      @psfs << Ruber::PluginSpecification.intro(:name => :p5, :type => :global)
      @psfs << Ruber::PluginSpecification.intro(:name => :p6, :type => :global)
      @psfs << Ruber::PluginSpecification.intro(:name => :p7, :type => :global)
      res = @loader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
      res.should =~ [:p3, :p4, :p6]
    end
    
    it 'raises UnresolvedDep if some dependencies can\'t be resolved' do
      @psfs[0].deps << :f2 << :p4 << :p7
      @psfs[1].deps << :p3
      @psfs[1].features << :f2
      @psfs[2].deps << :p6
      @psfs[2].features << :p5
      @psfs[3].deps << :p5
      p5 = Ruber::PluginSpecification.intro(:name => :p5, 
                                            :type => :global, 
                                            :deps => :p7)
      @psfs << p5
      lambda do
        @loader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
      end.should raise_error(Ruber::UnresolvedDep) do |e|
        e.missing.should == {:p7 => [:p1], :p6 => [:p3]}
      end
    end

  end
  
  describe '#sort_plugins' do
    
    before do
      psfs = [
        {:name => :c, :type => :global},
        {:name => :a, :type => :global},
        {:name => :s, :type => :global},
        {:name => :m, :type => :global}
        ]
      @psfs = psfs.map{|i| Ruber::PluginSpecification.intro i}
    end
    
    it 'sorts the plugins alphabetically if no dependencies exist' do
      res = @loader.sort_plugins(@psfs)
      res.map(&:name).should == [:a, :c, :m, :s]
    end
    
    it 'returns the plugins sorted according to dependencies' do
      @psfs[0].deps << :s  << :a
      @psfs[1].deps << :x
      @psfs[3].deps << :x << :c
      @psfs << Ruber::PluginSpecification.intro(:name => :x, :type => :global)
      res = @loader.sort_plugins(@psfs)
      res.map(&:name).should == [:s, :x, :a, :c, :m]
    end
    
    it 'doesn\'t include features passed as second argument' do
      @psfs << Ruber::PluginSpecification.intro(:name => :x, :type => :global)
      @psfs[0].deps << :s << :a << :b
      @psfs[1].deps << :x << :l
      @psfs[3].deps << :x << :c
      @psfs[4].deps << :l << :b
      res = @loader.sort_plugins(@psfs, [:b, :l])
      res.map(&:name).should == [:s, :x, :a, :c, :m]
    end

    
    it 'raises Ruber::UnresolvedDep if a dependency can\'t be resolved' do
      @psfs << Ruber::PluginSpecification.intro(:name => :x, :type => :global)
      @psfs << Ruber::PluginSpecification.intro(:name => :l, :type => :global)
      @psfs[0].deps << :s << :a
      @psfs[1].deps << :x
      @psfs[3].deps << :x << :r
      @psfs[5].deps << :t << :t
      lambda do 
        @loader.sort_plugins(@psfs)
      end.should raise_error(Ruber::UnresolvedDep) do |e|
        e.missing.should == {:r => [:m, :l], :t => [:l]}
      end
    end
    
    it 'raises Ruber::CircularDep if there are circular dependencies' do
      @psfs[0].deps << :s << :a
      @psfs[1].deps << :m
      @psfs[3].deps << :c
      circ = [[:a, :x], [:x, :c], [:c, :a]]
      lambda do 
        @loader.sort_plugins(@psfs)
      end.should raise_error(Ruber::CircularDep) do |e| 
        circ.should include(e.circular_deps)
      end
    end
       
  end
  
  describe '#load_component' do
    
    before(:all) do
      cls = Class.new(Qt::Object) do 
        attr_accessor :plugin_description 
        def initialize manager, psf
          super()
          @plugin_description = psf
        end
      end
      Object.const_set(:TestComponent, cls)
    end
    
    after(:all) do
      Object.send :remove_const, :TestComponent
    end
    
    before do
      yaml = <<-EOS
  name: test
  class: TestComponent
  type: global
      EOS
      @dir = make_dir_tree ['plugin.yaml'], Dir.tmpdir, 'plugin.yaml' => yaml
      @base_dir = File.dirname @dir
      @component = File.basename @dir
      # The directory names returned by KDE::Global.dirs.resource_dirs end with
      # a /, so we ensure that @dir does, too
      @dir = File.join @dir, ''
      @component_file = File.join @dir, 'plugin.yaml'
    end
    
    after do
      FileUtils.rm_rf @dir
    end
    
    it 'adds the component directory to KDE::StandardDirs if an instance of the application exists' do
      flexmock(KDE::Application).should_receive(:instance).and_return Qt::Object.new
      parent = Qt::Object.new
      @loader.load_component @base_dir, @component, parent
      KDE::Global.dirs.resource_dirs('pixmap').should include(@dir)
      KDE::Global.dirs.resource_dirs('data').should include(@dir)
      KDE::Global.dirs.resource_dirs('appdata').should include(@dir)
    end
    
    it 'does\'t add the component directory to KDE::StandardDirs if no instance of the application exist' do
      flexmock(KDE::Application).should_receive(:instance).and_return nil
      @loader.load_component @base_dir, @component, Qt::Object.new
      KDE::Global.dirs.resource_dirs('pixmap').should_not include(@dir)
      KDE::Global.dirs.resource_dirs('data').should_not include(@dir)
      KDE::Global.dirs.resource_dirs('appdata').should_not include(@dir)
    end
    
    it 'reads the full PSF from the subdirectory named as the component in the given directory' do
      yaml = File.read @component_file
      psf = Ruber::PluginSpecification.full YAML.load(yaml)
      flexmock(Ruber::PluginSpecification).should_receive(:full).once.with(@component_file).and_return psf
      @loader.load_component @base_dir, @component, nil

    end
    
    it 'raises SystemCallError if the PSF couldn\'t be found' do
      FileUtils.rm @component_file
      lambda{@loader.load_component @base_dir, @component}.should raise_error(SystemCallError)
    end
    
    it 'raises ArgumentError if the file isn\'t a valid YAML file' do
      File.open(@component_file, 'w'){|f| f.write 'name: {'}
      lambda{@loader.load_component @base_dir, @component}.should raise_error(ArgumentError)
    end
    
    it 'raises Ruber::PluginSpecification::PSFError if the file isn\'t a valid PSF' do
      File.open(@component_file, 'w'){|f| f.write '{}'}
      lambda{@loader.load_component @base_dir, @component}.should raise_error(Ruber::PluginSpecification::PSFError)
    end
    
   it 'creates an instance of the class mentioned in the PSF, passing the keeper and the psf object as arguments' do
     yaml = File.read @component_file
     psf = Ruber::PluginSpecification.full(YAML.load(yaml))
     flexmock(Ruber::PluginSpecification).should_receive(:full).and_return psf
     keeper = Qt::Object.new
     comp = TestComponent.new(keeper, psf)
     flexmock(TestComponent).should_receive(:new).once.with(keeper, psf).and_return(comp)
     @loader.load_component @base_dir, @component, keeper
    end
    
    it 'returns the new component' do
      yaml = File.read @component_file
      keeper = Qt::Object.new
      psf = Ruber::PluginSpecification.full(YAML.load(yaml))
      comp = TestComponent.new keeper, psf
      flexmock(TestComponent).should_receive(:new).once.and_return(comp)
      @loader.load_component(@base_dir, @component, @keeper).should equal(comp)
    end

    it 'stores the directory where the plugin.yaml file is in the directory attribute of the PSF' do
      comp = @loader.load_component @base_dir, @component
      # Use join to ensure that plugin_description.directory ends in a / as 
      # @dir does
      File.join(comp.plugin_description.directory, '').should == @dir
    end
            
  end
  
  describe '#load_plugin' do
    
      before(:all) do
      cls = Class.new(Qt::Object) do 
        attr_accessor :plugin_description 
        def initialize keeper, psf
          super(keeper)
          @plugin_description = psf
        end
        define_method(:load_settings){}
        define_method(:delayed_initialize){}
      end
      Object.const_set(:TestPlugin, cls)
    end
    
    after(:all){Object.send :remove_const, :TestPlugin}
    
    before do
      @yaml = <<-EOS
  name: test
  class: TestPlugin
  type: global
      EOS
      @dir = make_dir_tree ['plugin.yaml'], Dir.tmpdir, 'plugin.yaml' => @yaml
      # Ensure @dir ends with a /
      @dir = File.join @dir, ''
      @file = File.join @dir, 'plugin.yaml'
      @psf = Ruber::PluginSpecification.full YAML.load(@yaml)
      @keeper = Qt::Object.new
    end
    
    it 'adds the plugin directory to KDE::StandardDirs' do
      @loader.load_plugin @dir, @keeper
      KDE::Global.dirs.resource_dirs('pixmap').should include(@dir)
      KDE::Global.dirs.resource_dirs('data').should include(@dir)
      KDE::Global.dirs.resource_dirs('appdata').should include(@dir)
    end
  
    it 'reads the full PSF from the plugin.yaml file contained in the directory passed as argument' do
      psf = Ruber::PluginSpecification.full YAML.load(@yaml)
      data = YAML.load @yaml
      flexmock(Ruber::PluginSpecification).should_receive(:full).once.with(data, @dir).and_return psf
      @loader.load_plugin @dir, @keeper
    end
    
    it 'raises SystemCallError if the plugin file doesn\'t exist' do
      FileUtils.rm @file
      lambda{@loader.load_plugin @dir, @keeper}.should raise_error(SystemCallError)
    end
    
    it 'raises ArgumentError if the plugin file isn\'t a valid YAML file' do
      File.open(@file, 'w'){|f| f.write 'name: {'}
      lambda{@loader.load_plugin @dir, @keeper}.should raise_error(ArgumentError)
    end
    
    it 'raises Ruber::PluginSpecification::PSFError if the file isn\'t a valid PSF' do
      File.open(@file, 'w'){|f| f.write '{}'}
      code = lambda{@loader.load_plugin @dir, @keeper}
      code.should raise_error(Ruber::PluginSpecification::PSFError)
    end
    
    it 'creates an instance of the class mentioned in the PSF, passing the keeper and the PluginSpecification object as arguments' do
      psf = Ruber::PluginSpecification.full(YAML.load(@yaml))
      flexmock(Ruber::PluginSpecification).should_receive(:full).and_return psf
      plug = TestPlugin.new(@keeper, psf)
      flexmock(TestPlugin).should_receive(:new).once.with(@keeper, psf).and_return(plug)
      @loader.load_plugin @dir, @keeper
    end
    
    it 'returns the plugin object' do
      psf = Ruber::PluginSpecification.full(YAML.load(@yaml))
      flexmock(Ruber::PluginSpecification).should_receive(:full).and_return psf
      plug = TestPlugin.new(@keeper, psf)
      flexmock(TestPlugin).should_receive(:new).once.with(@keeper, psf).and_return(plug)
      res = @loader.load_plugin @dir, @keeper
      res.should equal(plug)      
    end
    
    context 'if included in a class derived from Qt::Object' do
      
      before :all do
        class QObjectLoader < Qt::Object
          include Ruber::ComponentLoader
          signals 'component_loaded(QObject*)', 'feature_loaded(QString, QObject*)'
        end
      end
      
      after :all do
        Object.send :remove_const, :QObjectLoader
      end

      before do
        @loader = QObjectLoader.new
      end
           
      it 'emits the "component_loaded(QObject*)" signal with the plugin object as argument' do
        psf = Ruber::PluginSpecification.full(YAML.load(@yaml))
        @plug = TestPlugin.new(@keeper, psf)
        flexmock(TestPlugin).should_receive(:new).once.and_return(@plug)
        m = flexmock{|mk| mk.should_receive(:component_loaded).once.with(@plug)}
        @loader.connect(SIGNAL('component_loaded(QObject*)')) do |o|
          m.component_loaded o
        end
        @loader.load_plugin @dir, @keeper
      end
      
      it 'emits the "feature_loaded(QString, QObject*)" signal for each feature provided by the plugin' do
        psf = Ruber::PluginSpecification.full(YAML.load(@yaml))
        psf.features << :x << :y
        flexmock(Ruber::PluginSpecification).should_receive(:full).and_return psf
        @plug = TestPlugin.new(@keeper, psf)
        flexmock(TestPlugin).should_receive(:new).once.and_return(@plug)
        m = flexmock do |mk| 
          mk.should_receive(:feature_loaded).with('test', @plug).once
          mk.should_receive(:feature_loaded).with('x', @plug).once
          mk.should_receive(:feature_loaded).with('y', @plug).once
        end
        @loader.connect(SIGNAL('feature_loaded(QString, QObject*)')) do |s, o|
          m.feature_loaded s, o
        end
        @loader.load_plugin @dir, @keeper
      end
      
      context 'if included in a class not derived from Qt::Object' do
        
        it 'doesn\'t attempt to emit signals' do
          lambda{@loader.load_plugin @dir, @keeper}.should_not raise_error
        end
        
      end
          
    end
    
    it 'calls the new plugin\'s delayed_initialize method, after emitting the feature_loaded signals' do
      psf = Ruber::PluginSpecification.full(YAML.load(@yaml))
      psf.features << :x << :y
      flexmock(Ruber::PluginSpecification).should_receive(:full).and_return psf
      plug = TestPlugin.new(@keeper, psf)
      flexmock(TestPlugin).should_receive(:new).once.with(@keeper, psf).and_return(plug)
      flexmock(@loader).should_receive(:component_loaded)
      flexmock(@loader).should_receive(:feature_loaded)
      flexmock(@loader).should_receive(:emit).times(4).globally.ordered
      flexmock(@loader).should_receive(:is_a?).with(Qt::Object).and_return true
      flexmock(plug).should_receive(:delayed_initialize).once.globally.ordered
      @loader.load_plugin @dir, @keeper
    end
    
    it 'calls the new plugin\'s delayed_initialize method even if it\'s private' do
      psf = Ruber::PluginSpecification.full(YAML.load(@yaml))
      flexmock(Ruber::PluginSpecification).should_receive(:full).and_return psf
      plug = TestPlugin.new(@keeper, psf)
      flexmock(TestPlugin).should_receive(:new).once.with(@keeper, psf).and_return(plug)
      class << plug
        private :delayed_initialize
      end
      flexmock(plug).should_receive(:delayed_initialize).once
      @loader.load_plugin @dir, @keeper
    end
        
  end
  
  describe '#find_needed_plugins' do
    
    before do
      contents = {
        'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global, deps: [p4]}',
        'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
        'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}',
        'd2/p4/plugin.yaml' => '{name: p4, class: P4, type: global}'
        }
      tree = YAML.load %q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p1, plugin.yaml], [p4, plugin.yaml]]]}
      @dir = make_dir_tree tree, Dir.tmpdir, contents
      @psfs = Hash[contents.values.map do |str|
        h = YAML.load str
        [h['name'].to_sym, Ruber::PluginSpecification.intro(h)]
      end
      ]
    end
    
    after do
      FileUtils.rm_rf @dir
    end

    it 'returns the PSFs for the given plugins in alphabetical order if they have no dependecy according to their PSFs in the given directories' do
      res = @loader.find_needed_plugins [:p4, :p3], [@dir]
      res.should == [@psfs[:p3], @psfs[:p4]]
    end
    
    it 'returns the PSFs in dependency order if some of them depend on others' do
      res = @loader.find_needed_plugins [:p3, :p1, :p4], [@dir]
      res.should == [@psfs[:p3], @psfs[:p4], @psfs[:p1]]
    end
    
    it 'returns the PSFs in dependency order, adding any plugin needed to satisfy dependencies' do
      res = @loader.find_needed_plugins [:p3, :p1], [@dir]
      res.should == [@psfs[:p3], @psfs[:p4], @psfs[:p1]]
    end
    
    it 'also uses the PSFs in the extra argument to satisfy dependencies' do
      file = File.join @dir, 'd1', 'p1', 'plugin.yaml'
      File.open(file, 'w'){|f| f.write "{name: p1, type: global, deps: [p5]}"}
      FileUtils.mkdir_p File.join @dir, 'd1', 'p5'
      file = File.join @dir, 'd1', 'p5', 'plugin.yaml'
      File.open(file, 'w'){|f| f.write "{name: p5, type: global}"}
      p5 = Ruber::PluginSpecification.intro :name => :p5, :type => :global
      res = @loader.find_needed_plugins [:p3, :p1], [@dir], [p5]
      res.should == [@psfs[:p1], @psfs[:p3]]      
    end
    
  end
  
  describe 'Ruber::ComponentManager#load_plugins' do
    
    before do
#       flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
      @data = %q{[[d1, [p1, plugin.yaml], [p2, plugin.yaml]], [d2, [p3, plugin.yaml], [p1, plugin.yaml]]]}
      @tree = YAML.load @data
      @dir = nil
      Object.const_set :P1, Class.new(Ruber::Plugin)
      Object.const_set :P2, Class.new(Ruber::Plugin)
      Object.const_set :P3, Class.new(Ruber::Plugin)
    end
    
    after do
      Object.send :remove_const, :P1
      Object.send :remove_const, :P2
      Object.send :remove_const, :P3
    end
    
#     it 'should find the plugins in the given directories and load them in the alphabetically order if there aren\'t dependencies among them' do
#       contents = {
#         'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
#         'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
#         'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
#         }
#       @dir = make_dir_tree(@tree, '/tmp/', contents)
#       @manager.load_plugins(%w[p2 p1 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
#       @manager.plugins.map{|i| i.class}.should == [P1, P2, P3]
#     end
#     
#     it 'should work with both strings and symbols' do
#       contents = {
#         'd1/p1/plugin.yaml' => '{name: p1, class: P1, type: global}',
#         'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
#         'd2/p3/plugin.yaml' => '{name: p3, class: P3, type: global}'
#       }
#       @dir = make_dir_tree(@tree, '/tmp/', contents)
#       @manager.load_plugins([:p2, :p1, :p3], %w[d1 d2].map{|d| File.join(@dir, d)})
#       @manager.plugins.map{|i| i.class}.should == [P1, P2, P3]
#       
#     end
#     
#     it 'should find the plugins in the given directories and load them in dependecy order' do
#       contents = {
#         'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p3, type: global}',
#         'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
#         'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, type: global}'
#         }
#       @dir = make_dir_tree(@tree, '/tmp/', contents)
#       @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
#       @manager.plugins.map{|i| i.class}.should == [P2, P3, P1]
#     end
#     
#     it 'should resolve dependencies among the plugins' do
#       contents = {
#         'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p4, type: global}',
#         'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
#         'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, features: [:p4], type: global}'
#         }
#       @dir = make_dir_tree(@tree, '/tmp/', contents)
#       @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
#       @manager.plugins.map{|i| i.class}.should == [P2, P3, P1]
#     end
#     
#     it 'should load the plugins using the pdfs with the unresolved dependencies' do
#       contents = {
#         'd1/p1/plugin.yaml' => '{name: p1, class: P1, deps: :p4, type: global}',
#         'd1/p2/plugin.yaml' => '{name: p2, class: P2, type: global}',
#         'd2/p3/plugin.yaml' => '{name: p3, class: P3, deps: :p2, features: [:p4], type: global}'
#         }
#       @dir = make_dir_tree(@tree, '/tmp/', contents)
#       @manager.load_plugins(%w[p1 p2 p3], %w[d1 d2].map{|d| File.join(@dir, d)})
#       @manager[:p1].plugin_description.deps.should == [:p4]
#     end
    
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

end
  