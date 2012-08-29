require 'spec/common'
require 'ruber/component_loader'

describe Ruber::ComponentLoader do
  
  after do
    FileUtils.rm_rf @dir if @dir
  end
  
  it 'inherits from Qt::Object' do
    Ruber::ComponentLoader.ancestors.should include(Qt::Object)
  end
    
  describe '.find_plugins' do
    
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
        Ruber::ComponentLoader.find_plugins(@dirs).should == @exp
        Ruber::ComponentLoader.find_plugins(@dirs, false).should == @exp
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
        res = Ruber::ComponentLoader.find_plugins(@dirs, true)
        res.should == @exp
        res[:p1].directory.should == File.join(@dirs[0], 'p1')
        res[:p2].directory.should == File.join(@dirs[0], 'p2')
        res[:p3].directory.should == File.join(@dirs[1], 'p3')
        res[:p4].directory.should == File.join(@dirs[1], 'p4')
        FileUtils.rm_r @dir
      end
      
      it 'doesn\'t return full plugin specifications' do
        res = Ruber::ComponentLoader.find_plugins(@dirs, true)
        res.each_value{|psf| psf.should be_intro_only}
      end
      
    end
        
    it 'should return only the file in the earliest directory, if more than one directory contain the same plugin' do
      dir = File.join @dirs[0], 'p3'
      FileUtils.mkdir dir
      file = File.join dir, 'plugin.yaml'
      File.open(file, 'w'){|f| f.write('{name: p3, type: global }')}
      Ruber::ComponentLoader.find_plugins(@dirs)[:p3].should == file
      Ruber::ComponentLoader.find_plugins(@dirs, true)[:p3].directory.should == dir
    end
    
  end
  
  describe '.resolve_features' do
    
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
      res = Ruber::ComponentLoader.resolve_features @psfs
      res[0].deps.should =~ [:s, :a, :x]
      res[1].deps.should =~ [:x, :s]
      res[2].deps.should == []
      res[3].deps.should =~ [:x, :c]
      res[4].deps.should == []
    end
    
    it 'raises Ruber::ComponentLoader::UnresolvedDep if some features can\'t be found' do
      @psfs[0].deps << :y
      @psfs[3].deps += [:z, :y]
      lambda{Ruber::ComponentLoader.resolve_features @psfs}.should raise_error(Ruber::UnresolvedDep){|e| e.missing.should == {:c => [:y], :m => [:z, :y]}}
    end
    
    it 'also searches the psfs passed as second argument' do
      @psfs[0].deps += [:y, :k]
      @psfs[3].deps += [:z, :y]
      extra = [
        {:name => :A, :features => [:A, :z]},
        {:name => :B, :features => [:B, :y, :k]}
      ].map{|i| OpenStruct.new i}
      res = Ruber::ComponentLoader.resolve_features @psfs, extra
      res[0].deps.should =~ [:s, :a, :x, :B]
      res[1].deps.should =~ [:x, :s]
      res[2].deps.should == []
      res[3].deps.should =~ [:x, :c, :A, :B]
      res[4].deps.should == []
    end
    
    it 'doesn\' change the psfs passed as argument' do
      res = Ruber::ComponentLoader.resolve_features @psfs
      res.each_with_index{|pl, i| pl.should_not equal(@psfs[i])}
    end
    
  end
  
  describe '.fill_dependencies' do
    
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
      Ruber::ComponentLoader.fill_dependencies(@psfs[0..1], @psfs).should == []
    end
    
    it 'returns an empty array if the plugins passed as first argument only depend on features having the name of other of those plugins' do
      @psfs[0].deps = [:p2]
      @psfs[1].deps = [:p3]
      Ruber::ComponentLoader.fill_dependencies(@psfs[0..2], @psfs).should == []
    end
    
    it 'returns an emtpy array if the plugins passed as first argument only depend on features provided by of other plugins in the first argument' do
      @psfs[0].deps = [:f2]
      @psfs[1].deps = [:f3]
      @psfs[1].features << :f2
      @psfs[2].features << :f3 << :f5
      Ruber::ComponentLoader.fill_dependencies(@psfs[0..2], @psfs).should == []
    end
    
    it 'returns an array containing the names of the plugins in the second argument whose name matches dependencies in the first argument not satisfied otherwise' do
      @psfs[0].deps << :f2 << :p4
      @psfs[1].deps << :p3
      @psfs[1].features << :f2
      @psfs << Ruber::PluginSpecification.intro(:name => :p5, :type => :global)
      res = Ruber::ComponentLoader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
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
      res = Ruber::ComponentLoader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
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
      res = Ruber::ComponentLoader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
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
        Ruber::ComponentLoader.fill_dependencies(@psfs[0..1], @psfs[2..-1])
      end.should raise_error(Ruber::UnresolvedDep) do |e|
        e.missing.should == {:p7 => [:p1], :p6 => [:p3]}
      end
    end

  end

  
end