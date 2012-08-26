require 'spec/common'
require 'ruber/component_loader'

describe Ruber::ComponentLoader do
  
  after do
    FileUtils.rm_rf @dir if @dir
  end
  
  it 'inherits from Qt::Object' do
    Ruber::ComponentLoader.ancestors.should include(Qt::Object)
  end
    
  describe 'Ruber::ComponentLoader.find_plugins' do
    
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
  
end