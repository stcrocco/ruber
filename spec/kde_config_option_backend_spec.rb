require 'spec/common'

require 'tmpdir'

require 'ruber/kde_config_option_backend'

#We need to generate a different file for each test, since otherwise the config object generated for one spec will also be used for the others (since they're KDE::SharedConfig objects)
def generate_random_file base = "ruber_kde_config_option_backend"
  File.join Dir.tmpdir, "#{base}-#{5.times.map{rand 10}.join}"
end


describe 'Ruber::KDEConfigSettingsBackend when created' do
    
  it 'should use the global kde config object if the constructor is called with no arguments' do
    cfg = KDE::Config.new File.join( Dir.tmpdir, 'ruber_kde_config_option_backend'), KDE::Config::SimpleConfig
    flexmock(KDE::Global).should_receive(:config).once.and_return cfg
    back = Ruber::KDEConfigSettingsBackend.new
    back.instance_variable_get(:@config).should equal(cfg)
  end
  
  it 'should use a new full KDE::SharedConfig object corresponding to the path given as argument if called with one argument' do
    filename = generate_random_file
    back = Ruber::KDEConfigSettingsBackend.new filename
    back.instance_variable_get(:@config).name.should == filename
  end
  
  it 'should use a new KDE::SharedConfig object corresponding to the path and the mode given as arguments if called with two arguments' do
    filename = generate_random_file
    cfg = KDE::SharedConfig.open_config filename, KDE::Config::SimpleConfig
    flexmock(KDE::SharedConfig).should_receive(:open_config).once.with(filename, KDE::Config::SimpleConfig).and_return cfg
    back = Ruber::KDEConfigSettingsBackend.new filename, KDE::Config::SimpleConfig
    back.instance_variable_get(:@config).name.should == filename
  end
  
  it 'should read the "Yaml options" entry of the "Ruber Internal" group and store the result in the @yaml_options instance variable, after having converted it' do
    filename = generate_random_file
    File.open(filename, 'w') do |f|
      data = <<-EOS
[Ruber Internal]
Yaml options=g1/o1,g1/o2,g2/o3
      EOS
      f.write data
    end
    back = Ruber::KDEConfigSettingsBackend.new filename
    FileUtils.rm_f filename
    back.instance_variable_get(:@yaml_options).should == [[:g1, :o1], [:g1, :o2], [:g2, :o3]]
  end
  
end

describe 'Ruber::KDEConfigSettingsBackend#[]' do
  
  before(:all) do
    @filename = generate_random_file
    data = <<-EOS
[Ruber Internal]
Yaml options=group_two/option_two,group_two/option_three

[Group One]
Option 1=test string
Option 2=1224

[Group Two]
Option One=ab,cd,ef
Option Two={a: b, c: :d}
Option Three=:xyz
    EOS
    File.open( @filename, 'w'){|f| f.write data}
  end
  
  after :all do
    FileUtils.rm_f @filename
  end
  
  it 'should return the value of option corresponding to the automatically determined human-friendly versions of the group and name of the argument' do
    back = Ruber::KDEConfigSettingsBackend.new @filename
    opt = OS.new({:name => :option_1, :group => :group_one, :default => ''})
    back[opt].should == 'test string'
    opt = OS.new({:name => :option_2, :group => :group_one, :default => 12})
    back[opt].should == 1224
    opt = OS.new({:name => :option_one, :group => :group_two, :default => []})
    back[opt].should == %w[ab cd ef]
  end
  
  it 'should process the string using YAML if it is included in the Yaml options list' do
    back = Ruber::KDEConfigSettingsBackend.new @filename
    opt = OS.new({:name => :option_two, :group => :group_two, :default => {}})
    back[opt].should == {'a' => 'b', 'c' => :d}
    opt = OS.new({:name => :option_three, :group => :group_two, :default => :abc})
    back[opt].should == :xyz
  end
  
  it 'should process the string using YAML if the option\'s default value isn\'t manageable using KDE::Config' do
    back = Ruber::KDEConfigSettingsBackend.new @filename
    opt = OS.new({:name => :option_2, :group => :group_one, :default => nil})
    flexmock(YAML).should_receive(:load).with('1224').once.and_return 1224
    back[opt].should == 1224
  end
  
  it 'should return a deep duplicate of the default value for the option if the option isn\'t in the file' do
    back = Ruber::KDEConfigSettingsBackend.new @filename
    opt = OS.new({:name => :option_6, :group => :group_one, :default => {:a => 2}})
    back[opt].should == {:a => 2}
    back[opt].should_not equal(opt.default)
    opt = OS.new({:name => :option_2, :group => :group_three, :default => 'hello'})
    back[opt].should == 'hello'
    back[opt].should_not equal(opt.default)
    opt = OS.new({:name => :option_6, :group => :group_one, :default => {:a => %w[a b]}})
    back[opt].should == {:a => %w[a b]}
    back[opt].should_not equal(opt.default)
    back[opt][:a].should_not equal(opt.default[:a])
    opt = OS.new({:name => :option_7, :group => :group_three, :default => 3})
    back[opt].should == 3
  end
  
end

describe 'Ruber::KDEConfigSettingsBackend#[]' do
  
#   before(:all) do
#   end
  
  before do
    @filename = generate_random_file
    data = <<-EOS
    [Ruber Internal]
    Yaml options=group_two/option_two,group_two/option_three
    
    [Group One]
    Option 1=test string
    Option 2=1224
    
    [Group Two]
    Option One=ab,cd,ef
    Option Two={a: b, c: :d}
    Option Three=:xyz
    EOS
    File.open( @filename, 'w'){|f| f.write data}
    @back = Ruber::KDEConfigSettingsBackend.new @filename
  end
  
  it 'should write the options which the KDE configuration system can handle' do
    opts = {
      OS.new({:name => :option_1, :group => :group_one, :default => ''}) => 'hello',
      OS.new({:name => :option_one, :group => :group_two, :default => []}) => %w[x y],
      OS.new({:name => :o1, :group => :G3, :default => 0}) => 5
    }
    @back.write opts
    cfg = KDE::Config.new @filename, KDE::Config::SimpleConfig
    cfg.group('Group One').read_entry('Option 1', '').should == 'hello'
    cfg.group('Group Two').read_entry('Option One', []).should == %w[x y]
    cfg.group('G3').read_entry('O1', 1).should == 5
  end
  
  it 'should write the options which the KDE configuration system can\'t handle converting them to YAML and store them in the "Yaml options option"' do
    opts = {
      OS.new({:name => :option_3, :group => :group_one, :default => (1..2)}) => (3..5),
      OS.new({:name => :option_two, :group => :group_two, :default => {}}) => {1 => :x},
    }
    @back.write opts
    cfg = KDE::Config.new @filename, KDE::Config::SimpleConfig
    YAML.load(cfg.group('Group One').read_entry('Option 3', '')).should == (3..5)
    YAML.load(cfg.group('Group Two').read_entry('Option Two', '')).should == {1 => :x}
    cfg.group('Ruber Internal').read_entry('Yaml options', []).should =~ %w[group_two/option_two group_two/option_three group_one/option_3] 
  end
  
  it 'should write the options which whose value is of a different class from the default value (except for true and false) converting them to YAML and store them in the "Yaml options option"' do
    opts = {
      OS.new({:name => :option_3, :group => :group_one, :default => 'abc'}) => %w[a b],
      OS.new({:name => :option_two, :group => :group_two, :default => []}) => 3,
      OS.new({:name => :option_four, :group => :group_three, :default => true}) => false,
      OS.new({:name => :option_five, :group => :group_three, :default => false}) => true,
    }
    @back.write opts
    cfg = KDE::Config.new @filename, KDE::Config::SimpleConfig
    YAML.load(cfg.group('Group One').read_entry('Option 3', 'abc')).should == %w[a b]
    YAML.load(cfg.group('Group Two').read_entry('Option Two', '')).should == 3
    cfg.group('Group Three').read_entry('Option Four', true).should == false
    cfg.group('Group Three').read_entry('Option Five', false).should == true
    cfg.group('Ruber Internal').read_entry('Yaml options', []).should =~ %w[group_two/option_two group_two/option_three group_one/option_3] 
  end
  
  it 'should keep the options which haven\'t been explicitly written' do
    opts = {
      OS.new({:name => :option_1, :group => :group_one, :default => ''}) => 'hello',
      OS.new({:name => :o1, :group => :G3, :default => 0}) => 5,
      OS.new({:name => :o2,  :group => :G3, :default => /ab/}) => /abc/
    }
    @back.write opts
    cfg = KDE::Config.new @filename, KDE::Config::SimpleConfig
    cfg.group('Group One').read_entry('Option 2', 0).should == 1224
    cfg.group('Group Two').read_entry('Option One', []).should == %w[ab cd ef]
    YAML.load(cfg.group('Group Two').read_entry('Option Two', '')).should == {'a' => 'b', 'c' => :d}
    YAML.load(cfg.group('Group Two').read_entry('Option Three', '')).should == :xyz
    cfg.group('Ruber Internal').read_entry('Yaml options', []).should =~ %w[group_two/option_two group_two/option_three G3/o2] 
  end
  
  it 'should not write options whose value is equal to their default value' do
    opts = { 
      OS.new({:name => :option_2, :group => :group_one, :default => 5}) => 5,
      OS.new({:name => :option_3, :group => :group_three, :default => 'ab'}) => 'ab',
    }
    @back.write opts
    cfg = KDE::Config.new @filename, KDE::Config::SimpleConfig
    cfg.group('Group One').has_key('Option 2').should be_false
    cfg.group('Group Three').has_key('Option 3').should be_false
  end
  
  after do
    FileUtils.rm_f @filename
  end
  
end