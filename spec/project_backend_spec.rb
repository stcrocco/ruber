require 'spec/common'

require 'ruber/project_backend'

describe Ruber::ProjectBackend do
  
  before do
    @dir = make_dir_tree []
  end
  
  after do
    FileUtils.rm_rf @dir
  end
  
  describe 'when created' do
    
    it 'takes the path of the main project file as argument' do
      lambda{Ruber::ProjectBackend.new File.join(@dir, 'Test.ruprj')}.should_not raise_error
    end
    
    it 'it creates three YamlSettingsBackend: the first corresponds to the argument, the other two correspond to files obtained by appending .ruusr and .ruses to the argument if the argument doesn\'t have extension .ruprj' do
      base = File.join @dir, 'Test.xyz'
      back = Ruber::ProjectBackend.new base
      backends = back.instance_variable_get(:@backends)
      backends[:global].file.should == base
      backends[:user].file.should == base+'.ruusr'
      backends[:session].file.should == base+'.ruses'
    end
    
    it 'uses the argment as it is for the global backend and removes its extension before appending .ruusr and .ruses if the argument has extension .ruprj' do
      base = File.join @dir, 'Test.ruprj'
      file = base + '.ruprj'
      back = Ruber::ProjectBackend.new file
      backends = back.instance_variable_get(:@backends)
      backends[:global].file.should == file
      backends[:user].file.should == base+'.ruusr'
      backends[:session].file.should == base+'.ruses'
      
    end
    
    it 'raises YamlSettingsBackend::InvalidSettingsFile if that exception is raised when creating the backend for the global options' do
      base = File.join @dir, 'Test.ruprj'
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.and_raise Ruber::YamlSettingsBackend::InvalidSettingsFile, "The file #{base+'.ruprj'} isn\'t a valid option file"
      lambda{Ruber::ProjectBackend.new base}.should raise_error( Ruber::YamlSettingsBackend::InvalidSettingsFile, "The file #{base+'.ruprj'} isn\'t a valid option file")
    end
    
    it 'raises YamlSettingsBackend::InvalidSettingsFile if that exception is raised when creating the backend for the user options' do
      file = File.join @dir, 'Test.ruprj'
      base = File.join @dir, 'Test'
      global = Ruber::YamlSettingsBackend.new base
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base).and_return(global)
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base + '.ruusr').and_raise Ruber::YamlSettingsBackend::InvalidSettingsFile, "The file #{base+'.ruusr'} isn\'t a valid option file"
      lambda{Ruber::ProjectBackend.new base}.should raise_error( Ruber::YamlSettingsBackend::InvalidSettingsFile, "The file #{base+'.ruusr'} isn\'t a valid option file")
    end

    it 'doesn\'t raise an exception if the backend for the session raises YamlSettingsBackend::InvalidSettingsFile' do
      file = File.join @dir, 'Test.ruprj'
      base = File.join @dir, 'Test'
      global = Ruber::YamlSettingsBackend.new base
      usr = Ruber::YamlSettingsBackend.new base + '.ruusr'
      dummy = Ruber::YamlSettingsBackend.new ''
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base).and_return(global)
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base + '.ruusr').and_return(usr)
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with('').and_return(dummy)
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base + '.ruses').and_raise Ruber::YamlSettingsBackend::InvalidSettingsFile
      lambda{Ruber::ProjectBackend.new base}.should_not raise_error
    end
    
    it 'emits a warning and use a dummy session backend if the session backend raises YamlSettingsBackend::InvalidSettingsFile' do
      
      class Ruber::ProjectBackend
        alias_method :old_warn, :warn
        def warn arg
          @warning = arg
        end
      end
      
      file= File.join @dir, 'Test.ruprj'
      base = File.join @dir, 'Test'
      global = Ruber::YamlSettingsBackend.new file
      usr = Ruber::YamlSettingsBackend.new base + '.ruusr'
      dummy = Ruber::YamlSettingsBackend.new ''
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(file).and_return(global)
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base + '.ruusr').and_return(usr)
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with(base + '.ruses').and_raise Ruber::YamlSettingsBackend::InvalidSettingsFile
      flexmock(Ruber::YamlSettingsBackend).should_receive(:new).once.with('').and_return(dummy)
      back = Ruber::ProjectBackend.new file
      back.instance_variable_get(:@warning).should == "The file #{base + '.ruses'} already exists but it's not a valid session file. Session options won't be saved"
      back.instance_variable_get(:@backends)[:session].file.should == ''
      
      class Ruber::ProjectBackend
        alias_method :warn, :old_warn
        remove_method :old_warn
      end
      
    end
    
  end
  
  describe '#file' do
    
    it 'returns the file corresponding to the global backend' do
      base = File.join @dir, 'Test.ruprj'
      back = Ruber::ProjectBackend.new base
      back.file.should == back.instance_variable_get(:@backends)[:global].file
    end
    
  end
  
  describe '#[]' do
    
    before do
      @back = Ruber::ProjectBackend.new File.join(@dir, 'Test.ruprj')
    end
    
    it 'calls the #[] method of the global backend if the option is of type global' do
      opt = OS.new(:name => :o, :group => :g, :default => 'x', :type => :global)
      flexmock(@back.instance_variable_get(:@backends)[:global]).should_receive(:[]).with(opt).once.and_return 'y'
      @back[opt].should == 'y'
    end
    
    it 'calls the #[] method of the user backend if the option is of type user' do
      opt = OS.new(:name => :o, :group => :g, :default => 'x', :type => :user)
      flexmock(@back.instance_variable_get(:@backends)[:user]).should_receive(:[]).with(opt).once.and_return 'y'
      @back[opt].should == 'y'
    end
    
    it 'calls the #[] method of the session backend if the option is of type session' do
      opt = OS.new(:name => :o, :group => :g, :default => 'x', :type => :session)
      flexmock(@back.instance_variable_get(:@backends)[:session]).should_receive(:[]).with(opt).once.and_return 'y'
      @back[opt].should == 'y'
    end
    
  end
  
  describe '#write' do
    
    before do
      @back = Ruber::ProjectBackend.new File.join(@dir, 'Test.ruprj')
      @global_options = {
        OS.new(:name => :o1, :group => :G1, :default => 3, :type => :global) => -1,
        OS.new(:name => :o3, :group => :G1, :default => 'a', :type => :global) => 'b'
      }
      @user_options = {
        OS.new(:name => :o2, :group => :G1, :default => 'xyz', :type => :user) => 'abc',
        OS.new(:name => :o4, :group => :G1, :default => /x/, :type => :user) => /y/
      }
      @session_options = {
        OS.new(:name => :o1, :group => :G2, :default => :a, :type => :session) => :b,
        OS.new(:name => :o5, :group => :G2, :default => [1, 2], :type => :session) => [1,2,3]
      }
      @options = @global_options.merge(@user_options).merge(@session_options)
    end
    
    it 'calls the write method of all backends, passing to each a hash with the options of the corresponding type' do
      backs = @back.instance_variable_get(:@backends)
      flexmock(backs[:global]).should_receive(:write).once.with(@global_options)
      flexmock(backs[:user]).should_receive(:write).once.with(@user_options)
      flexmock(backs[:session]).should_receive(:write).once.with(@session_options)
      @back.write @options
    end
    
    it 'doesn\'t attempt to call the write method of the session backend if it\'s dummy' do
      dummy = Ruber::YamlSettingsBackend.new ''
      @back.instance_variable_get(:@backends)[:session] = dummy
      flexmock(dummy).should_receive(:write).never
      @back.write @options
    end
    
  end
  
end