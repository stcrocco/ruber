require 'spec/common'
require 'facets/random'

require 'ruber/plugin_specification_reader'
require 'ruber/plugin_specification'
require 'ruber/plugin'

module PluginSpecificationReaderSpec
  class C
  end
  
end

module Ruber
  
  describe PluginSpecificationReader do
    
    def random_string len
      a = ('a'..'z').to_a
      len.times.map{a.at_rand}.join
    end
    
    describe '#process_pdf' do
      names = %w[
        name version about features deps runtime_deps ui_file tool_widgets config_widgets config_options project_options project_widgets extensions actions
      ]
      names.insert names.index('ui_file'), ['required', 'required', ['a', 'b']]
      names.insert names.index('ui_file'), %w[class class_obj]
      
      before do
        @info = OpenStruct.new
        @reader = Ruber::PluginSpecificationReader.new @info
        @info.directory = ''
        flexmock(@reader).should_receive(:require).by_default
        names.each do |n| 
          entry, _, value = n.is_a?(Array) ? n : [n, n]
          flexmock(@reader).should_receive("read_#{entry}").by_default.and_return(value || '')
        end
      end
      
      names.each do |n|
        entry, attr, value = n.is_a?(Array) ? n : [n, n]
        it "should return an object whose #{attr} method returns the value returned by calling the read_#{entry} method" do
          name = random_string 5
          value ||= random_string 10
          arg = {:name => name}
          flexmock(@reader).should_receive("read_#{entry}").once.with({:name => name}).and_return value
          @reader.process_pdf(arg).send(attr).should == value
        end
      end
    
      it 'should accept a hash and return the related PluginSpecification' do
        @reader.process_pdf({}).should eql(@info)
      end
      
      it 'requires all files obtained by joining the PluginSpecification\'s directory with the files returned by the read_required method, before calling the read_required method' do
        @info.directory = '/xyz'
        flexmock(@reader).should_receive(:read_required).and_return %w[a b]
        flexmock(@reader).should_receive(:require).globally.ordered.once.with '/xyz/a'
        flexmock(@reader).should_receive(:require).globally.ordered.once.with '/xyz/b'
        flexmock(@reader).should_receive(:read_ui_file).globally.ordered.once.and_return 'testui.rc'
        @reader.process_pdf({})
      end
      
      it 'loads files returned by the read_required method rather than require them if they end in .rb' do
        @info.directory = '/xyz'
        flexmock(@reader).should_receive(:read_required).and_return %w[a b.rb]
        flexmock(@reader).should_receive(:require).globally.ordered.once.with '/xyz/a'
        flexmock(@reader).should_receive(:load).globally.ordered.once.with '/xyz/b.rb'
        flexmock(@reader).should_receive(:read_ui_file).globally.ordered.once.and_return 'testui.rc'
        @reader.process_pdf({})
      end
    
    end
    
  end
  
end

describe 'Ruber::PluginSpecificationReader#process_pdf_intro' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
    flexmock(@reader).should_receive(:read_name).by_default.and_return(:x)
    flexmock(@reader).should_receive(:read_about).by_default.and_return(OpenStruct.new)
    flexmock(@reader).should_receive(:read_version).by_default.and_return('0.0.1')
    flexmock(@reader).should_receive(:read_required).by_default.and_return(['test_file'])
    flexmock(@reader).should_receive(:read_features).by_default.and_return([:p1])
    flexmock(@reader).should_receive(:read_deps).by_default.and_return([])
    flexmock(@reader).should_receive(:read_runtime_deps).by_default.and_return([])
  end
    
  it 'should store the value returned by calling the read_name method with both arguments in the result under the :name key' do
    hash = {}
    flexmock(@reader).should_receive(:read_name).once.with(hash, false).and_return(:x)
    res = @reader.process_pdf_intro({})
    res.name.should == :x
    
    flexmock(@reader).should_receive(:read_name).once.with(hash, true).and_return(:x)
    res = @reader.process_pdf_intro({}, true)
    res.name.should == :x
  end  
  
  it 'should store the value returned by the read_about method under the about key' do
    hash = {:name => :x, :human_name => 'Y'}
    exp = OpenStruct.new({:human_name => 'Y'})
    flexmock(@reader).should_receive(:read_about).once.with(hash).and_return(exp)
    res = @reader.process_pdf_intro(hash)
    res.about.should == exp
  end
  
  it 'should store the value returned by the read_version method under the version key' do
    hash = {:name => :x, :version => '1.2.3'}
    flexmock(@reader).should_receive(:read_version).once.with(hash).and_return('1.2.3')
    res = @reader.process_pdf_intro(hash)
    res.version.should == '1.2.3'
  end
  
  it 'should store the value returned by the read_required method in the result under the :required key' do
    hash = {}
    flexmock(@reader).should_receive(:read_required).once.with(hash).and_return(%w[f1 f2])
    res = @reader.process_pdf_intro hash
    @info.required.should == %w[f1 f2]
    res.required.should == %w[f1 f2]
  end
  
  it 'should store the value returned by the read_features method in the result under the :features key' do
    hash = {}
    flexmock(@reader).should_receive(:read_features).once.with(hash).and_return(%w[f1 f2])
    res = @reader.process_pdf_intro hash
    @info.features.should == %w[f1 f2]
    res.features.should == %w[f1 f2]
  end
  
  it 'should store the value returned by the read_deps method in the result under the :deps key' do
    hash = {}
    flexmock(@reader).should_receive(:read_deps).once.with(hash).and_return([:p1, :p2])
    res = @reader.process_pdf_intro hash
    @info.deps.should == [:p1, :p2]
    res.deps.should == [:p1, :p2]
  end
  
  it 'should store the value returned by the read_runtime_deps method in the result under the :runtime_deps key' do
    hash = {}
    flexmock(@reader).should_receive(:read_runtime_deps).once.with(hash).and_return([:p1, :p2])
    res = @reader.process_pdf_intro hash
    @info.runtime_deps.should == [:p1, :p2]
    res.runtime_deps.should == [:p1, :p2]
  end
  
  it 'should not call the read_class method' do
    flexmock(@reader).should_receive(:read_class).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_ui_file method' do
    flexmock(@reader).should_receive(:read_ui_file).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_tool_widgets method' do
    flexmock(@reader).should_receive(:read_tool_widgets).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_config_widgets method' do
    flexmock(@reader).should_receive(:read_config_widgets).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_config_options method' do
    flexmock(@reader).should_receive(:read_config_options).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_project_options method' do
    flexmock(@reader).should_receive(:read_project_options).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_project_widgets method' do
    flexmock(@reader).should_receive(:read_project_widgets).never
    @reader.process_pdf_intro({})
  end
  
  it 'should not call the read_extensions method' do
    flexmock(@reader).should_receive(:read_extensions).never
    @reader.process_pdf_intro({:name => :x})
  end
  
  it 'should not call the read_actions method' do
    flexmock(@reader).should_receive(:read_actions).never
    @reader.process_pdf_intro({})
  end
  
  
end

describe 'KRuber::PluginSpecificationReader#read_name' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should convert the :name or "name" entry of the input hash to a symbol and insert it in the returned hash under the :name key' do
    @reader.send(:read_name, {:name => :x}).should == :x
    @reader.send(:read_name, {'name' => :x}).should == :x
    @reader.send(:read_name, {:name => 'x'}).should == :x
    @reader.send(:read_name, {'name' => 'x'}).should == :x
  end
  
  it 'should use the :name entry if both the :name and "name" entry exist in the input hash' do
    @reader.send(:read_name, {:name => :x, 'name' => :y}).should == :x
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if a name entry doesn\'t exist in the input hash and the second argument is false' do
    lambda{@reader.send(:read_name, {})}.should raise_error(Ruber::PluginSpecification::PSFError, "The required 'name' entry is missing from the PDF")
  end
  
  it 'should return  nil if the :name/"name" entry doesn\'t exist in the input hash and the second argument is true' do
    @reader.send(:read_name, {}, true).should be_nil
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_description' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should convert the :description or "description" entry of the input hash to a string and insert it in the returned hash under the :description key' do
    @reader.send(:read_description, {:description => :x}).should == 'x'
    @reader.send(:read_description, {'description' => :x}).should == 'x'
    @reader.send(:read_description, {:description => 'x'}).should == 'x'
    @reader.send(:read_description, {'description' => 'x'}).should == 'x'
  end
  
  it 'should use the :description entry if both the :description and "description" entry exist in the input hash' do
    @reader.send(:read_description, {:description => 'x', 'description' => 'y'}).should == 'x'
  end
  
  it 'should return an empty string if neither the :description nor the "description" entries exist in the input hash' do
    @reader.send(:read_description, {}).should == ''
  end
  
end

describe 'Ruber::PluginSpecificationReader#read_class' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return the class corresponding to the :class/"class" entry' do
    @reader.send(:read_class, {:class => 'String'}).should == String
    @reader.send(:read_class, {'class' => :"Ruber::PluginSpecification"}).should == Ruber::PluginSpecification
  end
  
  it 'should use the :class entry if both the :class and "class" entry exist in the input hash' do
    @reader.send(:read_class, {:class => String, 'class' => Array}).should == String
  end
  
  it 'should return Ruber::Plugin if the :class/"class" entry doesn\'t exist' do
    @reader.send(:read_class, {}, true).should == Ruber::Plugin
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_required' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return an array containing the value of the :required or "required" entries of the input hash, converted to a string, if any of those entries is a string or a symbol' do
    [{:require => 'test'}, {:require => :test}, {'require' => 'test'}, {'require' => :test}].each do |h|
      @reader.send(:read_required, h).should == ['test']
    end
  end
  
  it 'should return an array containing the contents of the array in the :requried or "require" entry of the input hash converted to strings if any of those entries is an array' do
    [{:require => ['test1', :test2]}, {'require' => ['test1', :test2]}].each do |h|
      @reader.send(:read_required, h).should == %w[test1 test2]
    end
  end
  
  it 'should use the :require entry if both the :require and "require" entry exist in the input hash' do
    @reader.send(:read_required, {:require => 'f1', 'require' => 'f2'}).should == ['f1']
  end
  
  it 'should return an empty array if neither the :require nor the "require" entries exist in the input hash' do
    @reader.send(:read_required, {}).should == []
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_features' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return an array containing the value of the :features or "features" entries of the input hash, plus the plugin name, converted to a symbol, if any of those entries is a string or a symbol' do
    [{:name => 'x', :features => 'test'}, {:name => 'x', :features => :test}, {:name => 'x', 'features' => 'test'}, {:name => 'x', 'features' => :test}].each do |h|
      @reader.send(:read_features, h).should == [:x, :test]
    end
  end

  it 'should return an array containing the contents of the array in the :requried or "features" entry of the input hash converted to symbols, plus the plugin name, if any of those entries is an array' do
    [{:name => 'x', :features => ['test1', :test2]}, {:name => 'x', 'features' => ['test1', :test2]}].each do |h|
      @reader.send(:read_features, h).should == [:x, :test1, :test2]
    end
  end
  
  it 'should use the :features entry if both the :features and "features" entry exist in the input hash' do
    @reader.send(:read_features, {:name => 'x', :features => 'test1', 'features' => 'test2'}).should == [:x, :test1]
  end
  
  it 'should return an array containing only the plugin name (as symbol) if neither the :features nor the "features" entries exist in the input hash' do
    @reader.send(:read_features, {:name => :test}).should == [:test]
    @reader.send(:read_features, {:name => 'test'}).should == [:test]
  end
  
  it 'should not attempt to add the plugin name if it isn\'t given' do
    @reader.send(:read_features, {}).should == []
    @reader.send(:read_features, {:features => :test}).should == [:test]
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_deps' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return an array containing the value of the :deps or "deps" entries of the input hash, converted to a symbol, if any of those entries is a string or a symbol' do
    [{:deps => 'test'}, {:deps => :test}, {'deps' => 'test'}, {'deps' => :test}].each do |h|
      @reader.send(:read_deps, h).should == [:test]
    end
  end
  
  it 'should return an array containing the contents of the array in the :requried or "deps" entry of the input hash converted to symbols if any of those entries is an array' do
    [{:deps => ['test1', :test2]}, {'deps' => ['test1', :test2]}].each do |h|
      @reader.send(:read_deps, h).should == [:test1, :test2]
    end
  end
  
  it 'should use the :deps entry if both the :deps and "deps" entry exist in the input hash' do
    @reader.send(:read_deps, {:deps => 'test1', 'deps' => 'test2'}).should == [:test1]
  end
  
  it 'should return an empty array if neither the :deps nor the "deps" entries exist in the input hash' do
    @reader.send(:read_deps, {}).should == []
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_runtime_deps' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return an array containing the value of the :runtime_deps or "runtime_deps" entries of the input hash, converted to a symbol, if any of those entries is a string or a symbol' do
    [{:runtime_deps => 'test'}, {:runtime_deps => :test}, {'runtime_deps' => 'test'}, {'runtime_deps' => :test}].each do |h|
      @reader.send(:read_runtime_deps, h).should == [:test]
    end
  end
  
  it 'should return an array containing the contents of the array in the :requried or "runtime_deps" entry of the input hash converted to symbols if any of those entries is an array' do
    [{:runtime_deps => ['test1', :test2]}, {'runtime_deps' => ['test1', :test2]}].each do |h|
      @reader.send(:read_runtime_deps, h).should == [:test1, :test2]
    end
  end
  
  it 'should use the :runtime_deps entry if both the :runtime_deps and "runtime_deps" entry exist in the input hash' do
    @reader.send(:read_runtime_deps, {:runtime_deps => 'test1', 'runtime_deps' => 'test2'}).should == [:test1]
  end
  
  it 'should return an empty array if neither the :runtime_deps nor the "runtime_deps" entries exist in the input hash' do
    @reader.send(:read_runtime_deps, {}).should == []
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_ui_file' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should convert the :ui_file or "ui_file" entry of the input hash to a string and insert it in the returned hash under the :ui_file key' do
    @reader.send(:read_ui_file, {:ui_file => :x}).should == 'x'
    @reader.send(:read_ui_file, {'ui_file' => :x}).should == 'x'
    @reader.send(:read_ui_file, {:ui_file => 'x'}).should == 'x'
    @reader.send(:read_ui_file, {'ui_file' => 'x'}).should == 'x'
  end
  
  it 'should use the :ui_file entry if both the :ui_file and "ui_file" entry exist in the input hash' do
    @reader.send(:read_ui_file, {:ui_file => 'x', 'ui_file' => 'y'}).should == 'x'
  end
  
  it 'should return an empty string if neither the :ui_file nor the "ui_file" entries exist in the input hash' do
    @reader.send(:read_ui_file, {}).should == ''
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_widget' do
  
  before do
    @info = OpenStruct.new({:directory => '/dir', :about => OpenStruct.new(:icon => '')})
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return an OpenStruct with the contents of the :caption  or "caption" entry of the input hash under the :caption key' do
    res = @reader.send(:read_widget, {:caption =>"caption", :class => 'Array'})
    res.caption.should == "caption"
    res.caption.should == "caption"
    res = @reader.send(:read_widget, {'caption' =>"caption", :class => 'Hash'})
    res.caption.should == "caption"
    res.caption.should == "caption"
  end
  
  it 'should return an OpenStruct with the contents of the :pixmap or "pixmap" entry of the input hash, prepended with the plugin directory, under the :pixmap key if the entry is an existing file' do
    flexmock(KDE::Application).should_receive(:instance).and_return true
    flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return true
    res = @reader.send(:read_widget, {:pixmap =>"pixmap", :class => 'Array'})
    res.pixmap.should == '/dir/pixmap'
    res = @reader.send(:read_widget, {'pixmap' =>"pixmap", :class => 'Array'})
    res.pixmap.should == '/dir/pixmap'
  end
  
  it 'should return an OpenStruct with the string obtained passing the contents of the :pixmap/"pixmap" entry of the input hash to KDE::IconLoader.pixmap_path as :pixmap entry if the entry is not an existing file' do
    flexmock(KDE::Application).should_receive(:instance).and_return true
    flexmock(KDE::IconLoader).should_receive(:pixmap_path).with( 'pixmap').twice.and_return '/usr/pixmap'
    res = @reader.send(:read_widget, {:pixmap =>"pixmap", :class => 'Array'})
    res.pixmap.should == '/usr/pixmap'
    res = @reader.send(:read_widget, {'pixmap' =>"pixmap", :class => 'Array'})
    res.pixmap.should == '/usr/pixmap'
  end
  
  it 'should return an OpenStruct with the contents of the :pixmap or "pixmap" entry of the input hash, prepended with the plugin directory, under the :pixmap key if the application doesn\'t exist, even if the file doesn\'t exist' do
    flexmock(KDE::Application).should_receive(:instance).and_return(nil)
    flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return false
    flexmock(KDE::IconLoader).should_receive(:pixmap_path).with( 'pixmap').never
    res = @reader.send(:read_widget, {:pixmap =>"pixmap", :class => 'Array'})
    res.pixmap.should == '/dir/pixmap'
    res = @reader.send(:read_widget, {'pixmap' =>"pixmap", :class => 'Array'})
    res.pixmap.should == '/dir/pixmap'
  end
  
  it 'should return an OpenStruct with an empty string as pixmap entry if the :pixmap/"pixmap" entry of the input hash is not an existing file and KDE::IconLoader can\'t find an icon with that name' do
    flexmock(KDE::IconLoader).should_receive(:pixmap_path).twice.and_return ''
    flexmock(KDE::Application).should_receive(:instance).and_return(true)
    res = @reader.send(:read_widget, {:pixmap =>"pixmap", :class => 'Array'})
    res.pixmap.should == ''
    res = @reader.send(:read_widget, {'pixmap' =>"pixmap", :class => 'Array'})
    res.pixmap.should == ''
  end
    
  it 'should return an OpenStruct with the contents of the :class or "class" entry of the input hash under the :class_obj key' do
    res = @reader.send(:read_widget, {:class => 'Array'})
    res.class_obj.should == Array
    res.class_obj.should == Array
    res = @reader.send(:read_widget, {'class' => 'Array'})
    res.class_obj.should == Array
    res.class_obj.should == Array
  end
  
  it 'should return an OpenStruct with the contents of the :code or "code" entry of the input hash under the :code key' do
    res = @reader.send(:read_widget, {:code =>"C.new"})
    res.code.should == "C.new"
    res.code.should == "C.new"
    res = @reader.send(:read_widget, {'code' =>"C.new"})
    res.code.should == "C.new"
    res.code.should == "C.new"
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if both the :code/"code" and the :class/"class" entries are specified in the input hash' do
    lambda{@reader.send(:read_widget, {:code => "Cls.new", :class =>  'Array'})}.should raise_error(Ruber::PluginSpecification::PSFError, "A widget description can't contain both the :class and the :code entries")
    lambda{@reader.send(:read_widget, {'code' => "Cls.new", :class =>  'Array'})}.should raise_error(Ruber::PluginSpecification::PSFError, "A widget description can't contain both the :class and the :code entries")
    lambda{@reader.send(:read_widget, {:code => "Cls.new", 'class' =>  'Array'})}.should raise_error(Ruber::PluginSpecification::PSFError, "A widget description can't contain both the :class and the :code entries")
    lambda{@reader.send(:read_widget, {'code' => "Cls.new", 'class' =>  'Array'})}.should raise_error(Ruber::PluginSpecification::PSFError, "A widget description can't contain both the :class and the :code entries")
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if neither the :class/"class" nor the :code/"code" entries exist in the input hash' do
    lambda{@reader.send(:read_widget, {})}.should raise_error(Ruber::PluginSpecification::PSFError, "Either the :class or the :code entry must be present in the widget description")
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if the second argument includes :caption and the :caption/"caption" entry doesn\'t exist in the input hash' do
    lambda{@reader.send(:read_widget, {:class => 'Array'}, [:caption])}.should raise_error(Ruber::PluginSpecification::PSFError, "The :caption entry must be present in the widget description")
  end
  
  it 'should use "" as caption if the :caption/"caption" is not included in the input hash' do
    @reader.send(:read_widget, {:class => 'Array'}).caption.should == ''
  end
  
  it 'should use the plugin icon if the pixmap entry doesn\'t exist' do
    @info.about.icon = '/usr/test.png'
    @reader.send(:read_widget, {:class => 'Array'}).pixmap.should == '/usr/test.png'
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if the second argument includes :pixmap, the pixmap entry doesn\'t exist in the input hash and the plugin icon is empty' do
    @info.about.icon = ''
    lambda{@reader.send(:read_widget, {:class => 'Array'}, [:pixmap])}.should raise_error(Ruber::PluginSpecification::PSFError, "The :pixmap entry must be present in the widget description")
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_tool_widgets' do
  
  before do
    @info = OpenStruct.new({:directory => '/dir'})
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should pass the :tool_widgets/"tool_widgets" entry to the read_widget method and return an array containing the returned value if the :tool_widgets/"tool_widgets" entry is an hash' do
    widget_hashes = [ 
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => :bottom},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'position' => :bottom},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'position' => :bottom},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => 'bottom'}
    ]
    widget_hashes.each do |h|
      exp = {:class => Array, :pixmap => 'pix', :caption => 'caption'}
      ost = OpenStruct.new( exp)
      flexmock(@reader).should_receive(:read_widget).once.with(h, Array).and_return( ost )
      res = @reader.send(:read_tool_widgets, {:tool_widgets => h})
      res.should be_instance_of(Array)
      res.size.should == 1
      res[0].should eql(ost)
    end
  end
  
  it 'should pass each item in the :tool_widgets or "tool_widgets" entry to the read_widget method and return an array of the returned values if the :tool_widgets/"tool_widgets" entry is an array' do
    widget_hashes = [ 
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => :bottom},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'position' => :bottom},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'position' => :bottom},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => 'bottom'}
    ]
    widget_hashes.each do |h|
      exp = {:class => Array, :pixmap => 'pix', :caption => 'caption'}
      ost = OpenStruct.new( exp)
      flexmock(@reader).should_receive(:read_widget).twice.with(h, Array).and_return( ost )
      res = @reader.send(:read_tool_widgets, {:tool_widgets => [h, h]})
      res.should be_instance_of(Array)
      res.size.should == 2
      res[0].should eql(ost)
      res[1].should eql(ost)
    end
  end
  
  it 'should add the value of the :position/"position" entry of the original hash, converted to a symbol, to the values returned by the read_widget method, under the :position key' do
    widget_hashes = [ 
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => :top},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'position' => :left},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'position' => :right},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => 'bottom'}
    ]
    widget_hashes.each do |h|
      exp = {:class => 'Array', :pixmap => 'pix', :caption => 'caption'}
      flexmock(@reader).should_receive(:read_widget).twice.with(h, Array).and_return( OpenStruct.new(exp) )
      @reader.send(:read_tool_widgets, {:tool_widgets => [h, h]}).each do |w|
        w.position.should == (h[:position]||h["position"]).to_sym
      end
    end
  end
  
  it 'should add the value of the :name/"name" entry of the original hash, converted to a string, to the values returned by the read_widget method, under the :name key' do
    widget_hashes = [ 
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :name => :w},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'name' => :w},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'name' => :w},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :name=> 'w'}
    ]
    widget_hashes.each do |h|
      exp = {:class => 'Array', :pixmap => 'pix', :caption => 'caption'}
      flexmock(@reader).should_receive(:read_widget).twice.with(h, Array).and_return( OpenStruct.new(exp) )
      @reader.send(:read_tool_widgets, {:tool_widgets => [h, h]}).each do |w|
        w.name.should == (h[:name]||h["name"]).to_s
      end
    end
  end
  
  it 'should add the value of the :variable_name/"variable_name" entry of the original hash, converted to a string, to the values returned by the read_widget method, under the :var_name key' do
    widget_hashes = [ 
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :var_name => :w},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'var_name' => :w},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', 'var_name' => :w},
      {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :var_name=> 'w'}
    ]
    widget_hashes.each do |h|
      exp = {:class => 'Array', :pixmap => 'pix', :caption => 'caption'}
      flexmock(@reader).should_receive(:read_widget).twice.with(h, Array).and_return( OpenStruct.new(exp) )
      @reader.send(:read_tool_widgets, {:tool_widgets => [h, h]}).each do |w|
        w.var_name.should == (h[:var_name]||h["var_name"]).to_s
      end
    end
  end
  
  it 'should use the :tool_widgets entry if both the :tool_widgets and "tool_widgets" entry exist in the input hash' do
    widget_hash1 = {:class => 'Array', :pixmap => 'pix', :caption => 'caption', :position => :bottom}
    widget_hash2 = {:class => 'Test1'}
    exp = {:class_obj => Array, :pixmap => 'pix', :caption => 'caption'}
    flexmock(@reader).should_receive(:read_widget).once.with(widget_hash1, Array).and_return OpenStruct.new(exp)
    res = @reader.send(:read_tool_widgets, {:tool_widgets => widget_hash1, "tool_widgets" => widget_hash2})[0].class_obj.should == Array
  end
  
  it 'should return an empty array if neither the :tool_widgets nor the "tool_widgets" entry exist in the input hash' do
    @reader.send(:read_tool_widgets, {}).should == []
  end
  
  it 'should pass the array [:pixmap, :caption] as second argument of the read_widget method' do
    flexmock(@reader).should_receive(:read_widget).twice.with(Hash, [:pixmap, :caption]).and_return( OpenStruct.new )
    @reader.send(:read_tool_widgets, {:tool_widgets => [{:position => :left}]})
    @reader.send(:read_tool_widgets, {:tool_widgets => {:position => :right}})
  end
  
  it 'should use :bottom as default value if neither the :position nor the "position" entry exist for a hash' do
    flexmock(@reader).should_receive(:read_widget).and_return( OpenStruct.new)
    @reader.send(:read_tool_widgets, {:tool_widgets => [{}]})[0].position.should == :bottom
    @reader.send(:read_tool_widgets, {:tool_widgets => {}})[0].position.should == :bottom
  end
  
  it 'uses the caption as default value for the :name/"name" entry' do
    flexmock(@reader).should_receive(:read_widget).and_return OpenStruct.new(:caption => 'Abc def')
    @reader.send(:read_tool_widgets, {:tool_widgets => [{}]})[0].name.should == "Abc def"
    @reader.send(:read_tool_widgets, {:tool_widgets => {}})[0].name.should == "Abc def"
  end
  
  it 'should use "widget" as default value for the :var_name/"var_name" entry if the entry doesn\'t exist' do
    flexmock(@reader).should_receive(:read_widget).and_return( OpenStruct.new)
    @reader.send(:read_tool_widgets, {:tool_widgets => [{}]})[0].var_name.should == "widget"
    @reader.send(:read_tool_widgets, {:tool_widgets => {}})[0].var_name.should == "widget"
  end
  
  it 'should use nil as default value for the :var_name/"var_name" entry if the entry is nil' do
    flexmock(@reader).should_receive(:read_widget).and_return( OpenStruct.new)
    @reader.send(:read_tool_widgets, {:tool_widgets => [{:var_name => nil}]})[0].var_name.should be_nil
    @reader.send(:read_tool_widgets, {:tool_widgets => {:var_name => nil}})[0].var_name.should be_nil
  end

end

describe 'KRuber::PluginSpecificationReader#read_config_widgets' do
  
  before do
    @info = OpenStruct.new({:directory => '/dir', :about => OS.new(:icon => '') })
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should call the read_widget method passing as first argument the :config_widgets/"config_widgets" entry and return its return value put in an array, when the :config_widgets/"config_widgets" entry is not an array' do
    hashes = [
      {:config_widgets => {}},
      {'config_widgets' => {}}
      ]
    exp = [{:class => 'Array'}, {:class => 'Array'}]
    flexmock(@reader).should_receive(:read_widget).once.with(hashes[0][:config_widgets], Array).and_return(OpenStruct.new(exp[0]))
    flexmock(@reader).should_receive(:read_widget).once.with(hashes[1]['config_widgets'], Array).and_return(OpenStruct.new(exp[1]))
    @reader.send(:read_config_widgets,hashes[0]).should == [OpenStruct.new(exp[0])]
    @reader.send(:read_config_widgets,hashes[1]).should == [OpenStruct.new(exp[1])]
  end
  
  it 'should call the read_widget method for each element of the :config_widgets/"config_widgets" entry and return an array with all the return values, when the :config_widgets/"config_widgets" is an array' do
    hashes = [
      {:config_widgets =>  [{:class => 'Array'}, {:class => 'Ruber::PluginSpecification'}]},
      {'config_widgets' => [{:class => 'Ruber::PluginSpecification'}, {:class => 'Array'}]}
    ]
    exp = [{:class => 'Array'}, {:class => 'Ruber::PluginSpecification'}, {:class => 'Ruber::PluginSpecification'}, {:class => 'Array'}]
    2.times{|i| flexmock(@reader).should_receive(:read_widget).once.with(hashes[0][:config_widgets][i], Array).and_return(OpenStruct.new(exp[i]))}
    2.times{|i| flexmock(@reader).should_receive(:read_widget).once.with(hashes[1]['config_widgets'][i], Array).and_return(OpenStruct.new(exp[2 + i]))}
    @reader.send(:read_config_widgets,hashes[0]).should == [OpenStruct.new(exp[0]), OpenStruct.new(exp[1])]
    @reader.send(:read_config_widgets,hashes[1]).should == [OpenStruct.new(exp[2]), OpenStruct.new(exp[3])]
  end
  
  it 'should use the :config_widgets, if both the :config_widgets and the "config_widgets" entries exist in the input hash' do
    hash = {:config_widgets => {:class => 'Array'}, "config_widgets" => {:class => 'B'}}
    flexmock(@reader).should_receive(:read_widget).once.with(hash[:config_widgets], Array)
    flexmock(@reader).should_receive(:read_widget).never.with(hash['config_widgets'], Array)
    @reader.send(:read_config_widgets, hash)
  end
  
  it 'should raise Ruber::PluginSpecification::PSFError if the caption is not specified for one widget' do
    lambda{@reader.send(:read_config_widgets, {:config_widgets => {:class => 'Array'}})}.should raise_error(Ruber::PluginSpecification::PSFError, "The :caption entry must be present in the widget description")
    lambda{@reader.send(:read_config_widgets, {:config_widgets => [{:class => 'Array'}, {:class => 'Array', :caption => 'c'}]})}.should raise_error(Ruber::PluginSpecification::PSFError, "The :caption entry must be present in the widget description")
  end
  
  it 'should return an empty array if the :config_widgets/"config_widgets" entry doesn\'t exist in the input hash' do
    @reader.send(:read_config_widgets, {}).should == []
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_config_options' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
    @data = {
      :config_options => { 
                          :G1 => { 
                                  :o1 => {:default => 3},
                                  'o2' => {:default => 'abc'}
                                 },
                          'G2' => {
                                   :o1 => {:default => :xyz},
                          :o3 => {:default => %w[a b c]}
                                  }
                         } 
    }
    
  end
  
  it 'should return a Hash' do
    @reader.send(:read_config_options, {:config_options => {}}).should be_instance_of( Hash )
  end
  
  it 'should call the read_config_option method for each entry in each group in the :config_options/"config_options" entry' do
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o1, {:default => 3})
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o2, {:default => 'abc'})
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o1, {:default => :xyz})
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o3, {:default => %w[a b c]})
    @reader.send(:read_config_options, @data)
    data = {
      'config_options' => { 
                          :G1 => { 
                                  :o1 => {:default => 3},
                                  'o2' => {:default => 'abc'}
                                 },
                          'G2' => {
                                    :o1 => {:default => :xyz},
                                    :o3 => {:default => %w[a b c]}
                                  }
                         } 
    }
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o1, {:default => 3})
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o2, {:default => 'abc'})
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o1, {:default => :xyz})
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o3, {:default => %w[a b c]})
    @reader.send(:read_config_options, data)
  end
  
  it 'should store the value returned by each call to read_config_option under the [group, name] key in the returned hash, with group and name converted to a symbol' do
    h = @data[:config_options]
    exp = {
      [:G1, :o1] => h[:G1][:o1],
      [:G1, :o2] => h[:G1][:o2],
      [:G2, :o1] => h['G2'][:o1],
      [:G2, :o3] => h['G2'][:o3]
      }
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o1, {:default => 3}).and_return exp[[:G1, :o1]]
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o2, {:default => 'abc'}).and_return exp[[:G1, :o2]]
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o1, {:default => :xyz}).and_return exp[[:G2, :o1]]
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o3, {:default => %w[a b c]}).and_return exp[[:G2, :o3]]
    @reader.send(:read_config_options, @data).should == exp
  end
    
  it 'should use the :config_options entry if both the :config_options and the "config_options" entries exist in the input hash' do
    data = {:config_options => {:G1 => {:o1 => {:default => 3}}}, 'config_options' => {:G2 => {:o2 => {:default => 5}}}}
    flexmock(@reader).should_receive(:read_option).with(:G1, :o1, {:default => 3}).once
    flexmock(@reader).should_receive(:read_option).with(:G2, :o2, {:default => 5}).never
    @reader.send(:read_config_options, data)
  end
  
  it 'should return an empty hash if the :config_options/"config_options" entry doesn\'t exist in the input hash' do
    @reader.send(:read_config_options, {}).should == {}
  end
  
end

describe 'KRuber::PluginSpecificationReader#read_project_options' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
    @data = {
      :project_options => { 
                          :G1 => { 
                                  :o1 => {:default => 3},
                                  'o2' => {:default => 'abc'}
                                 },
                          'G2' => {
                                   :o1 => {:default => :xyz},
                          :o3 => {:default => %w[a b c]}
                                  }
                         } 
    }
    
  end
  
  it 'should return a Hash' do
    @reader.send(:read_project_options, {:project_options => {}}).should be_instance_of( Hash )
  end
  
  it 'should call the read_option method for each entry in each group in the :project_options/"project_options" entry' do
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o1, {:default => 3}).and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o2, {:default => 'abc'}).and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o1, {:default => :xyz}).and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o3, {:default => %w[a b c]}).and_return(OS.new)
    @reader.send(:read_project_options, @data)
    data = {
      'project_options' => { 
                          :G1 => { 
                                  :o1 => {:default => 3},
                                  'o2' => {:default => 'abc'}
                                 },
                          'G2' => {
                                    :o1 => {:default => :xyz},
                                    :o3 => {:default => %w[a b c]}
                                  }
                         } 
    }
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o1, {:default => 3}).and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o2, {:default => 'abc'}).and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o1, {:default => :xyz}).and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o3, {:default => %w[a b c]}).and_return(OS.new)
    @reader.send(:read_project_options, data)
  end
  
  it 'should store the value returned by each call to read_config_option under the [group, name] key in the returned hash, with group and name converted to a symbol' do
    h = @data[:project_options]
    exp = {
      [:G1, :o1] => h[:G1][:o1],
      [:G1, :o2] => h[:G1]['o2'],
      [:G2, :o1] => h['G2'][:o1],
      [:G2, :o3] => h['G2'][:o3]
      }
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o1, {:default => 3}).and_return OS.new(exp[[:G1, :o1]])
    flexmock(@reader).should_receive(:read_option).once.with(:G1, :o2, {:default => 'abc'}).and_return OS.new(exp[[:G1, :o2]])
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o1, {:default => :xyz}).and_return OS.new(exp[[:G2, :o1]])
    flexmock(@reader).should_receive(:read_option).once.with(:G2, :o3, {:default => %w[a b c]}).and_return OS.new(exp[[:G2, :o3]])
    res = @reader.send(:read_project_options, @data)
    res.size.should == exp.size
    res.each_pair do |k, v|
      e = exp[k]
      v.default.should == e[:default]
    end
  end
  
  it 'merges the object returned by read_option with the hash returned by read_rules' do
    data = {:project_options => {:g1 => {:o1 => {:default => 1, :file_extension => '*.rb', :scope => :global}}}}
    exp = OS.new(:default => 1, :group => :g1, :name => :o1)
    flexmock(@reader).should_receive(:read_option).once.with(:g1, :o1, {:default => 1, :file_extension => '*.rb', :scope => :global}).and_return exp
    flexmock(@reader).should_receive(:read_rules).once.with({:default => 1, :file_extension => '*.rb', :scope => :global}).and_return({:file_extension => ['*.rb'], :scope => [:global], :mimetype => []})
    res = @reader.send(:read_project_options, data)
    res[[:g1, :o1]].scope.should == [:global]
    res[[:g1, :o1]].file_extension.should == ['*.rb']
    res[[:g1, :o1]].mimetype.should == []
  end
  
  it 'should add the "type" attribute to the object returned by read_option and set it to the type entry of the hash, converted into a symbol' do
    h = @data[:project_options]
    h[:G1][:o1][:type] = :global
    h[:G1]["o2"][:type] = "user"
    h["G2"][:o1]["type"] = :session
    h["G2"][:o3]["type"] = "global"  
    res = @reader.send(:read_project_options, @data)
    res[[:G1, :o1]].type.should == :global
    res[[:G1, :o2]].type.should == :user
    res[[:G2, :o1]].type.should == :session
    res[[:G2, :o3]].type.should == :global
  end

  it 'should use :global as default value for the type attribute' do
    res = @reader.send(:read_project_options, @data)
    res[[:G1, :o1]].type.should == :global
  end
  
    
  it 'should use the :project_options entry if both the :project_options and the "project_options" entries exist in the input hash' do
    data = {:project_options => {:G1 => {:o1 => {:default => 3}}}, 'project_options' => {:G2 => {:o2 => {:default => 5}}}}
    flexmock(@reader).should_receive(:read_option).with(:G1, :o1, {:default => 3}).once.and_return(OS.new)
    flexmock(@reader).should_receive(:read_option).with(:G2, :o2, {:default => 5}).never
    @reader.send(:read_project_options, data)
  end
  
  it 'should return an empty hash if the :project_options/"project_options" entry doesn\'t exist in the input hash' do
    @reader.send(:read_project_options, {}).should == {}
  end

end

describe 'Ruber::PluginSpecificationReader#read_option' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return a Ruber::PluginSpecificationReader::Option object' do
    @reader.send(:read_option, :G1, :o1, {}).should be_a(Ruber::PluginSpecificationReader::Option)
  end
  
  it 'should use the first argument as the "group" attribute of the returned value, after converting it to a symbol' do
    @reader.send(:read_option, :G1, :o1, {}).group.should == :G1
    @reader.send(:read_option, 'G1', :o1, {}).group.should == :G1
  end
  
  it 'should use the first argument as the "name" attribute of the returned value, after converting it to a symbol' do
    @reader.send(:read_option, :G1, :o1, {}).name.should == :o1
    @reader.send(:read_option, :G1, 'o1', {}).name.should == :o1
  end
  
  it 'should use the :relative_path/"relative_path" entry of the second argument as "relative_path" attribute of the returned object, if it exists in the second argument' do
    @reader.send(:read_option, :G1, :o1, {:relative_path => true}).relative_path.should be_true
    @reader.send(:read_option, :G1, :o1, {:relative_path => false}).relative_path.should_not be_true
    @reader.send(:read_option, :G1, :o1, {'relative_path' => true}).relative_path.should be_true
    @reader.send(:read_option, :G1, :o1, {'relative_path' => false}).relative_path.should_not be_true
  end
  
  it 'should use false as "relative_path" attribute for the returned object if the :relative_path/"relative_path" entry doesn\'t exist in the returned object' do
    @reader.send(:read_option, :G1, :o1, {}).relative_path.should be_false
  end
  
  it 'should use the :default/"default" entry of the second argument as "default" attribute of the returned object if the entry exists' do
    @reader.send(:read_option, :G1, :o1, {:default => 3}).instance_variable_get(:@table)[:default].should == 3
    @reader.send(:read_option, :G1, :o1, {'default' => 3}).instance_variable_get(:@table)[:default].should == 3
    @reader.send(:read_option, :G1, :o1, {:default => false}).instance_variable_get(:@table)[:default].should == false
    @reader.send(:read_option, :G1, :o1, {'default' => false}).instance_variable_get(:@table)[:default].should == false
    @reader.send(:read_option, :G1, :o1, {:default => true}).instance_variable_get(:@table)[:default].should == true
    @reader.send(:read_option, :G1, :o1, {'default' => true}).instance_variable_get(:@table)[:default].should == true
    @reader.send(:read_option, :G1, :o1, {:default => 'x'}).instance_variable_get(:@table)[:default].should == 'x'
    @reader.send(:read_option, :G1, :o1, {'default' => 'x'}).instance_variable_get(:@table)[:default].should == 'x'
  end
  
  it 'should use an emtpy string as "default" attribute of the returned object if the :default/"default" entry doesn\'t exist in the second argument' do
    @reader.send(:read_option, :G1, :o1, {}).instance_variable_get(:@table)[:default].should == ''
  end
  
  it 'should set the eval_default entry of the returned object to the value of the "eval_default" entry' do
    @reader.send(:read_option, :G1, :o1, {:eval_default => false}).eval_default.should be_false
  end
  
  it 'should use true as default value for the eval_default entry' do
    @reader.send(:read_option, :G1, :o1, {}).eval_default.should be_true
  end
  
  it 'uses the order entry of the second argument as order attribute of the returned object' do
    @reader.send(:read_option, :G1, :o1, {:order => 3}).order.should == 3
    @reader.send(:read_option, :G1, :o1, {'order' => 4}).order.should == 4
  end
  
  it 'uses nil as the default value for the order entry' do
    @reader.send(:read_option, :G1, :o1, {}).order.should be_nil
  end
  
end

describe 'Ruber::PluginSpecificationReader#read_project_widgets' do
  
  before do
    @info = OpenStruct.new({:directory => '/dir', :about => OS.new(:icon => '')})
    @reader = Ruber::PluginSpecificationReader.new @info
  end

  it 'should call the read_widget method passing as first argument the :project_widgets/"project_widgets" entry and return its return value put in an array, when the :project_widgets/"project_widgets" entry is not an array' do
      hashes = [
        {:project_widgets => {}},
        {'project_widgets' => {}}
        ]
      exp = [{:class => 'Array', :scope => [:global], :file_extension => [], :mimetype => []}, {:class => 'C2', :scope => [:global], :file_extension => [], :mimetype => []}]
      flexmock(@reader).should_receive(:read_widget).once.with(hashes[0][:project_widgets], Array).and_return(OpenStruct.new(exp[0]))
      flexmock(@reader).should_receive(:read_widget).once.with(hashes[1]['project_widgets'], Array).and_return(OpenStruct.new(exp[1]))
      @reader.send(:read_project_widgets,hashes[0]).should == [OpenStruct.new(exp[0])]
      @reader.send(:read_project_widgets,hashes[1]).should == [OpenStruct.new(exp[1])]
    end
    
    it 'should call the read_widget method for each element of the :project_widgets/"project_widgets" entry and return an array with all the return values, when the :project_widgets/"project_widgets" is an array' do
      hashes = [
        {:project_widgets =>  [{:class => 'Array'}, {:class => 'Ruber::PluginSpecification'}]},
        {'project_widgets' => [{:class => 'Ruber::PluginSpecificationReader'}, {:class => 'Array'}]}
      ]
      exp = [
        {:class_obj => Array, :scope => [:global], :file_extension => [], :mimetype => []}, 
        {:class_obj => Ruber::PluginSpecification, :scope => [:global], :file_extension => [], :mimetype => []},
        {:class_obj => Ruber::PluginSpecificationReader, :scope => [:global], :file_extension => [], :mimetype => []},
        {:class_obj => Array, :scope => [:global], :file_extension => [], :mimetype => []}
      ]
      2.times{|i| flexmock(@reader).should_receive(:read_widget).once.with(hashes[0][:project_widgets][i], Array).and_return(OpenStruct.new(exp[i]))}
      2.times{|i| flexmock(@reader).should_receive(:read_widget).once.with(hashes[1]['project_widgets'][i], Array).and_return(OpenStruct.new(exp[2 + i]))}
      @reader.send(:read_project_widgets,hashes[0]).should == [OpenStruct.new(exp[0]), OpenStruct.new(exp[1])]
      @reader.send(:read_project_widgets,hashes[1]).should == [OpenStruct.new(exp[2]), OpenStruct.new(exp[3])]
    end
    
    it 'calls the read_rules method for each widget and merges the returned hash with the widget\'s data' do
      data = {
        :project_widgets => [
                             {:class => Qt::CheckBox, :scope => :global, :caption => 'x'},
                             {:class => Qt::LineEdit, :scope => :document, :mimetype => 'application/x-ruby', :caption => 'y'}
                             ]
        }
      flexmock(@reader).should_receive(:read_rules).once.with(data[:project_widgets][0]).and_return({:scope => [:global], :file_extension => [], :mimetype => []})
      flexmock(@reader).should_receive(:read_rules).once.with(data[:project_widgets][1]).and_return({:scope => [:document], :file_extension => [], :mimetype => ['application/x-ruby']})
      res = @reader.send(:read_project_widgets, data)
      res[0].scope.should == [:global]
      res[0].file_extension.should == []
      res[0].mimetype.should == []
      res[1].scope.should == [:document]
      res[1].file_extension.should == []
      res[1].mimetype.should == ['application/x-ruby']
    end
    
    it 'should use the :project_widgets, if both the :project_widgets and the "project_widgets" entries exist in the input hash' do
      hash = {:project_widgets => {:class => 'A'}, "project_widgets" => {:class => 'B'}}
      flexmock(@reader).should_receive(:read_widget).once.with(hash[:project_widgets], Array).and_return(OpenStruct.new)
      flexmock(@reader).should_receive(:read_widget).never.with(hash['project_widgets'], Array)
      @reader.send(:read_project_widgets, hash)
    end
    
    it 'should raise Ruber::PluginSpecification::PSFError if the caption is not specified for one widget' do
      lambda{@reader.send(:read_project_widgets, {:project_widgets => {:class => 'Array'}})}.should raise_error(Ruber::PluginSpecification::PSFError, "The :caption entry must be present in the widget description")
      lambda{@reader.send(:read_project_widgets, {:project_widgets => [{:class => 'Array'}, {:class => 'Array', :caption => 'c'}]})}.should raise_error(Ruber::PluginSpecification::PSFError, "The :caption entry must be present in the widget description")
    end
    
    it 'should return an empty array if the :project_widgets/"project_widgets" entry doesn\'t exist in the input hash' do
      @reader.send(:read_project_widgets, {}).should == []
    end
  
end

describe 'Ruber::PluginSpecificationReader#read_extensions' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end
  
  it 'should return a Hash' do
    @reader.send(:read_extensions, {}).should be_instance_of(Hash)
  end
  
  it 'should call the read_extension method for each entry in the :extensions/"project_extensions" entry in the input hash and store the returned value under the same key, converted to a symbol, in the returned hash' do
    hash = {:extensions => {:e1 => {:class => 'Array'}, 'e2' => {:class => 'Ruber::PluginSpecification'}}}
    flexmock(@reader).should_receive(:read_extension).once.with(:e1, {:class => 'Array'}).and_return OpenStruct.new({:class_obj => Array})
    flexmock(@reader).should_receive(:read_extension).once.with(:e2, {:class => 'Ruber::PluginSpecification'}).and_return OpenStruct.new({:class_obj => Ruber::PluginSpecification})
    res = @reader.send(:read_extensions, hash)
    res.size.should == 2
    res[:e1].should have_entries(:class_obj => Array)
    res[:e2].should have_entries(:class_obj => Ruber::PluginSpecification)
    hash = {'extensions' => {:e1 => {:class => 'Array'}, 'e2' => {:class => 'Ruber::PluginSpecification'}}}
    flexmock(@reader).should_receive(:read_extension).once.with(:e1, {:class => 'Array'}).and_return OpenStruct.new({:class_obj => Array})
    flexmock(@reader).should_receive(:read_extension).once.with(:e2, {:class => 'Ruber::PluginSpecification'}).and_return OpenStruct.new({:class_obj => Ruber::PluginSpecification})
    res = @reader.send(:read_extensions, hash)
    res.size.should == 2
    res[:e1].should have_entries(:class_obj => Array)
    res[:e2].should have_entries(:class_obj => Ruber::PluginSpecification)
  end
  
  it 'should return an empty hash if the :extensions/"project_extensions" entry doesn\'t exist in the input hash' do
    @reader.send(:read_extensions, {}).should == {}
  end
  
end

describe 'Ruber::PluginSpecificationReader#read_extension' do
  
  before do
    @info = OpenStruct.new
    @reader = Ruber::PluginSpecificationReader.new @info
  end

  describe ', when the second argument is a hash' do
  
    it 'should return an OpenStruct' do
      @reader.send(:read_extension, :e, {:class => 'Array'}).should be_instance_of(OpenStruct)
    end
    
    it 'should use the first argument as "name" attribute for the returned object' do
      @reader.send(:read_extension, :e, {:class => 'Array'}).name.should == :e
    end
    
    it 'should use the :class/"class" entry of the second argument as "class_name" attribute for the returned object' do
      @reader.send(:read_extension, :e, {:class => 'Array'}).class_obj.should == Array
    end
    
    it 'calls read_rules and stores the value it returns in the returned object' do
      res = @reader.send(:read_extension, :e, {:class => 'Array', :scope => :global, :file_extension => '*.rb'})
      res.scope.should == [:global]
      res.mimetype.should == []
      res.file_extension.should == ['*.rb']
    end
    
    it 'should raise Ruber::PluginSpecification::PSFError if the :class/"class" entry doesn\'t exist in the second argument' do
      lambda{@reader.send(:read_extension, :e, {})}.should raise_error(Ruber::PluginSpecification::PSFError, "The required 'class' entry is missing from the PDF")
    end
    
  end
  
  describe ', when the second argument is a array' do
    
    it 'returns an array' do
      @reader.send(:read_extension, :e, [{:class => 'Array'}, {:class => 'String'}]).should be_a(Array)
    end
    
    it 'calls the read_extension method once for each element of the array, passing it the first argument and the element itself and puts the result in the returned array' do
      res = @reader.send(:read_extension, :e, [{:class => 'Array', :scope => :global}, {:class => 'String', :file_extension => '*.xyz'}])
      res[0].should have_entries(:class_obj => Array, :scope => [:global], :name => :e)
      res[1].should have_entries(:class_obj => String, :file_extension => ['*.xyz'], :name => :e)
    end
    
  end
  
end

describe Ruber::PluginSpecificationReader do
  
  describe '#read_action' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return an OpenStruct' do
      @reader.send(:read_action, 'xyz', {}).should be_an(OpenStruct)
    end
    
    it 'should store the first argument in the name attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {}).name.should == 'xyz'
    end

    it 'should store the content of the text entry in the text attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:text => 'Abc'}).text.should == 'Abc'
    end
    
    it 'should use an empty string as default value for the text entry' do
      @reader.send(:read_action, 'xyz', {}).text.should == ''
    end
    
    it 'should create a KDE::Shortcut from the shortcut entry and store it in the shortuct attribute of the returned object' do
      short = @reader.send(:read_action, 'xyz', {:shortcut => 'Ctrl+S'}).shortcut
      short.should be_a(KDE::Shortcut)
      short.to_string.should == 'Ctrl+S'
    end
    
    it 'should use nil as default value for the shortcut entry' do
      @reader.send(:read_action, 'xyz', {}).shortcut.should be_nil
    end

    it 'should store the content of the help entry in the help attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:help => 'Abc'}).help.should == 'Abc'
    end
    
    it 'should use an empty string as default value for the help entry' do
      @reader.send(:read_action, 'xyz', {}).help.should == ''
    end
    
    it 'should store the pixmap entry, prepended with the plugin directory, under the icon entry of the returned object if the file exists' do
      @reader.instance_variable_get(:@plugin_info).directory = '/dir'
      flexmock(KDE::Application).should_receive(:instance).and_return true
      flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return true
      @reader.send(:read_action, 'xyz', {:icon =>"pixmap"}).icon.should == '/dir/pixmap'
    end
    
    it 'should store the path returned by KDE::IconLoader.pixmap_path when called with the icon entry, under the icon entry of the returned object if the file doesn\'t exist in the plugin directory' do
      @reader.instance_variable_get(:@plugin_info).directory = '/dir'
      flexmock(KDE::IconLoader).should_receive(:pixmap_path).with( 'pixmap').once.and_return '/usr/pixmap'
      flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return false
      @reader.send(:read_action, 'xyz', {:icon =>"pixmap"}).icon.should == '/usr/pixmap'
    end
    
    it 'should store the pixmap entry, prepended with the plugin directory, under the icon entry of the returned object if the file doesn\'t exist but the application object hasn\'t been created yet' do
      @reader.instance_variable_get(:@plugin_info).directory = '/dir'
      flexmock(KDE::Application).should_receive(:instance).and_return nil
      flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return false
      flexmock(KDE::IconLoader).should_receive(:pixmap_path).never
      @reader.send(:read_action, 'xyz', {:icon =>"pixmap"}).icon.should == '/dir/pixmap'
    end
    
    it 'should use an empty string as default value for the icon entry' do
      res = @reader.send(:read_action, 'xyz', {}).icon.should == ''
    end

    it 'should store the constant corresponding to the class entry in the action_class attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:class => 'KDE::ToggleAction'}).action_class.should == KDE::ToggleAction
    end

    it 'should use KDE::Action as default value of the class entry' do
      @reader.send(:read_action, 'xyz', {}).action_class.should == KDE::Action
    end
    
    it 'should store the content of the standard_action entry, converted to a symbol, in the standard_action attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:standard_action => 'open_new'}).standard_action.should == :open_new
    end
    
    it 'should use nil as default value of the standard_action entry' do
      @reader.send(:read_action, 'xyz', {}).standard_action.should be_nil
    end
    
    it 'should set the standard_action attribute of the returned object to nil if a class entry exists in the hash' do
      @reader.send(:read_action, 'xyz', {:standard_action => 'open_new', :class => KDE::ToggleAction}).standard_action.should be_nil
    end
    
    it 'should set the action_class attribute of the returned object to nil if the standard_action entry exists in the hash and the class entry doesn\'t' do
      @reader.send(:read_action, 'xyz', {:standard_action => 'open_new'}).action_class.should be_nil
    end
    
    it 'should store the content of the receiver entry in the receiver attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:receiver => '@var'}).receiver.should == '@var'
    end
    
    it 'should use "self" as default value of the receiver entry' do
      @reader.send(:read_action, 'xyz', {}).receiver.should == 'self'
    end
    
    it 'should store the content of the signal entry in the signal attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:signal => 'toggled(bool)'}).signal.should == 'toggled(bool)'
    end
    
    it 'should use "triggered(bool)" as default value of the signal entry' do
      @reader.send(:read_action, 'xyz', {}).signal.should == 'triggered(bool)'
    end
    
    it 'should store the content of the slot entry in the slot attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:slot => 'test()'}).slot.should == 'test()'
    end
    
    it 'should use nil as default value of the slot entry' do
      @reader.send(:read_action, 'xyz', {}).slot.should be_nil
    end
    
    it 'should store the content of the states entry in the states attrbiute of the returned object' do
      @reader.send(:read_action, 'xyz', {:states => %w[s1 s2]}).states.should == %w[s1 s2]
    end
    
    it 'should use an empty array as default value of the states entry' do
      @reader.send(:read_action, 'xyz', {}).states.should == []
    end
    
    it 'should store the content of the state entry in the state attribute of the returned object' do
      @reader.send(:read_action, 'xyz', {:state => 's'}).state.should == 's'
    end
    
    it 'should use nil as default value of the state entry' do
      @reader.send(:read_action, 'xyz', {}).state.should be_nil
    end
    
    it 'should set the state attribute of the returned object to nil if the states entry also exists' do
      @reader.send(:read_action, 'xyz', {:states => %w[s1 s2], :state => 's'}).state.should be_nil
    end
    
    it 'should use the symbol version of the keys over the string version if both exist' do
      hash = {
        :text => 'A', 'text' => 'B',
        :shortcut => 'Ctrl+A', 'shortcut' => 'Ctrl+B',
        :help => 'H', 'help' => 'h',
        :class => 'KDE::ToggleAction', 'class' => 'KDE::RecentFilesAction',
        :receiver => '@var1', 'receiver' => '@var2',
        :signal => 'S1()', 'signal' => 'S2()',
        :slot => 's1()', 'slot' => 's2()',
        :states => %w[a b], 'states' => %w[c d]
        }
      res = @reader.send :read_action, 'xyz', hash
      res.text.should == 'A'
      res.shortcut.to_string.should == 'Ctrl+A'
      res.help.should == 'H'
      res.action_class.should == KDE::ToggleAction
      res.receiver.should == '@var1'
      res.signal.should == 'S1()'
      res.slot.should == 's1()'
      res.states.should == %w[a b]
    end
    
    it 'should use the string versions of the keys if the symbol version doesn\'t exist' do
      hash = {
        "text" => 'A',
        "shortcut" => 'Ctrl+A',
        "help" => 'H',
        "class" => 'KDE::ToggleAction',
        "receiver" => '@var1',
        "signal" => 'S1()',
        "slot" => 's1()',
        "states" => %w[a b],
      }
      res = @reader.send :read_action, 'xyz', hash
      res.text.should == 'A'
      res.shortcut.to_string.should == 'Ctrl+A'
      res.help.should == 'H'
      res.action_class.should == KDE::ToggleAction
      res.receiver.should == '@var1'
      res.signal.should == 'S1()'
      res.slot.should == 's1()'
      res.states.should == %w[a b]
    end
    
  end
  
  describe '#read_actions' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
      @hash = {
        :actions => {
          'a1' => {:text => 'X'},
          :a2 => {:text => 'Y'},
          'a3' => {:text => 'Z'}
                    }
      }
    end
    
    it 'should return a hash' do
      @reader.send( :read_actions, @hash).should be_a(Hash)
    end
    
    it 'should call the read_action method for each entry in the actions entry, passing it each key (converted to a string) and the corresponding value' do
      flexmock(@reader).should_receive(:read_action).with('a1', @hash[:actions]['a1']).once
      flexmock(@reader).should_receive(:read_action).with('a2', @hash[:actions][:a2]).once
      flexmock(@reader).should_receive(:read_action).with('a3', @hash[:actions]['a3']).once
      @reader.send :read_actions, @hash
    end
    
    it 'should store the value returned by each call to read_action in the returned hash under its name' do
      res = @reader.send :read_actions, @hash
      res['a1'].text.should == 'X'
      res['a2'].text.should == 'Y'
      res['a3'].text.should == 'Z'
    end
    
  end
  
  describe '#read_human_name' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return the content of the :human_name entry of the argument, if it exists' do
      @reader.send(:read_human_name, {:human_name => 'Test'}).should == 'Test'
      @reader.send(:read_human_name, {'human_name' => 'Test'}).should == 'Test'
    end
    
    it 'should use the value in the :human_name entry if both it and the "human_name" entry exist' do
      @reader.send(:read_human_name, {:human_name => 'Test', 'human_name' => 'X'}).should == 'Test'
    end
    
    it 'should obtain the human_name entry from the name entry if the former is missing' do
      @info.name = :xy_z
      @reader.send(:read_human_name, {}).should == 'Xy z'
    end
    
  end
  
  describe '#read_authors' do
   
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return the contents of the authors entry of the argument, if it exists' do
      @reader.send(:read_authors, {:authors => [['Stefano Crocco', 'stefano.crocco@alice.it']]}).should == [['Stefano Crocco', 'stefano.crocco@alice.it']]
      @reader.send(:read_authors, {'authors' => [['Stefano Crocco', 'stefano.crocco@alice.it']]}).should == [['Stefano Crocco', 'stefano.crocco@alice.it']]
    end
    
    it 'inserts an empty string as second element to all the inner arrays which only have one element' do
      @reader.send(:read_authors, {:authors => [['Stefano Crocco']]}).should == [['Stefano Crocco', '']]
    end
    
    it 'should use the :authors entry if both it and the "authors" entry exist' do
      @reader.send(:read_authors, {:authors => [['Stefano Crocco', 'stefano.crocco@alice.it']], 'authors' => []}).should == [['Stefano Crocco', 'stefano.crocco@alice.it']]
    end
    
    it 'should use an empty array as default value' do
      @reader.send(:read_authors, {}).should == []
    end
    
    it 'should raise PluginSpecification::PSFError if the value contained in the entry isn\'t an array' do
      lambda{@reader.send(:read_authors, {:authors => 'Name'})}.should raise_error(Ruber::PluginSpecification::PSFError, 'The "authors" entry in the PDF should be an array')
    end
    
    it 'should enclose the value contained in the authors entry in an array if it\'s not a nested array' do
      @reader.send(:read_authors, {:authors => ['Stefano Crocco', 'stefano.crocco@alice.it']}).should == [['Stefano Crocco', 'stefano.crocco@alice.it']]
    end
    
    it 'encloses the value contained in the authors entry in an array if the authors entry is an array with a single entry and that\'s not an array' do
      @reader.send(:read_authors, {:authors => ['Stefano Crocco']}).should == [['Stefano Crocco', '']]
    end
    
    it 'should not enclose an empty array in another array' do
      @reader.send(:read_authors, {:authors => []}).should == []
    end
    
  end
  
  describe '#read_license' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return the contents of the license entry in the argument if it exists' do
      @reader.send(:read_license, {:license => :gpl}).should == :gpl
      @reader.send(:read_license, {'license' => :gpl}).should == :gpl
    end
    
    it 'should convert the contents of the license entry to a symbol' do
      @reader.send(:read_license, {:license => 'gpl'}).should == :gpl
    end
   
    it 'should use the :license entry if both it and the "license" entry exist' do
      @reader.send(:read_license, {:license => :gpl3, 'license' => :gpl}).should == :gpl3
    end
    
    it 'should use :unknown as default value' do
      @reader.send(:read_license, {}).should == :unknown
    end
    
    it 'should raise PluginSpecification::PSFError if the license is a symbol but it\'s not recognized' do
      allowed = [:unknown, :gpl, :gpl2, :lgpl, :lgpl2, :bsd, :artistic, :qpl, :qpl1, :gpl3, :lgpl3]
      allowed.each do |l|
        lambda{@reader.send(:read_license, {:license => l})}.should_not raise_error
      end
      lambda{@reader.send(:read_license, {:license => :xyz})}.should raise_error(Ruber::PluginSpecification::PSFError, "Invalid licese type :xyz")
    end
    
    it 'should use the content of the entry, even if it doesn\'t correspond to a license name if it is a string' do
      @reader.send(:read_license, {:license => 'xyz'}).should == 'xyz'
    end
    
  end
  
  describe "#read_version" do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return the contents of the version entry in the argument if it exists' do
      @reader.send(:read_version, {:version => '1.2.3'}).should == '1.2.3'
      @reader.send(:read_version, {'version' => '1.2.3'}).should == '1.2.3'
    end
   
    it 'should use the :version entry if both it and the "version" entry exist' do
      @reader.send(:read_version, {:version => '1.2.3', 'version' => '4.5.6'}).should == '1.2.3'
    end
    
    it 'should use "0.0.0" as default value' do
      @reader.send(:read_version, {}).should == '0.0.0'
    end
    
  end
  
  describe '#read_about' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return an OpenStruct' do
      @reader.send(:read_about, {:about => {}}).should be_a(OpenStruct)
    end
    
    it 'should store the human name of the plugin in the returned value' do
      flexmock(@reader).should_receive(:read_human_name).once.with({:human_name => 'Xyz'}).and_return('Xyz')
      @reader.send(:read_about, {:about => {:human_name => 'Xyz'}}).human_name.should == 'Xyz'
    end
    
    it 'should store the authors of the plugin in the returned value' do
      flexmock(@reader).should_receive(:read_authors).once.with({:authors => '[[Author, xyz@abc.or]]'}).and_return([%w[Author xyz@abc.or]])
      @reader.send(:read_about, ({:about => {:authors => '[[Author, xyz@abc.or]]'}})).authors.should == [%w[Author xyz@abc.or]]
    end
    
    it 'should store the description of the plugin in the returned value' do
      flexmock(@reader).should_receive(:read_description).once.with({:description => 'Short description'}).and_return('Short description')
      @reader.send(:read_about, :about => {:description => 'Short description'}).description.should == 'Short description'
    end
    
    it 'should store the license of the plugin in the returned value' do
      flexmock(@reader).should_receive(:read_license).once.with({:license => :gpl}).and_return(:gpl)
      @reader.send(:read_about, :about => {:license => :gpl}).license.should == :gpl
    end
    
    it 'should store the address for reporting bugs in the returned object' do
      flexmock(@reader).should_receive(:read_bug_address).once.with({:bug_address => 'xyz@abc.com'}).and_return('xyz@abc.com')
      @reader.send(:read_about, :about => {:bug_address => 'xyz@abc.com'}).bug_address.should == 'xyz@abc.com'
    end
    
    it 'should store the copyright information in the returned object' do
      flexmock(@reader).should_receive(:read_copyright).once.with({:copyright => 'Author'}).and_return('Author')
      @reader.send(:read_about, :about => {:copyright => 'Author'}).copyright.should == 'Author'
    end
    
    it 'should store the homepage information in the returned object' do
      flexmock(@reader).should_receive(:read_homepage).once.with({:homepage => 'http://www.abc.xyz.org'}).and_return('http://www.abc.xyz.org')
      @reader.send(:read_about, :about => {:homepage => 'http://www.abc.xyz.org'}).homepage.should == 'http://www.abc.xyz.org'
    end
    
    it 'should store the icon associated with the plugin in the returned object' do
      flexmock(@reader).should_receive(:read_icon).once.with({:icon => 'ruby.png'}).and_return('ruby.png')
      @reader.send(:read_about, :about => {:icon => 'ruby.png'}).icon.should == 'ruby.png'
    end
    
  end
  
  describe '#read_bug_address' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return the bug_address entry of the PDF' do
      @reader.send(:read_bug_address, {:bug_address => 'xyz@abc.org'}).should == 'xyz@abc.org'
      @reader.send('read_bug_address', {:bug_address => 'xyz@abc.org'}).should == 'xyz@abc.org'
    end
    
    it 'should use an empty string as default value' do
      @reader.send(:read_bug_address, {}).should == ''
    end
    
    it 'should use the symbol entry if both entries exist' do
      @reader.send(:read_bug_address, {:bug_address => 'xyz@abc.org', 'bug_address' => 'abc@xyz.com'}).should == 'xyz@abc.org'
    end
    
  end
  
  describe '#read_copyright' do
  
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
  
    it 'should return the copyright entry of the PDF' do
      @reader.send(:read_copyright, {:copyright => 'copyright text'}).should == 'copyright text'
      @reader.send('read_copyright', {:copyright => 'copyright text'}).should == 'copyright text'
    end

    it 'should use an empty string as default value' do
      @reader.send(:read_copyright, {}).should == ''
    end
    
    it 'should use the symbol entry if both entries exist' do
      @reader.send(:read_copyright, {:copyright => 'copyright text', 'copyright' => 'other copyright text'}).should == 'copyright text'
    end
    
  end
  
  describe '#read_homepage' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'should return the homepage entry of the PDF' do
      @reader.send(:read_homepage, {:homepage => 'http://www.abc.org'}).should == 'http://www.abc.org'
      @reader.send(:read_homepage, {'homepage' => 'http://www.abc.org'}).should == 'http://www.abc.org'
    end
    
    it 'should prepend http:// to the home page if it isn\'t empty but doesn\'t start with http://' do
      @reader.send(:read_homepage, {:homepage => 'www.abc.org'}).should == 'http://www.abc.org'
      @reader.send(:read_homepage, {:homepage => ''}).should == ''
    end
    
    it 'should use an empty string as default value' do
      @reader.send(:read_homepage, {}).should == ''
    end
    
    it 'should use the symbol entry if both entries exist' do
      @reader.send(:read_homepage, {:homepage => 'http://www.abc.org', 'homepage' => 'http://www.xyz.org'}).should == 'http://www.abc.org'
    end
    
  end
  
  describe '#read_icon' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
      @info.directory = '/dir'
    end    
    
    it 'should return the icon file prepended with the plugin directory, if the icon file exists in the plugin directory' do
      flexmock(KDE::Application).should_receive(:instance).and_return true
      flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return true
      @reader.send(:read_icon, {:icon => "pixmap"}).should == '/dir/pixmap'
      @reader.send(:read_icon, {'icon' => "pixmap"}).should == '/dir/pixmap'
    end
  
    it 'should return the absolute path of the icon file obtained using KDE::IconLoader if the icon file isn\'t in the plugin directory and the application object exists' do
      flexmock(KDE::Application).should_receive(:instance).and_return true
      flexmock(KDE::IconLoader).should_receive(:pixmap_path).with( 'pixmap').twice.and_return '/usr/pixmap'
      @reader.send(:read_icon, {:icon =>"pixmap"}).should == '/usr/pixmap'
      @reader.send(:read_icon, {'icon' =>"pixmap"}).should == '/usr/pixmap'
    end
  
    it 'should return the icon file prepended with the plugin directory, if the icon file exists in the plugin directory if the icon file isn\'t in the plugin directory but the application object doesn\'t exist' do
      flexmock(KDE::Application).should_receive(:instance).and_return(nil)
      flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return false
      flexmock(KDE::IconLoader).should_receive(:pixmap_path).with( 'pixmap').never
      @reader.send(:read_icon, {:icon =>"pixmap"}).should == '/dir/pixmap'
      @reader.send(:read_icon, {'icon' =>"pixmap"}).should == '/dir/pixmap'
    end
    
    it 'should use an empty string as default value' do
      @reader.send(:read_icon, {}).should == ''
    end
    
    it 'should use the symbol entry if both entries exist' do
      flexmock(KDE::Application).should_receive(:instance).and_return true
      flexmock(File).should_receive(:exist?).with("/dir/pixmap").and_return true
      @reader.send(:read_icon, {:icon => 'pixmap', 'icon' => 'Pixmap'}).should == '/dir/pixmap'
    end
  
  end
  
  describe '#read_rules' do
    
    before do
      @info = OpenStruct.new
      @reader = Ruber::PluginSpecificationReader.new @info
    end
    
    it 'returns a hash' do
      @reader.send(:read_rules, {}).should be_a(Hash)
    end
    
    describe ', when reading the scope' do
    
      it 'puts the contents of the scope entry of the argument in the :scope entry of the returned hash' do
        @reader.send(:read_rules, {:scope => [:global]})[:scope].should == [:global]
        @reader.send(:read_rules, {'scope' => [:document]})[:scope].should == [:document]
      end
      
      it 'converts the values :all and all to [:global, :document]' do
        @reader.send(:read_rules, {:scope => 'all'})[:scope].should == [:global, :document]
        @reader.send(:read_rules, {'scope' => :all})[:scope].should == [:global, :document]
      end
      
      it 'encloses the scope entry of the argument in a array, unless it\'s already an array' do
        @reader.send(:read_rules, {:scope => :global})[:scope].should == [:global]
      end
      
      it 'converts each entry of the scope array to a symbol' do
        @reader.send(:read_rules, {:scope => %w[global document]})[:scope].should == [:global, :document]
      end
      
      it 'uses [:global] as default value for the scope entry' do
        @reader.send(:read_rules, {})[:scope].should == [:global]
      end
    
    end
    
    context ', when reading the place' do
    
      it 'puts the contents of the place entry of the argument in the :place entry of the returned hash' do
        @reader.send(:read_rules, {:place => [:local]})[:place].should == [:local]
        @reader.send(:read_rules, {'place' => [:remote]})[:place].should == [:remote]
      end
      
      it 'converts the values :all and all to [:local, :remote]' do
        @reader.send(:read_rules, {:place => ['all']})[:place].should == [:local, :remote]
        @reader.send(:read_rules, {'place' => [:all]})[:place].should == [:local, :remote]
      end
      
      it 'encloses the place entry of the argument in a array, unless it\'s already an array' do
        @reader.send(:read_rules, {:place => :local})[:place].should == [:local]
      end
      
      it 'converts each entry of the place array to a symbol' do
        @reader.send(:read_rules, {:place => %w[local remote]})[:place].should == [:local, :remote]
      end
      
      it 'uses [:local] as default value' do
        @reader.send(:read_rules, {})[:place].should == [:local]
      end
    
    end

    
    describe ', when reading the mimetype' do
      
      it 'stores the contents of the mimetype entry of the argument in the returned value' do
        @reader.send(:read_rules, :mimetype => ['application/x-ruby'])[:mimetype].should == ['application/x-ruby']
        @reader.send(:read_rules, 'mimetype' => ['application/x-ruby'])[:mimetype].should == ['application/x-ruby']
      end
      
      it 'encloses the mimetype entry in a array unless it\'s already a array' do
        @reader.send(:read_rules, :mimetype => 'application/x-ruby')[:mimetype].should == ['application/x-ruby']
      end
      
      it 'uses an empty array as default value' do
        @reader.send(:read_rules, {})[:mimetype].should == []
      end
      
    end
    
    describe ', when reading the file extension' do
      
      it 'stores the contents of the file_extension entry of the argument in the returned value' do
        @reader.send(:read_rules, :file_extension => %w[*.rb *.yaml])[:file_extension].should == %w[*.rb *.yaml]
        @reader.send(:read_rules, 'file_extension' => %w[*.rb *.yaml])[:file_extension].should == %w[*.rb *.yaml]
      end
      
      it 'converts the file_extension entry in a array, unless it\'s already one' do
        @reader.send(:read_rules, :file_extension => '*.rb')[:file_extension].should == ['*.rb']
      end
      
      it 'uses an empty array as default value' do
        @reader.send(:read_rules, {})[:file_extension].should == []
      end
      
    end
    
  end
    
end

describe Ruber::PluginSpecificationReader::Option do
  
  describe '#default' do
    
    it 'should work as the base class method if the value isn\'t a string' do
      o = Ruber::PluginSpecificationReader::Option.new :default => 1
      o.default.should == 1
      o.default = true
      o.default.should be_true
      o.default = %w[a b c]
      o.default.should == %w[a b c]
    end
    
    it 'should return the value as it is if it is a string and the "eval_default" entry is false' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "puts", :eval_default => false
      o.default.should == 'puts'
    end
    
    it 'should call "eval" on the value, using TOPLEVEL_BINDING as second argument, if the value is a string and no argument is given' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "1+3", :eval_default => true
      flexmock(o).should_receive(:eval).with("1+3", TOPLEVEL_BINDING).and_return(4)
      o.default.should == 4
    end
    
    it 'should call "eval" on the value, using the argument as second argument to eval, if the value is a string and an argument is given' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "1+3", :eval_default => true
      b = binding
      flexmock(o).should_receive(:eval).with("1+3", b).and_return(4)
      o.default(b).should == 4
    end
    
    it 'should return the value as it is if eval raises NoMethodError, NameError, ArgumentError or SyntaxError' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "class"
      o.default.should == 'class'
      o.default = 'XYZ'
      o.default.should == 'XYZ'
      o.default = 'x'
      o.default.should == 'x'
      o.default = 'require'
      o.default.should == 'require'
    end
    
  end
  
  describe 'to_os' do
    
    it 'should return an OpenStruct' do
      o = Ruber::PluginSpecificationReader::Option.new :default => 1, :x => 'a'
      o.to_os.should be_instance_of(OpenStruct)
    end
    
    it 'should put the value returned by the #default method in the :default attribute of the OpenStruct' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "1", :x => 'a'
      flexmock(o).should_receive(:default).once.and_return 1
      o.to_os.default.should == 1
    end
    
    it 'should pass the argument to #default, using TOPLEVEL_BINDING if it isn\'t given' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "1", :x => 'a'
      flexmock(o).should_receive(:default).once.with(TOPLEVEL_BINDING).and_return 1
      o.to_os
      b = binding
      flexmock(o).should_receive(:default).once.with(b).and_return 1
      o.to_os(b)
    end
    
    it 'should store all the entries except default in the returned object as they are' do
      o = Ruber::PluginSpecificationReader::Option.new :default => "1", :x => 'puts'
      o.to_os.x.should == 'puts'
    end
    
  end
  
end
