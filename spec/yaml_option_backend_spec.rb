require 'spec/common'
require 'tempfile'
require 'fileutils'
require 'tmpdir'
require 'facets/kernel/deep_copy'


require 'ruber/yaml_option_backend'

describe 'Ruber::YamlSettingsBackend, when created' do
  
  it 'should load the yaml file passed as argument and store its contents, if the file exists' do
    Tempfile.open('yaml_option_backend.yaml') do |tf|
      data = <<EOS
:G1:
 :o1: 1
 :o2: hello
:G2:
 :o1: ~
 :o2: [1, 2, a]
 :o3: test
EOS
      tf.write data
      tf.flush
      back = Ruber::YamlSettingsBackend.new(tf.path)
      exp = {
        :G1 => {:o1 => 1, :o2 => 'hello'},
        :G2 => {:o1 => nil, :o2 => [1,2, 'a'], :o3 => 'test'}
      }
      back.instance_variable_get(:@data).should == exp
    end
  end
  
  it 'should raise YamlSettingsBackend::InvalidSettingsFile if the file exists but isn\'t a valid YAML file' do
    Tempfile.open('yaml_option_backend.yaml') do |tf|
      data = "{"
      tf.write data
      tf.flush
      lambda{Ruber::YamlSettingsBackend.new(tf.path)}.should raise_error(Ruber::YamlSettingsBackend::InvalidSettingsFile)
    end
  end
  
  it 'should raise YamlSettingsBackend::InvalidSettingsFile if the file exists but doesn\'t contain a top-level hash' do
    Tempfile.open('yaml_option_backend.yaml') do |tf|
      data = "[a, b, c]"
      tf.write data
      tf.flush
      lambda{Ruber::YamlSettingsBackend.new(tf.path)}.should raise_error(Ruber::YamlSettingsBackend::InvalidSettingsFile)
    end
  end
  
  it 'sets the data to an empty hash before raising InvalidSettingsFile if the file isn\'t a valid YAML file' do
    
    cls = Class.new(Ruber::YamlSettingsBackend) do
      def initialize file
        begin super
        rescue Ruber::YamlSettingsBackend::InvalidSettingsFile
        end
      end
    end
    
    Tempfile.open('yaml_option_backend.yaml') do |tf|
      data = "{"
      tf.write data
      tf.flush
      back = cls.new tf.path
      back.instance_variable_get(:@data).should == {}
    end
    
  end
  
  it 'sets the data to an empty hash before raising InvalidSettingsFile if the file isn\'t a valid project file' do
    
    cls = Class.new(Ruber::YamlSettingsBackend) do
      def initialize file
        begin super
        rescue Ruber::YamlSettingsBackend::InvalidSettingsFile
        end
      end
    end
    
    Tempfile.open('yaml_option_backend.yaml') do |tf|
      data = "[a, b, c]"
      tf.write data
      tf.flush
      back = cls.new tf.path
      back.instance_variable_get(:@data).should == {}
    end

  end
    
  it 'should create an empty hash if the file doesn\'t exist' do
    back = Ruber::YamlSettingsBackend.new('/xyz.yaml')
    back.instance_variable_get(:@data).should == {}
  end
  
  it 'should store the name of the file' do
    back = Ruber::YamlSettingsBackend.new('/xyz.yaml')
    back.instance_variable_get(:@filename).should == '/xyz.yaml'
  end
  
end

describe 'Ruber::YamlSettingsBackend#[]' do
  
  before do
    Tempfile.open('yaml_option_backend.yaml') do |tf|
    data = <<EOS
:G1:
 :o1: 1
 :o2: hello
:G2:
 :o1: ~
 :o2: [1, 2, a]
 :o3: test
EOS
    tf.write data
    tf.flush
    @back = Ruber::YamlSettingsBackend.new(tf.path)
    end
  end
  
  it 'should return the value of the option with the group and name specified by the argument' do
    opt = OS.new({:name => :o2, :group => :G2, :default => []})
    @back[opt].should == [1, 2, 'a']
  end
  
  it 'should return the default value of the option if an option with that name and group doesn\'t exist' do
    opt = OS.new({:name => :o4, :group => :G2, :default => 'xyz'})
    @back[opt].should == 'xyz'
    opt = OS.new({:name => :o1, :group => :G3, :default => (1..2)})
    @back[opt].should == (1..2)
    opt = OS.new({:name => :o4, :group => :G3, :default => []})
    @back[opt].should == []
  end
  
  it 'should return a deep duplicate of the default value for the option if the option isn\'t in the file' do
    opt = OS.new({:name => :option_6, :group => :group_one, :default => {:a => 2}})
    @back[opt].should == {:a => 2}
    @back[opt].should_not equal(opt.default)
    opt = OS.new({:name => :option_2, :group => :group_three, :default => 'hello'})
    @back[opt].should == 'hello'
    @back[opt].should_not equal(opt.default)
    opt = OS.new({:name => :option_6, :group => :group_one, :default => {:a => %w[a b]}})
    @back[opt].should == {:a => %w[a b]}
    @back[opt].should_not equal(opt.default)
    @back[opt][:a].should_not equal(opt.default[:a])
    opt = OS.new({:name => :option_7, :group => :group_three, :default => 3})
    @back[opt].should == 3
  end
  
end

describe 'Ruber::YamlSettingsBackend#write' do
  
  before do
    @filename =File.join(Dir.tmpdir, 'ruber_yaml_option_backend.yaml') 
  end
  
  after do
    FileUtils.rm_f @filename
  end
  
  it 'should write all the options passed as argument to file' do
    back = Ruber::YamlSettingsBackend.new @filename
    options = {
      OS.new(:name => :o1, :group => :G1, :default => 3) => -1,
      OS.new(:name => :o2, :group => :G1, :default => 'xyz') => 'abc',
      OS.new(:name => :o1, :group => :G2, :default => :a) => :b
    }
    back.write(options)
    exp = {
      :G1 => {:o1 => -1, :o2 => 'abc'},
      :G2 => {:o1 => :b}
    }
    (YAML.load File.read(@filename)).should == exp
  end
  
  it 'should not write the options whose value is equal to their default value' do
    back = Ruber::YamlSettingsBackend.new @filename
    options = {
      OS.new(:name => :o1, :group => :G1, :default => 3) => 3,
      OS.new(:name => :o2, :group => :G1, :default => 'xyz') => 'abc',
      OS.new(:name => :o1, :group => :G2, :default => :a) => :a
    }
    back.write(options)
    exp = { :G1 => {:o2 => 'abc'} }
    (YAML.load File.read(@filename)).should == exp
  end
  
  it 'should not remove options not included in the argument from the file' do
    back = Ruber::YamlSettingsBackend.new @filename
    orig_data = {
      :G1 => {:o1 => 7, :o3 => :x}, 
      :G2 => {:o2 => 1..2},
      :G3 => {:o1 => 'hello', :o3 => [1,2,3]}
    }
    back.instance_variable_set :@data, orig_data
    options = {
      OS.new(:name => :o1, :group => :G1, :default => 3) => 3,
      OS.new(:name => :o2, :group => :G1, :default => 'xyz') => 'abc',
      OS.new(:name => :o1, :group => :G2, :default => :a) => :b
    }
    back.write(options)
    exp = orig_data.deep_copy
    exp[:G1].delete :o1
    exp[:G1][:o2] = 'abc'
    exp[:G2][:o1] = :b
    (YAML.load File.read(@filename)).should == exp
  end
  
  it 'should store the new data' do
    back = Ruber::YamlSettingsBackend.new @filename
    orig_data = {
      :G1 => {:o1 => 7, :o3 => :x}, 
      :G2 => {:o2 => 1..2},
      :G3 => {:o1 => 'hello', :o3 => [1,2,3]}
    }
    back.instance_variable_set :@data, orig_data
    options = {
      OS.new(:name => :o1, :group => :G1, :default => 3) => 5,
      OS.new(:name => :o2, :group => :G1, :default => 'xyz') => 'abc',
      OS.new(:name => :o1, :group => :G2, :default => :a) => :b
    }
    back.write(options)
    exp = orig_data.deep_copy
    exp[:G1][:o1] = 5
    exp[:G1][:o2] = 'abc'
    exp[:G2][:o1] = :b
    back.instance_variable_get(:@data).should == exp
  end
  
end

describe Ruber::YamlSettingsBackend do
  
  describe "#file" do
    
    it 'should return the argument passed to the constructor' do
      back = Ruber::YamlSettingsBackend.new('/xyz.yaml')
      back.file.should == '/xyz.yaml'
    end
    
  end
  
end