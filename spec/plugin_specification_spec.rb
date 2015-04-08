require 'spec/common'

require 'ruber/plugin_specification'
require 'ruber/plugin'
require 'ruber/plugin_specification_reader'

describe 'Ruber::PluginSpecification.new' do

  it 'should accept a file name and return a PluginSpecification which only contains the pdf intro' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.new 'file'
    res.should be_instance_of(Ruber::PluginSpecification)
    res.should be_intro_only
  end
  
  it 'should accept a hash and return PluginSpecification which only contains the pdf intro' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.new( {} )
    res.should be_instance_of(Ruber::PluginSpecification)
    res.should be_intro_only
  end
  
  it 'should set the "directory" attribute to second argument, if isn\'t nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.new 'file', '/home/stefano/xyz/abc'
    res.directory.should == '/home/stefano/xyz/abc'
  end
  
  it 'should set the "directory" attribute to the directory of the file passed as argument, if the first argument is a string and the second is nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.new '/home/stefano/xyz/abc/plugin.yaml'
    res.directory.should == '/home/stefano/xyz/abc'
  end
  
  it 'should set the "directory" attribute to the current directory if the first argument is a hash and the second is nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.new( {} )
    res.directory.should == File.expand_path( Dir.pwd )
  end
  
  it 'should return a PluginSpecification containing the data in the file' do
    flexmock(File).should_receive(:read).and_return("{:name: :test, about: {:description: desc}}")
    res = Ruber::PluginSpecification.new 'file'
    res.name.should == :test
    res.about.description.should == 'desc'
    res.tool_widgets.should be_nil
  end
  
  it 'should raise PSFError if the :name entry is missing from the pdf' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("description: desc}")
    lambda{Ruber::PluginSpecification.new 'file'}.should raise_error(Ruber::PluginSpecification::PSFError, "The required 'name' entry is missing from the PSF")
  end
  
  it 'should raise SystemCallError if the file doesn\'t exist' do
    lambda{Ruber::PluginSpecification.new 'file'}.should raise_error(SystemCallError)
  end
  
  it 'should raise ArgumentError if the file isn\'t a valid YAML file' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("{:name: test, :description: desc")
    lambda{Ruber::PluginSpecification.new 'file'}.should raise_error(ArgumentError)
  end
  
  it 'should raise Ruber::PluginSpecification::PdfError if the file isn\'t a valid PSF' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("{:description: desc}")
    lambda{Ruber::PluginSpecification.new 'file'}.should raise_error(Ruber::PluginSpecification::PSFError)
  end
  
end

describe 'Ruber::PluginSpecification.intro' do

  it 'should accept a file name and return a PluginSpecification which only contains the pdf intro' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.intro 'file'
    res.should be_instance_of(Ruber::PluginSpecification)
    res.should be_intro_only
  end
  
  it 'should accept a hash a PluginSpecification which only contains the pdf intro' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.intro( {} )
    res.should be_instance_of(Ruber::PluginSpecification)
    res.should be_intro_only
  end
  
  it 'should return a PluginSpecification containing the data in the file' do
    flexmock(File).should_receive(:read).and_return("{:name: :test, about: {:description: desc}}")
    res = Ruber::PluginSpecification.intro 'file'
    res.name.should == :test
    res.about.description.should == 'desc'
    res.tool_widgets.should be_nil
  end
  
  it 'should set the "directory" attribute to second argument, if isn\'t nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.intro 'file', '/home/stefano/xyz/abc'
    res.directory.should == '/home/stefano/xyz/abc'
  end
  
  it 'should set the "directory" attribute to the directory of the file passed as argument, if the first argument is a string and the second is nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.intro '/home/stefano/xyz/abc/plugin.yaml'
    res.directory.should == '/home/stefano/xyz/abc'
  end
  
  it 'should set the "directory" attribute to the current directory if the first argument is a hash and the second is nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.intro( {} )
    res.directory.should == File.expand_path( Dir.pwd )
  end
  
  it 'should raise SystemCallError if the file doesn\'t exist' do
    lambda{Ruber::PluginSpecification.intro 'file'}.should raise_error(SystemCallError)
  end
  
  it 'should raise ArgumentError if the file isn\'t a valid YAML file' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("{:name: test, :description: desc")
    lambda{Ruber::PluginSpecification.intro 'file'}.should raise_error(ArgumentError)
  end
  
  it 'should raise Ruber::PluginSpecification::PdfError if the file isn\'t a valid PSF' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("{:description: desc}")
    lambda{Ruber::PluginSpecification.intro 'file'}.should raise_error(Ruber::PluginSpecification::PSFError)
  end
  
end

describe 'Ruber::PluginSpecification.full' do
  
  it 'should accept a file name and return a PluginSpecification which contains all the contents of the pdf' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.full 'file'
    res.should be_instance_of(Ruber::PluginSpecification)
    res.should_not be_intro_only
  end
  
  it 'should accept a hash a PluginSpecification which only contains the pdf intro' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.full( {} )
    res.should be_instance_of(Ruber::PluginSpecification)
    res.should_not be_intro_only
  end
  
  it 'should return a PluginSpecification containing all the data in the file' do
    Object.const_set(:C, Class.new)
    flexmock(File).should_receive(:read).and_return("{:name: :test, :description: desc, class: C, project_options: {g1: {o1: {default: 5}}}}")
    res = Ruber::PluginSpecification.full 'file'
    res.name.should == :test
    res.project_options[[:g1, :o1]].should have_entries(:name => :o1, :default => 5)
    Object.send(:remove_const, :C)
  end
  
  it 'should set the "directory" attribute to second argument, if isn\'t nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.full 'file', '/home/stefano/xyz/abc'
    res.directory.should == '/home/stefano/xyz/abc'
  end
  
  it 'should set the "directory" attribute to the directory of the file passed as argument, if the first argument is a string and the second is nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(File).should_receive(:read).and_return("{:name: :test}")
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.full '/home/stefano/xyz/abc/plugin.yaml'
    res.directory.should == '/home/stefano/xyz/abc'
  end
  
  it 'should set the "directory" attribute to the current directory if the first argument is a hash and the second is nil' do
    reader = flexmock('reader')
    reader.should_ignore_missing
    flexmock(Ruber::PluginSpecificationReader).should_receive(:new).and_return(reader)
    res = Ruber::PluginSpecification.full( {} )
    res.directory.should == File.expand_path( Dir.pwd )
  end
  
  it 'should raise SystemCallError if the file doesn\'t exist' do
    lambda{Ruber::PluginSpecification.full 'file'}.should raise_error(SystemCallError)
  end
  
  it 'should raise ArgumentError if the file isn\'t a valid YAML file' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("{:name: test, :description: desc")
    lambda{Ruber::PluginSpecification.full 'file'}.should raise_error(ArgumentError)
  end
  
  it 'should raise Ruber::PluginSpecification::PdfError if the file isn\'t a valid PSF' do
    flexmock(File).should_receive(:exist?).and_return true
    flexmock(File).should_receive(:read).and_return("{:description: desc}")
    lambda{Ruber::PluginSpecification.full 'file'}.should raise_error(Ruber::PluginSpecification::PSFError)
  end
  
end

describe 'Ruber::PluginSpecification#complete_processing' do
  
  before :all do
    Object.const_set(:C, Class.new)
  end
  
  after :all do
    Object.send(:remove_const, :C)
  end
  
  it 'should make the object not contain only the pdf introduction' do
    flexmock(File).should_receive(:read).and_return("{:name: :test, :description: desc, class: C}")
    info = Ruber::PluginSpecification.new 'file'
    info.complete_processing
    info.should_not be_intro_only
  end
  
  it 'should contain all the information in the pdf' do
    flexmock(File).should_receive(:read).and_return("{:name: :test, :description: desc, :project_options: {:g1: {o1: {default: 1}}}, class: 'C'}")
    info = Ruber::PluginSpecification.new 'file'
    info.complete_processing
    info.project_options[[:g1, :o1]].should have_entries(:name => :o1, :default => 1, :group => :g1)
  end
  
  it 'should not access the file' do
    flexmock(File).should_receive(:read).and_return("{:name: :test, :description: desc, class: C}").once
    info = Ruber::PluginSpecification.new 'file'
    info.complete_processing
  end
   
end

describe 'Ruber::PluginSpecification#has_config_options?' do
  
  before do
    flexmock(File).should_receive(:read).and_return('{name: x}')
  end
  
  it 'should raise RuntimeError with message "Ruber::PluginSpecification#has_config_options? can only be called on a full Ruber::PluginSpecification"' do
    lambda{Ruber::PluginSpecification.intro('file').has_config_options?}.should raise_error(RuntimeError,"Ruber::PluginSpecification#has_config_options? can only be called on a full Ruber::PluginSpecification")
  end
  
  it 'should return true if the config_options entry isn\'t empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.config_options = {:o1 => OpenStruct.new}
    info.should have_config_options
  end
  
  it 'should return false if the config_options entry is empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.should_not have_config_options
  end
  
end

describe 'Ruber::PluginSpecification#has_config_widgets?' do
  
  before do
    flexmock(File).should_receive(:read).and_return('{name: x}')
  end
  
  it 'should raise RuntimeError with message "Ruber::PluginSpecification#has_config_widgets? can only be called on a full Ruber::PluginSpecification"' do
    lambda{Ruber::PluginSpecification.intro('file').has_config_widgets?}.should raise_error(RuntimeError,"Ruber::PluginSpecification#has_config_widgets? can only be called on a full Ruber::PluginSpecification")
  end
  
  it 'should return true if the config_widgets entry isn\'t empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.config_widgets = [OpenStruct.new]
    info.should have_config_widgets
  end
  
  it 'should return false if the config_widgets entry is empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.should_not have_config_widgets
  end
  
end

describe 'Ruber::PluginSpecification#has_tool_widgets?' do
  
  before do
    flexmock(File).should_receive(:read).and_return('{name: x}')
  end
  
  it 'should raise RuntimeError with message "Ruber::PluginSpecification#has_tool_widgets? can only be called on a full Ruber::PluginSpecification"' do
    lambda{Ruber::PluginSpecification.intro('file').has_tool_widgets?}.should raise_error(RuntimeError,"Ruber::PluginSpecification#has_tool_widgets? can only be called on a full Ruber::PluginSpecification")
  end
  
  it 'should return true if the tool_widgets entry isn\'t empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.tool_widgets = [OpenStruct.new]
    info.should have_tool_widgets
  end
  
  it 'should return false if the tool_widgets entry is empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.should_not have_tool_widgets
  end
  
end

describe 'Ruber::PluginSpecification#has_project_options?' do
  
  before do
    flexmock(File).should_receive(:read).and_return('{name: x}')
  end
  
  it 'should raise RuntimeError with message "Ruber::PluginSpecification#has_project_options? can only be called on a full Ruber::PluginSpecification"' do
    lambda{Ruber::PluginSpecification.intro('file').has_project_options?}.should raise_error(RuntimeError,"Ruber::PluginSpecification#has_project_options? can only be called on a full Ruber::PluginSpecification")
  end
  
  it 'should return true if the project_options entry isn\'t empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.project_options = {:o1 => OpenStruct.new({:name => :o1})}
    info.should have_project_options
  end
  
  it 'should return false if the project_options entry is empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.should_not have_project_options
  end
  
end

describe 'Ruber::PluginSpecification#has_project_widgets?' do
  
  before do
    flexmock(File).should_receive(:read).and_return('{name: x}')
  end
  
  it 'should raise RuntimeError with message "Ruber::PluginSpecification#has_project_widgets? can only be called on a full Ruber::PluginSpecification"' do
    lambda{Ruber::PluginSpecification.intro('file').has_project_widgets?}.should raise_error(RuntimeError,"Ruber::PluginSpecification#has_project_widgets? can only be called on a full Ruber::PluginSpecification")
  end
  
  it 'should return true if the project_widgets entry isn\'t empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.project_widgets = [OpenStruct.new({:caption => :o1})]
    info.should have_project_widgets
  end
  
  it 'should return false if the project_widgets entry is empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.should_not have_project_widgets
  end
  
end

describe 'Ruber::PluginSpecification#has_extensions?' do
  
  before do
    flexmock(File).should_receive(:read).and_return('{name: x}')
  end
  
  it 'should raise RuntimeError with message "Ruber::PluginSpecification#has_extensions? can only be called on a full Ruber::PluginSpecification"' do
    lambda{Ruber::PluginSpecification.intro('file').has_extensions?}.should raise_error(RuntimeError,"Ruber::PluginSpecification#has_extensions? can only be called on a full Ruber::PluginSpecification")
  end
  
  it 'should return true if the project_extensions entry isn\'t empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.extensions = {:e1 => OpenStruct.new({:name => :e1})}
    info.should have_extensions
  end
  
  it 'should return false if the project_extensions entry is empty' do
    info = Ruber::PluginSpecification.full 'file'
    info.should_not have_extensions
  end
  
end
