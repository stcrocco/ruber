require 'spec/common'

require 'ruber/plugin'
require 'ruber/plugin_specification'
require 'ruber/project'
require 'ruber/settings_container'
require 'ruber/kde_config_option_backend'
require 'ruber/editor/document'
require 'ruber/plugin_specification_reader'

module PluginSpec
  
  class FakeConfig < Qt::Object
    signals 'settings_changed()'
    
    include Ruber::SettingsContainer
    
    def initialize
      super
      setup_container(Ruber::KDEConfigSettingsBackend.new)
    end
    
    def add_option *args; end
    
    def remove_option *args;end
  end
  
  class MyWidget < Qt::Widget
    
    slots 'load_settings()'
    
    def load_settings
    end
  
  end
  
end

describe 'Ruber::Plugin, when created' do
    
  before do
    @app = Qt::Object.new
    @data = {:name => :test, :class => 'Ruber::Plugin'}
    @manager = flexmock{|m| m.should_ignore_missing}
    @config = PluginSpec::FakeConfig.new
    @mw = flexmock("main_window"){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
  end
  
  it 'should call super passing the application object as argument' do
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plug.parent.should equal(@app)
  end
  
  it 'should store the argument passed to the constructor int the plugin_description attribute' do
    pdf = Ruber::PluginSpecification.full( @data )
    plug = Ruber::Plugin.new pdf
    plug.plugin_description.should equal( pdf )
  end
  
  it 'should store itself in the component manager' do
    @manager = flexmock('manager'){|m| m.should_receive(:add).once .with(Ruber::Plugin)}
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager)
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config)
    Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
  end
  
  it 'should set the plugin name to be equal to the name contained in the pdf' do
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plug.plugin_name.should == :test
  end
  
  it 'should connect its "load_settings()" slot to the configuration manager\'s "settings_changed()" signal' do
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    flexmock(plug).should_receive(:load_settings).once
    @config.instance_eval{emit settings_changed}
  end
  
  it 'should register its options, if any, with the config object, if it exists (converting each Option object to an OpenStruct)' do
    @data[:config_options]=  {
      :General=> {
                  :o1 => {:default => '"#{\'a\'.capitalize}"'},
                  :o2 => {:default => 3},
                  :o3 => {:default => "Array"},
                  :o4 => {:default => 'y', :eval_default => false}
                 }
                             }
    flexmock(@config) do |m|
      m.should_receive(:add_option).once.with(OS.new(:name => :o1, :group => :General, :default => 'A', :relative_path => false, :eval_default => true, :order => nil))
      m.should_receive(:add_option).once.with(OS.new({:name => :o2, :group => :General, :default => 3, :relative_path => false, :eval_default => true, :order => nil}))
      m.should_receive(:add_option).once.with(OS.new({:name => :o3, :group => :General, :default => Array, :relative_path => false, :eval_default => true, :order => nil}))
      m.should_receive(:add_option).once.with(OS.new({:name => :o4, :group => :General, :default => 'y', :relative_path => false, :eval_default => false, :order => nil}))
    end
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
  end
  
  it 'register options which have a lower "order" attribute before those with a higher value' do
    @data[:config_options]=  {
      :General=> {
                  :o1 => {:default => '"#{\'a\'.capitalize}"', :order => 1},
                  :o2 => {:default => 3, :order => 0},
                  :o3 => {:default => "Array", :order => 0},
                  :o4 => {:default => 'y', :eval_default => false, :order => 1}
                 }
    }
    flexmock(@config) do |m|
      m.should_receive(:add_option).once.with(OS.new({:name => :o2, :group => :General, :default => 3, :relative_path => false, :eval_default => true, :order => 0})).ordered('first')
      m.should_receive(:add_option).once.with(OS.new({:name => :o3, :group => :General, :default => Array, :relative_path => false, :eval_default => true, :order => 0})).ordered('first')
      m.should_receive(:add_option).once.with(OS.new(:name => :o1, :group => :General, :default => 'A', :relative_path => false, :eval_default => true, :order => 1)).ordered('second')
      m.should_receive(:add_option).once.with(OS.new({:name => :o4, :group => :General, :default => 'y', :relative_path => false, :eval_default => false, :order => 1})).ordered('second')
    end
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
  end
  
  it 'register options don\'t have an "order" attribute at an arbitrary time' do
    @data[:config_options]=  {
      :General=> {
                  :o1 => {:default => '"#{\'a\'.capitalize}"', :order => 1},
                  :o2 => {:default => 3},
                  :o3 => {:default => "Array", :order => 0},
                  :o4 => {:default => 'y', :eval_default => false}
                 }
    }
    flexmock(@config) do |m|
      m.should_receive(:add_option).once.with(OS.new({:name => :o2, :group => :General, :default => 3, :relative_path => false, :eval_default => true, :order => nil}))
      m.should_receive(:add_option).once.with(OS.new({:name => :o3, :group => :General, :default => Array, :relative_path => false, :eval_default => true, :order => 0})).ordered('first')
      m.should_receive(:add_option).once.with(OS.new(:name => :o1, :group => :General, :default => 'A', :relative_path => false, :eval_default => true, :order => 1)).ordered('second')
      m.should_receive(:add_option).once.with(OS.new({:name => :o4, :group => :General, :default => 'y', :relative_path => false, :eval_default => false, :order => nil}))
    end
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
  end

  
  it 'should use the plugin\'s binding to evaluate the options\' default value' do
    class Ruber::Plugin
      def test_value
        7
      end
    end
    @data[:config_options] = {
      :G => {
             :o1 => {:default => 'test_value'}
             }
      }
    flexmock(@config){|m| m.should_receive(:add_option).once.with(OS.new(:name => :o1, :group => :G, :default => 7, :relative_path => false, :eval_default => true, :order => nil))}
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    class Ruber::Plugin
      undef_method :test_value
    end
  end
   
  it 'should not attempt to register its options if the config component doesn\'t exist' do
    flexmock(Ruber).should_receive(:[]).with(:config).and_return nil
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager)
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app)
    @data[:config_options]= { :General=> { :o1 => {:type => 'string', :default => '"#{\'a\'.capitalize}"'} }}
    lambda{Ruber::Plugin.new Ruber::PluginSpecification.full(@data)}.should_not raise_error
  end
  
  it 'should add all the config widgets it provides, if any, to the config manager' do
    @data[:config_widgets] = [
      {:class => Qt::CheckBox, :caption => 'C1'},
      {:class => Qt::PushButton, :caption => 'C2'}
    ]
    Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app)
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config)
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(mw)
    widgets = @config.dialog.widgets
    widgets.size.should == 2
    widgets.any?{|w| w.is_a?(Qt::CheckBox)}.should_not be_nil
    widgets.any?{|w| w.is_a?(Qt::PushButton)}.should_not be_nil
  end
  
  it 'should call the "load_settings" method, if the configuration manager exists' do
    Ruber::Plugin.class_eval do
      alias :old_load_settings :load_settings
      def load_settings
        @called = true
      end
    end
    @data[:config_options]=  { :General=> { :o1 => {:type => 'string', :default => '"#{\'a\'.capitalize}"'} } }
    flexmock(@config).should_receive(:add_option)
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plug.instance_variable_get(:@called).should be_true
    Ruber::Plugin.class_eval{alias :load_settings :old_load_settings}
  end
  
  it 'shouldn\'t call the "load_settings" method, if the configuration manager doesn\'t exist' do
    Ruber::Plugin.class_eval do
      alias :old_load_settings :load_settings
      def load_settings
        @called = true
      end
    end
    flexmock(Ruber).should_receive(:[]).with(:config).and_return nil
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager)
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app)
    @data[:config_options]=  { :General=> { :o1 => {:type => 'string', :default => '"#{\'a\'.capitalize}"'} } }
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plug.instance_variable_get(:@called).should be_nil
    Ruber::Plugin.class_eval{alias :load_settings :old_load_settings}
  end
  
  it 'should create the tool widgets mentioned in the PDF' do
    @data[:tool_widgets] = [
      {:class => Qt::CheckBox, :caption => 'w1', :pixmap => 'xyz.png'},
      {:class => Qt::LineEdit, :position => :left, :caption => 'w2', :pixmap => 'abc.png'},
      ]
    pix1 = flexmock('xyz.png')
    pix2 = flexmock('abc.png')
    flexmock(Qt::Pixmap).should_receive(:new).once.with('xyz.png').and_return pix1
    flexmock(Qt::Pixmap).should_receive(:new).once.with('abc.png').and_return pix2
    pdf = Ruber::PluginSpecification.full(@data)
    pdf.tool_widgets[0].pixmap = 'xyz.png'
    pdf.tool_widgets[1].pixmap = 'abc.png'
    @mw.should_receive(:add_tool).with(:bottom, Qt::CheckBox, pix1, 'w1').once
    @mw.should_receive(:add_tool).with(:left, Qt::LineEdit, pix2, 'w2').once
    Ruber::Plugin.new pdf
  end
  
  it 'should give the tool widgets the names specified in the :name entry, if given' do
    @data[:tool_widgets] = [
      {:class => Qt::CheckBox, :caption => 'w1', :pixmap => 'xyz.png', :name => 'W1'},
      {:class => Qt::LineEdit, :position => :left, :caption => 'w2', :pixmap => 'abc.png', :name => 'W2'},
      ]
    w1 = Qt::CheckBox.new
    w2 = Qt::LineEdit.new
    flexmock(Qt::CheckBox).should_receive(:new).once.and_return(w1)
    flexmock(Qt::LineEdit).should_receive(:new).once.and_return(w2)
    Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    w1.object_name.should == 'W1'
    w2.object_name.should == 'W2'
  end
  
  it 'should store the tool widgets in instance variables, according to the :var_name entry' do
    @data[:tool_widgets] = [
      {:class => Qt::CheckBox, :caption => 'w1', :pixmap => 'xyz.png', :var_name => 'w1'},
      {:class => Qt::LineEdit, :position => :left, :caption => 'w2', :pixmap => 'abc.png'},
      {:class => Qt::PushButton, :position => :right, :caption => 'w3', :pixmap => 'jkl.png', :var_name => nil},
      ]
    w1 = Qt::CheckBox.new
    w2 = Qt::LineEdit.new
    flexmock(Qt::CheckBox).should_receive(:new).once.and_return(w1)
    flexmock(Qt::LineEdit).should_receive(:new).once.and_return(w2)
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plug.instance_variable_get(:@w1).should equal(w1)
    plug.instance_variable_get(:@widget).should equal(w2)
    # the map part is needed because instance_variables returns strings in ruby
    # 1.8 and symbols in ruby 1.9
    plug.instance_variables.map{|v| v.to_s}.should =~ ['@plugin_description', '@w1', '@widget']
  end
  
  it 'should connect the tool widgets\' "load_settings" method to the application, if the application exists and the tool widgets provide a load_settings method' do
    Object.class_eval <<-EOS
      class W1 < Qt::Widget
      slots 'load_settings()'
      def load_settings;end
      end
      
      class W2 < Qt::Widget
      end
      
      class W3 < Qt::Widget
      slots 'load_settings()'
      def load_settings;end
      end
    EOS
    @data[:tool_widgets] = [
      {:class => W1, :caption => 'w1', :pixmap => 'xyz.png', :var_name => 'w1'},
      {:class => W2, :position => :left, :caption => 'w2', :pixmap => 'abc.png'},
      {:class => W3, :position => :right, :caption => 'w3', :pixmap => 'jkl.png', :var_name => nil},
      ]
    w1 = W1.new
    w2 = W2.new
    w3 = W3.new
    flexmock(W1).should_receive(:new).once.and_return(w1)
    flexmock(W2).should_receive(:new).once.and_return(w2)
    flexmock(W3).should_receive(:new).once.and_return(w3)
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    flexmock(w2).should_receive(:load_settings).never
    flexmock(w1).should_receive(:load_settings).once
    flexmock(w3).should_receive(:load_settings).once
    @config.instance_eval{emit settings_changed}
    Object.send(:remove_const, :W1)
    Object.send(:remove_const, :W2)
    Object.send(:remove_const, :W3)
  end
  
  it 'should call the "load_settings" method of each tool widget which provides it, if the configuration manager exists' do
        Object.class_eval <<-EOS
      class W1b < Qt::Widget
      slots 'load_settings()'
      def load_settings;end
      end
      
      class W2b < Qt::Widget
      end
      
      class W3b < Qt::Widget
      slots 'load_settings()'
      def load_settings;end
      end
    EOS
    @data[:tool_widgets] = [
      {:class => W1b, :caption => 'w1', :pixmap => 'xyz.png', :var_name => 'w1'},
      {:class => W2b, :position => :left, :caption => 'w2', :pixmap => 'abc.png'},
      {:class => W3b, :position => :right, :caption => 'w3', :pixmap => 'jkl.png', :var_name => nil},
      ]
    w1 = W1b.new
    w2 = W2b.new
    w3 = W3b.new
    flexmock(W1b).should_receive(:new).once.and_return(w1)
    flexmock(W2b).should_receive(:new).once.and_return(w2)
    flexmock(W3b).should_receive(:new).once.and_return(w3)
    flexmock(w1).should_receive(:load_settings).once
    flexmock(w3).should_receive(:load_settings).once
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    Object.send(:remove_const, :W1b)
    Object.send(:remove_const, :W2b)
    Object.send(:remove_const, :W3b)
  end
  
end

describe 'Ruber::Plugin#unload' do
  
  before do
    @app = Qt::Object.new
    @data = {:name => :test, :class => 'Ruber::Plugin'}
    @manager = flexmock{|m| m.should_ignore_missing}
    @config = PluginSpec::FakeConfig.new
    @mw = flexmock('main window'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
  end
  
  it 'calls the shutdown method' do
    plugin = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    flexmock(plugin).should_receive(:shutdown).once
    plugin.unload
  end
  
  it 'should disconnect itself from the application\'s settings_changed signal' do
    plugin = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    flexmock(plugin).should_receive(:load_settings).never
    plugin.unload
    @config.instance_eval{emit settings_changed}
  end
  
  it 'should remove all tool widgets from the main window' do
    @data[:tool_widgets] = [
      {:class => Qt::CheckBox, :caption => 'W1', :pixmap => 'xyz.png', :name => 'w1'},
      {:class => Qt::LineEdit, :position => :left, :caption => 'W2', :name => 'w2', :pixmap => 'xab.png'},
      {:class => Qt::PushButton, :position => :right, :caption => 'w3', :pixmap => 'jkl.png'},
    ]
    w1 = Qt::CheckBox.new
    w2 = Qt::LineEdit.new
    w3 = Qt::PushButton.new
    flexmock(Qt::CheckBox).should_receive(:new).once.and_return(w1)
    flexmock(Qt::LineEdit).should_receive(:new).once.and_return(w2)
    flexmock(Qt::PushButton).should_receive(:new).once.and_return(w3)
    @mw.should_receive(:remove_tool).once.with('w1')
    @mw.should_receive(:remove_tool).once.with('w2')
    @mw.should_receive(:remove_tool).once.with('w3')
    plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plug.unload
  end
  
  it 'should remove all configuration options from the configuration manager, if it exists' do
    @data[:config_options] = {:x => {:a => {:default => 3}, :b => {:default => 'string'}}, :y => {:c => {:default => true}}}
    flexmock(@config) do |mk| 
      mk.should_receive(:remove_option).with(:x, :a).once
      mk.should_receive(:remove_option).with(:x, :b).once
      mk.should_receive(:remove_option).with(:y, :c).once
    end
    plugin = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    plugin.unload
  end
  
  it 'shouldn\'t attempt tp remove the configuration options from the configuration manager, if it doesn\'t exist' do
    @data[:config_options] = {:x => {:a => {:default => 3}, :b => {:default => 'string'}}, :y => {:c => {:default => true}}}
    plugin = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    lambda{plugin.unload}.should_not raise_error
  end
  
end

describe 'Ruber::Plugin' do
  
  before do
    @data = {:name => 'test', :class => 'Ruber::Plugin'}
    @app = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    @projects = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    @manager = flexmock{|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
  end
  
  it 'should have a "load_settings" private method' do
    @plug.respond_to?(:load_settings, true).should be_true
    @plug.respond_to?(:load_settings).should be_false
  end
  
  it 'should have a save_settings method' do
    @plug.should respond_to(:save_settings)
  end
  
  it 'should have a query_close method which returns true' do
  @plug.query_close.should == true
  end
  
  describe '#add_options_to_project' do
    
    before do
      @data[:project_options] = {
        :g1 => {:o1 => {:default => 7, :scope => :global}, :o2 => {:default => 'abc', :scope => :document}},
        :g2 => {:o1 => {:default => %w[a b c]}, :o3 => {:default => :xyz}}
      }
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
    end
    
    it 'adds the options for which the project\'s match_rule? returns true to the project' do
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g1, :o1]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g1, :o2]]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g2, :o1]]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g2, :o3]]).and_return true
      @plug.add_options_to_project @prj
      opts = @prj.instance_variable_get(:@known_options)
      opts[[:g1,:o1]].default.should == 7
      opts[[:g1,:o2]].should be_nil
      opts[[:g2,:o1]].should be_nil
      opts[[:g2,:o3]].default.should == :xyz
    end
    
    it 'uses the project\'s binding to evaluate the default values of the options' do
      @prj.instance_variable_set(:@xyz, 5)
      @plug.plugin_description.project_options[[:g1,:o1]].default = '2*@xyz'
      @plug.add_options_to_project @prj
      opts = @prj.instance_variable_get(:@known_options)
      opts[[:g1,:o1]].default.should == 10
    end
    
    it 'adds first options whose "order" attribure is lower' do
      desc = @plug.plugin_description.project_options
      desc[[:g1, :o1]].order = 1
      desc[[:g1, :o2]].order = 0
      desc[[:g2, :o1]].order = 0
      desc[[:g2, :o3]].order = 1
      flexmock(@prj).should_receive(:match_rule?).and_return true
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g1,:o2]]).ordered('first')
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g2,:o1]]).ordered('first')
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g1,:o1]]).ordered('second')
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g2,:o3]]).ordered('second')
      @plug.add_options_to_project @prj
    end
    
    it 'adds options with an "order" attribute of nil at any time' do
      desc = @plug.plugin_description.project_options
      desc[[:g1, :o1]].order = 1
      desc[[:g1, :o2]].order = nil
      desc[[:g2, :o1]].order = 0
      desc[[:g2, :o3]].order = nil
      flexmock(@prj).should_receive(:match_rule?).and_return true
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g1,:o2]])
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g2,:o1]]).ordered('first')
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g1,:o1]]).ordered('second')
      flexmock(@prj).should_receive(:add_option).once.with(desc[[:g2,:o3]])
      @plug.add_options_to_project @prj
    end
    
    it 'ignores any option which has already been added if the second parameter is false' do
      desc = @plug.plugin_description
      
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g1, :o1]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g1, :o2]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g2, :o1]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g2, :o3]]).and_return true
      
      flexmock(@prj).should_receive(:add_option).once.with(desc.project_options[[:g1, :o1]])
      flexmock(@prj).should_receive(:add_option).once.with(desc.project_options[[:g1, :o2]]).and_raise(ArgumentError)
      flexmock(@prj).should_receive(:add_option).once.with(desc.project_options[[:g2, :o1]])
      flexmock(@prj).should_receive(:add_option).once.with(desc.project_options[[:g2, :o3]])
      
      @plug.add_options_to_project @prj, false
    end
    
    it 'doesn\'t ignore exceptions due to options having already been added if the second argument is true' do
      desc = @plug.plugin_description
      
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g1, :o1]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_options[[:g1, :o2]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).never.with(desc.project_options[[:g2, :o1]]).and_return true
      flexmock(@prj).should_receive(:match_rule?).never.with(desc.project_options[[:g2, :o3]]).and_return true
      
      flexmock(@prj).should_receive(:add_option).once.with(desc.project_options[[:g1, :o1]])
      flexmock(@prj).should_receive(:add_option).once.with(desc.project_options[[:g1, :o2]]).and_raise(ArgumentError)
      flexmock(@prj).should_receive(:add_option).never.with(desc.project_options[[:g2, :o1]])
      flexmock(@prj).should_receive(:add_option).never.with(desc.project_options[[:g2, :o3]])
      
      lambda{@plug.add_options_to_project @prj, true}.should raise_error(ArgumentError)
    end
    
  end
  
  describe '#add_widgets_to_project' do
    
    before do
      @data[:project_widgets] = [
        {:class => 'Qt::ComboBox', :caption => 'C1', :scope => :document},
        {:class => 'Qt::LineEdit', :caption => 'C1', :scope => :global},
        {:class => 'Qt::CheckBox', :caption => 'C2'},
      ]
      @mw = Qt::Widget.new
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
    end
    
    it 'adds the widgets for which the project\'s match_rule? method returns true to the project' do
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_widgets[0]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_widgets[1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.project_widgets[2]).and_return true
      @plug.register_with_project @prj
      le = Qt::LineEdit.new
      cb = Qt::CheckBox.new
      flexmock(Qt::LineEdit).should_receive(:new).once.and_return(le)
      flexmock(Qt::CheckBox).should_receive(:new).once.and_return(cb)
      widgets = @prj.dialog.widgets
      widgets.size.should == 2
      widgets.find{|w| w.is_a? Qt::ComboBox}.should be_nil
      widgets.find{|w| w.is_a? Qt::LineEdit}.should_not be_nil
      widgets.find{|w| w.is_a? Qt::CheckBox}.should_not be_nil
    end
    
  end
  
  describe '#add_extensions_to_project' do
    
    class Ext < Qt::Object
      include Ruber::Extension
    end
    
    before do
      @cls_name = self.class.const_get(:Ext).name
      @data[:extensions] = {
        :ext1 => {:class => @cls_name}, 
        :ext2 => {:class => 'Qt::Object', :scope => :document}
      }
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
    end
    
    it 'adds each extension for which the project\'s match_rule? method returns true to the project' do
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext2]).and_return false
      @plug.add_extensions_to_project @prj
      exts = @prj.instance_variable_get(:@project_extensions)
      exts[:ext1].parent.should equal(@prj)
      exts[:ext2].should be_nil
    end
    
    it 'adds only the first extension matching the project in a list of extensions' do
      @data[:extensions] = {
        :e => [
               {:class => 'String', :scope => :global},
               {:class => 'Qt::Widget', :scope => :document},
               {:class => 'Qt::Object', :scope => [:globl, :document]}
               ]
        }
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
      w = Qt::Widget.new{extend Ruber::Extension}
      flexmock(Qt::Widget).should_receive(:new).once.with(@prj).and_return w
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:e][0]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:e][1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).never.with(desc.extensions[:e][2])
      @plug.add_extensions_to_project @prj
      exts = @prj.instance_variable_get(:@project_extensions)
      exts[:e].should be_a(Qt::Widget)
    end
    
    it 'sets the plugin attribute of the extension to itself' do
      @data[:extensions][:ext3] = [
        {:class => 'String', :scope => :global},
        {:class => 'Qt::Widget', :scope => :document},
        {:class => 'Qt::Object', :scope => [:globl, :document]}
      ]
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
      wid = Qt::Widget.new{extend Ruber::Extension}
      flexmock(Qt::Widget).should_receive(:new).once.with(@prj).and_return(wid)
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext2]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext3][0]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext3][1]).and_return true
      @plug.add_extensions_to_project @prj
      wid.plugin.should be_the_same_as(@plug)
      @prj.extension(:ext1).plugin.should be_the_same_as(@plug)
    end
    
    it 'doesn\'t attempt to add any extension from a list if no one matches' do
      @data[:extensions] = {
        :e => [
               {:class => 'String', :scope => :global},
               {:class => 'Qt::Widget', :scope => :document},
               {:class => 'Qt::Object', :scope => [:globl, :document]}
              ]
      }
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
      desc = @plug.plugin_description
      desc.extensions[:e].each{|d| flexmock(@prj).should_receive(:match_rule?).once.with(d).once.and_return false}
      lambda{@plug.add_extensions_to_project @prj}.should_not raise_error
      exts = @prj.instance_variable_get(:@project_extensions)
      exts.should_not have_key(:e)
    end
    
    it 'doesn\'t attempt to add an extension which has already been added if the second argument is false' do
      desc = @plug.plugin_description
      old = Qt::Object.new Qt::Object.new
      flexmock(@prj).should_receive(:match_rule?).with(desc.extensions[:ext1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).with(desc.extensions[:ext2]).and_return false
      flexmock(@prj).should_receive(:extension).with(:ext1).once.and_return(old)
      flexmock(@prj).should_receive(:extension).with(:ext2).once.and_return(nil)
      flexmock(Qt::Object).should_receive(:new).never
      flexmock(@prj).should_receive(:add_extension).never
      @plug.add_extensions_to_project @prj, false
    end
    
    it 'doesn\'t check whether the extension already exists if the second argument is true' do
      desc = @plug.plugin_description
      new = Ext.new
      flexmock(@prj).should_receive(:match_rule?).with(desc.extensions[:ext1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).with(desc.extensions[:ext2]).and_return false
      flexmock(@prj).should_receive(:extension).never
      flexmock(Ext).should_receive(:new).once.with(@prj).and_return new
      flexmock(@prj).should_receive(:add_extension).once.with :ext1, new
      @plug.add_extensions_to_project @prj, true
    end
    
    it 'emits the extension_added(QString, QObject*) signal for each added_extension, passing the extension name and the project as arguments' do
      @data[:extensions][:ext3] = {:class => @cls_name, :scope => :global}
      @data[:extensions][:ext4] = [
        {:class => 'Qt::Widget', :scope => :global},
        {:class => @cls_name, :scope => :global},
        ]
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      desc = @plug.plugin_description
      @prj = Ruber::Project.new('test.ruprj', 'Test')
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext2]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext3]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext4][0]).and_return false
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext4][1]).and_return true
      m = flexmock do |mk|
        mk.should_receive(:test).with('ext1', @prj).once.ordered
        mk.should_receive(:test).with('ext2', @prj).never
        mk.should_receive(:test).with('ext3', @prj).once.ordered
        mk.should_receive(:test).with('ext4', @prj).once.ordered
      end
      @plug.connect(SIGNAL('extension_added(QString, QObject*)')){|s, o| m.test s, o}
      @plug.add_extensions_to_project @prj
    end
    
    it 'doesn\'t attempt to emit the extension_added signal if it doesn\'t have it' do
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext1]).and_return true
      flexmock(@prj).should_receive(:match_rule?).once.with(desc.extensions[:ext2]).and_return false
      class << @plug
        undef_method :extension_added
      end
      lambda{@plug.add_extensions_to_project @prj}.should_not raise_error
    end
    
  end
  
  describe '#remove_options_from_project' do
    
      before do
        @data[:project_options] = {
          :g1 => {:o1 => {:default => 7, :scope => :global}, :o2 => {:default => 'abc', :scope => :document}},
          :g2 => {:o1 => {:default => %w[a b c]}, :o3 => {:default => :xyz}}
        }
        @projects = Qt::Object.new
        flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
        @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
        @manager.should_receive(:each_component).once.and_yield(@plug)
        @prj = Ruber::Project.new('test.ruprj', 'Test')
      end
    
    it 'removes all options belonging to the plugin for which the project\'s match_rule? method returns true if the second argument is true' do
      desc = @plug.plugin_description
      @prj.add_option OS.new({:group => :g1, :name => :opt1, :default => nil})
      @prj.add_option OS.new({:group => :g2, :name => :opt2, :default => (1..2)})
      @prj.add_option OS.new({:group => :g3, :name => :opt3, :default => /a/})
      @prj.add_option OS.new({:group => :g1, :name => :o2, :default => 7})
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g1, :o1]]).once.and_return true
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g1, :o2]]).once.and_return false
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g2, :o1]]).once.and_return true
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g2, :o3]]).once.and_return true
      flexmock(@prj).should_receive(:remove_option).with(:g1, :o1).once
      flexmock(@prj).should_receive(:remove_option).with(:g1, :o2).never
      flexmock(@prj).should_receive(:remove_option).with(:g2, :o1).once
      flexmock(@prj).should_receive(:remove_option).with(:g2, :o3).once
      @plug.remove_options_from_project @prj, true
    end
    
    it 'removes all options belonging to the plugin and previously added to the project for which the project\'s match_rule? method returns false if the second argument is false' do
      desc = @plug.plugin_description
      @prj.add_option OS.new({:group => :g1, :name => :opt1, :default => nil})
      @prj.add_option OS.new({:group => :g2, :name => :opt2, :default => (1..2)})
      @prj.add_option OS.new({:group => :g3, :name => :opt3, :default => /a/})
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g1, :o1]]).once.and_return true
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g1, :o2]]).never
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g2, :o1]]).once.and_return false
      flexmock(@prj).should_receive(:match_rule?).with(desc.project_options[[:g2, :o3]]).once.and_return true
      flexmock(@prj).should_receive(:remove_option).with(:g1, :o1).never
      flexmock(@prj).should_receive(:remove_option).with(:g1, :o2).never
      flexmock(@prj).should_receive(:remove_option).with(:g2, :o1).once
      flexmock(@prj).should_receive(:remove_option).with(:g2, :o3).never
      @plug.remove_options_from_project @prj, false
    end
        
  end
  
  describe '#remove_widgets_from_project' do
    
    before do
      @data[:project_widgets] = [
        {:class => 'Qt::ComboBox', :caption => 'C1', :scope => :document},
        {:class => 'Qt::LineEdit', :caption => 'C1', :scope => :global},
        {:class => 'Qt::CheckBox', :caption => 'C2'},
        ]
      @mw = Qt::Widget.new
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @manager.should_receive(:each_component).once.and_yield @plug
      @prj = Ruber::Project.new('test.ruprj', 'Test')
    end
    
    it 'removes all widgets belonging to the plugin from the project' do
      desc = @plug.plugin_description
      flexmock(@prj).should_receive(:remove_widget).once.with desc.project_widgets[0]
      flexmock(@prj).should_receive(:remove_widget).once.with desc.project_widgets[1]
      flexmock(@prj).should_receive(:remove_widget).once.with desc.project_widgets[2]
      @plug.remove_widgets_from_project @prj
    end
    
  end
  
  describe '#remove_extensions_from_project' do
    
    class Ext < Qt::Object
      include Ruber::Extension
    end
    
    before do
      @cls_name = self.class.const_get(:Ext).name
      @data[:extensions] = {
        :ext1 => {:class => @cls_name}, 
        :ext2 => {:class => 'Qt::Object', :scope => :document},
        :ext3 => {:class => @cls_name}
      }
      @projects = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @manager.should_receive(:each_component).and_yield(@plug)
      other_data = {
        :name => :plug1,
        :class => 'Ruber::Plugin',
        :extensions => {
                        :e1 => {:class => @cls_name, :scope => :global},
                        :e2 => {:class => @cls_name, :scope => :global},
                        }
      }
      @other_plug = Ruber::Plugin.new Ruber::PluginSpecification.full(other_data)
      @prj = Ruber::Project.new('test.ruprj', 'Test')
      @other_plug.add_extensions_to_project @prj
    end
    
    describe ', when the second argument is true' do
    
      it 'removes all extensions provided by the plugin for which the project\'s match_rule? method returns true' do
        @prj.extensions.keys.sort.should == [:e1, :e2, :ext1, :ext3]
        @plug.remove_extensions_from_project @prj, true
        @prj.extensions.keys.sort.should == [:e1, :e2]
      end
      
      it 'removes a multiple extension from the project if one of the entries\' rule matches the project\'s, when the second argument is true' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = [
          OS.new(:class_obj => String, :scope => [:document]),
          OS.new(:class_obj => Ext, :scope => [:global])
        ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        @plug.remove_extensions_from_project @prj, true
        @prj.extensions.keys.sort.should == [:e1, :e2]
      end
      
      it 'emits the removing_extension(QString, QObject*) signal for each existing extension which is being removed passing the extension name and the project as arguments' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = [
          OS.new(:class_obj => String, :scope => [:document]),
          OS.new(:class_obj => Ext, :scope => [:global])
        ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        m = flexmock do |mk|
          mk.should_receive(:test).once.with('ext1', @prj)
          mk.should_receive(:test).once.with('ext3', @prj)
          mk.should_receive(:test).once.with('ext4', @prj)
        end
        @plug.connect(SIGNAL('removing_extension(QString, QObject*)')){|s, o| m.test s, o}
        @plug.remove_extensions_from_project @prj, true
      end
            
      it 'emits the extension_removed(QString, QObject*) signal for each existing extension which has been removed passing the extension name and the project as arguments after removing it' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = [
          OS.new(:class_obj => String, :scope => [:document]),
          OS.new(:class_obj => Ext, :scope => [:global])
        ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        m = flexmock
        flexmock(@prj).should_receive(:remove_extension).once.with(:ext1).ordered('1')
        m.should_receive(:test).once.with('ext1', @prj).ordered('1')
        flexmock(@prj).should_receive(:remove_extension).once.with(:ext3).ordered('3')
        m.should_receive(:test).once.with('ext3', @prj).ordered('3')
        flexmock(@prj).should_receive(:remove_extension).once.with(:ext4).ordered('4')
        m.should_receive(:test).once.with('ext4', @prj).ordered('4')
        @plug.connect(SIGNAL('extension_removed(QString, QObject*)')){|s, o| m.test s, o}
        @plug.remove_extensions_from_project @prj, true
      end
      
      it 'doesn\'t attempt to emit the removing_extension signal if the plugin doesn\'t define it' do
        class << @plug
          undef_method :removing_extension
        end
        lambda{@plug.remove_extensions_from_project @prj, true}.should_not raise_error
      end

      it 'doesn\'t attempt to emit the extension_removed signal if the plugin doesn\'t define it' do
        class << @plug
          undef_method :extension_removed
        end
        lambda{@plug.remove_extensions_from_project @prj, true}.should_not raise_error
      end

    end
    
    describe ', when the second argument is false' do
    
      it 'removes the existing extensions provided by the plugin for which the project\'s match_rule? method returns false' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = OS.new(:class => @cls_name, :scope => [:document])
        ext = Ext.new
        ext.plugin = @plug
        @prj.add_extension :ext4, ext
        @plug.remove_extensions_from_project @prj, false
        @prj.extensions.keys.sort.should == [:e1, :e2, :ext1, :ext3]
      end
      
      it 'removes a multiple extension only if the class of the existing extension corresponds to the one specified by the entry for which the project\'s match_rule? fails' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = [
          OS.new(:class_obj => String, :scope => [:document]),
          OS.new(:class_obj => Ext, :scope => [:global])
        ]
        desc.extensions[:ext5] = [
          OS.new(:class_obj => Qt::Object, :scope => [:global]),
          OS.new(:class_obj => Ext, :scope => [:document])
        ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.add_extension :ext5, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        @prj.extension(:ext5).plugin = @plug
        @plug.remove_extensions_from_project @prj, false
        @prj.extensions.keys.should =~ [:e1, :e2, :ext1, :ext3, :ext4]
      end
      
      it 'emits the removing_extension(QString, QObject*) signal for each removed extension' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = OS.new(:class => @cls_name, :scope => [:document])
        desc.extensions[:ext5] = [
          OS.new(:class_obj => Qt::Object, :scope => [:global]),
          OS.new(:class_obj => Ext, :scope => [:document])
      ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.add_extension :ext5, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        @prj.extension(:ext5).plugin = @plug
        m = flexmock do |mk|
          mk.should_receive(:test).once.with('ext4', @prj)
          mk.should_receive(:test).once.with('ext5', @prj)
        end
        @plug.connect(SIGNAL('removing_extension(QString, QObject*)')){|s, o| m.test s, o}
        @plug.remove_extensions_from_project @prj, false
      end
      
      it 'emits the extension(QString, QObject*) signal for each removed extension after removing it' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = OS.new(:class => @cls_name, :scope => [:document])
        desc.extensions[:ext5] = [
          OS.new(:class_obj => Qt::Object, :scope => [:global]),
          OS.new(:class_obj => Ext, :scope => [:document])
      ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.add_extension :ext5, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        @prj.extension(:ext5).plugin = @plug
        m = flexmock
        flexmock(@prj).should_receive(:remove_extension).with(:ext4).once.ordered('4')
        m.should_receive(:test).once.with('ext4', @prj).once.ordered('4')
        flexmock(@prj).should_receive(:remove_extension).with(:ext5).once.ordered('5')
        m.should_receive(:test).once.with('ext5', @prj).once.ordered('5')
        @plug.connect(SIGNAL('extension_removed(QString, QObject*)')){|s, o| m.test s, o}
        @plug.remove_extensions_from_project @prj, false
      end
      
      it 'doesn\'t attempt to emit the removing_extension signal if the plugin doesn\'t define it' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = OS.new(:class => @cls_name, :scope => [:document])
        desc.extensions[:ext5] = [
          OS.new(:class_obj => Qt::Object, :scope => [:global]),
          OS.new(:class_obj => Ext, :scope => [:document])
        ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.add_extension :ext5, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        @prj.extension(:ext5).plugin = @plug
        class << @plug
          undef_method :removing_extension
        end
        lambda{@plug.remove_extensions_from_project @prj, false}.should_not raise_error
      end
      
      it 'doesn\'t attempt to emit the extension_removed signal if the plugin doesn\'t define it' do
        desc = @plug.plugin_description
        desc.extensions[:ext4] = OS.new(:class => @cls_name, :scope => [:document])
        desc.extensions[:ext5] = [
          OS.new(:class_obj => Qt::Object, :scope => [:global]),
          OS.new(:class_obj => Ext, :scope => [:document])
        ]
        @prj.add_extension :ext4, Ext.new(@prj)
        @prj.add_extension :ext5, Ext.new(@prj)
        @prj.extension(:ext4).plugin = @plug
        @prj.extension(:ext5).plugin = @plug
        class << @plug
          undef_method :extension_removed
        end
        lambda{@plug.remove_extensions_from_project @prj, false}.should_not raise_error
      end


    end
    
  end
    
end

describe 'Ruber::Plugin#register_with_project' do
  
  include FlexMock::ArgumentTypes
  
  before do
    @data = {:name => 'test', :class => 'Ruber::Plugin'}
    @app = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    @manager = flexmock{|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @projects = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    @prj = Ruber::Project.new('test.ruprj', 'Test')
  end
  
  it 'calls add_options_to_project passing true as second argument' do
    flexmock(@plug).should_receive(:add_options_to_project).once.with(@prj, true)
    @plug.register_with_project @prj
  end
  
  it 'calls add_widgets_to_project' do
    flexmock(@plug).should_receive(:add_widgets_to_project).once.with(@prj)
    @plug.register_with_project @prj
  end
    
  it 'calls add_extensions_to_project' do
    flexmock(@plug).should_receive(:add_extensions_to_project).once.with(@prj, true)
    @plug.register_with_project @prj
  end
  
end

describe 'Ruber::Plugin#remove_from_project' do
  
  before do
    @data = {:name => 'test', :class => 'Ruber::Plugin'}
    @app = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    @manager = flexmock{|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @projects = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    @prj = Ruber::Project.new('test.ruprj', 'Test')
    @plug.register_with_project @prj
  end

  it 'calls remove_options_from_project passing true as second argument' do
    flexmock(@plug).should_receive(:remove_options_from_project).once.with(@prj, true)
    @plug.remove_from_project @prj
  end
  
  it 'calls remove_widgets_from_project' do
    flexmock(@plug).should_receive(:remove_widgets_from_project).once.with(@prj)
    @plug.remove_from_project @prj
  end

  it 'calls remove_extensions_from_project passing true as second argument' do
    flexmock(@plug).should_receive(:remove_extensions_from_project).once.with(@prj, true)
    @plug.remove_from_project @prj
  end
  
end

describe 'Ruber::Plugin#update_project' do
  
  before do
    @data = {:name => 'test', :class => 'Ruber::Plugin'}
    @app = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    @manager = flexmock{|m| m.should_ignore_missing}
    @projects = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
    @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
    @prj = Ruber::Project.new 'test.ruprj', 'Test'
    @plug.register_with_project @prj
    @doc = Ruber::Document.new __FILE__
  end
  
  it 'calls remove_options_from_project passing false as second argument' do
    flexmock(@plug).should_receive(:remove_options_from_project).once.with(@prj, false)
    @plug.update_project @prj
  end
  
  it 'calls add_options_to_project passing false as second argument' do
    flexmock(@plug).should_receive(:add_options_to_project).once.with(@prj, false)
    @plug.update_project @prj
  end

  it 'calls remove_widgets_from_project passing false as second argument' do
    flexmock(@plug).should_receive(:remove_widgets_from_project).once.with(@prj)
    @plug.update_project @prj
  end
  
  it 'calls add_widgets_to_project passing false as second argument' do
    flexmock(@plug).should_receive(:add_widgets_to_project).once.with(@prj)
    @plug.update_project @prj
  end
  
  it 'calls remove_extensions_from_project passing false as second argument' do
    flexmock(@plug).should_receive(:remove_extensions_from_project).once.with(@prj, false)
    @plug.update_project @prj
  end
  
  it 'calls add_extensions_to_project passing false as second argument' do
    flexmock(@plug).should_receive(:add_extensions_to_project).once.with(@prj, false)
    @plug.update_project @prj
  end
  
end

describe Ruber::Plugin do
  
  it 'has a restore_session method which takes one argument' do
    Ruber::Plugin.instance_method(:restore_session).arity.should == 1
  end
  
  it 'has a private delayed_initialize method' do
    Ruber::Plugin.private_instance_methods.should include(:delayed_initialize)
  end
  
  describe '#session_data' do
    
    it 'returns an empty hash' do
      data = {:name => 'test', :class => 'Ruber::Plugin'}
      app = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(app).by_default
      manager = flexmock{|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(manager).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
      plug = Ruber::Plugin.new Ruber::PluginSpecification.full(data)
      plug.session_data.should == {}
    end
    
  end
  
  describe '#setup_action' do
    
    before do
      @app = KDE::Application.instance
      @components = flexmock('components'){|m| m.should_ignore_missing}
      @main_window = flexmock('main_window'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@main_window).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
      data = { :name => 'test', :actions => {'a1' => {} } }
      pdf = Ruber::PluginSpecification.full(data)
      @action = pdf.actions['a1']
      @plug = Ruber::Plugin.new pdf
      @coll = KDE::XMLGUIClient.new.action_collection
    end
    
    it 'should call the method given in the standard_action entry of the KDE::StandardAction class, if the standard_action entry isn\'t nil' do
      @action.standard_action = :open_new
      @action.action_class = nil
      action = KDE::Action.new @coll
      flexmock(KDE::StandardAction).should_receive(:open_new).once.with(nil, '', KDE::ActionCollection).and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should create a new action of the given class, passing the gui action_collection as argument if the standard_action entry of the data is nil' do
      @action.action_class = KDE::ToggleAction
      action = KDE::Action.new @coll
      flexmock(KDE::ToggleAction).should_receive(:new).with(KDE::ActionCollection).once.and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should return the new action' do
      action = KDE::Action.new @coll
      flexmock(KDE::Action).should_receive(:new).and_return(action).once
      @plug.send(:setup_action, @action, @coll).should equal(action)
    end
    
    it 'should set the text of the action to the value stored in the data if the latter is not empty' do
      @action.text = 'xyz'
      @plug.send(:setup_action, @action, @coll).text.should == 'xyz'
    end
    
    it 'should not set the text of the action to the value stored in the data if the latter is empty' do
      action = KDE::Action.new @coll
      flexmock(action).should_receive(:text=).never
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should set the icon of the action to the value stored in the data if the latter is not empty' do
      @action.icon = KDE::IconLoader.global.iconPath 'document-new', KDE::IconLoader::Small
      icon = Qt::Icon.new @action.icon
      flexmock(Qt::Icon).should_receive(:new).with(@action.icon).once.and_return icon
      @plug.send(:setup_action, @action, @coll).icon.should_not be_null
    end
    
    it 'should not set the icon of the action to the value stored in the data if the latter is not empty' do
      action = KDE::Action.new @coll
      flexmock(action).should_receive(:icon=).never
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      @plug.send :setup_action, @action, @coll
    end

    it 'should set the help text of the action to the value stored in the data if the latter is not empty' do
      @action.help = 'xyz'
      @plug.send(:setup_action, @action, @coll).tool_tip.should == 'xyz'
    end
    
    it 'should not set the help text of the action to the value stored in the data if the latter is empty' do
      action = KDE::Action.new @coll
      flexmock(action).should_receive(:help_text=).never
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should set the shortcut of the action to the value stored in the data, if the latter isn\'t nil' do
      @action.shortcut = KDE::Shortcut.new 'Ctrl+S'
      @plug.send(:setup_action, @action, @coll).shortcut.to_string.should == 'Ctrl+S'
    end
    
    it 'should not set the shortcut of the action to the value stored in the data if the latter is nil' do
      action = KDE::Action.new @coll
      flexmock(action).should_receive(:shortcut=).never
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should connect the signal stored in the data with the slot stored in the data of the receiver obtained by calling instance_eval on self with the recevier stored in the data as argument if the slot is not nil' do
      @action.slot = 'action_triggered(bool)'
      @action.receiver = '@obj'
      obj = Qt::Object.new @plug
      @plug.instance_variable_set(:@obj, obj)
      def @plug.connect *args
      end
      action = KDE::Action.new @coll
      flexmock(@plug).should_receive(:connect).with(action, SIGNAL('triggered(bool)'), obj, SLOT('action_triggered(bool)')).once
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should not attempt to connect a signal of the action if the slot method of the data returns nil' do
      def @plug.connect *args
      end
      action = KDE::Action.new @coll
      flexmock(@plug).should_receive(:connect).never
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      @plug.send(:setup_action, @action, @coll)
    end
    
    it 'should register an ui state handler for the action if the state entry of the data is not nil' do
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app)
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components)
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
      action = KDE::Action.new @coll
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      mw = flexmock('main_window') do |m| 
        m.should_receive(:register_action_handler).with(action,'s1', :extra_id => @plug).once
      end
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return mw
      @action.state = 's1'
      @plug.send(:setup_action, @action, @coll)
    end
        
    it 'should not attempt to register an ui state handler if the state entry of the data is nil' do
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app)
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components)
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil)
      action = KDE::Action.new @coll
      flexmock(KDE::Action).should_receive(:new).with(KDE::ActionCollection).and_return action
      mw = flexmock('main_window') do |m| 
        m.should_receive(:register_action_handler).never
      end
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return mw
      @plug.send(:setup_action, @action, @coll)
    end

  end
  
  describe '#setup_actions' do

    before do
      @app = KDE::Application.instance
      @components = flexmock('components'){|m| m.should_ignore_missing}
      @main_window = flexmock('main_window'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@main_window).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
      data = { :name => 'test', :actions => {'a1' => {:text => '1'}, 'a2' => {:text => '2'}, 'a3' => {:text => '3'} } }
      @pdf = Ruber::PluginSpecification.full(data)
      @plug = Ruber::Plugin.new @pdf
      @gui = KDE::XMLGUIClient.new
    end
    
    it 'should call the setup_action method for each action in the plugin description' do
      coll = @gui.action_collection
      @pdf.actions.each_value do |a|
        flexmock(@plug).should_receive(:setup_action).with(a, KDE::ActionCollection).once.and_return KDE::Action.new(coll)
      end
      @plug.send :setup_actions, coll
    end
    
    it 'should add each action to the action collection' do
      coll = @gui.action_collection
      @plug.send :setup_actions, coll
      @pdf.actions.each_value do |a|
        coll.action(a.name).text.should == a.text
      end
    end
    
  end
  
  describe '#about_data' do
    
    before do
      @data = {:name => :test_plugin, :class => 'Ruber::Plugin'}
      @app = Qt::Object.new
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
      @manager = flexmock{|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(@manager).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(nil).by_default
      @plug = Ruber::Plugin.new Ruber::PluginSpecification.full(@data)
      @desc = @plug.plugin_description
    end
    
    it 'should return an instance of KDE::AboutData' do
      @plug.about_data.should be_a(KDE::AboutData)
    end
    
    it 'should set the app name of the returned object to the plugin name' do
      @plug.about_data.app_name.should == 'test_plugin'
    end
    
    it 'should set the program name of the returned object to human name of the plugin' do
      @desc.about.human_name = 'XyZ'
      @plug.about_data.program_name.should == 'XyZ'
    end
    
    it 'should set the version of the returned object to the version of the plugin' do
      @desc.version = '2.6.4'
      @plug.about_data.version.should == '2.6.4'
    end
    
    it 'should set the license of the returned object to the license of the plugin if the latter is a symbol' do
      Ruber::Plugin::LICENSES.each_pair do |sym, val|
        @desc.about.license = sym
        @plug.about_data.licenses[0].key.should == val
      end
    end
    
    it 'should set the license to Custom and the license text to the license of the plugin if the latter is a string' do
      @desc.about.license = 'My License'
      data = @plug.about_data
      data.licenses[0].key.should == KDE::AboutData::License_Custom
      data.licenses[0].text.should == 'My License'
    end
    
    it 'should add an author (with the respective e-mail, if given) for each of the plugin authors' do
      @desc.about.authors = [['A1', 'a1@something.com'], ['A2']]
      authors = @plug.about_data.authors
      authors.size.should == 2
      authors[0].name.should == 'A1'
      authors[0].email_address.should == 'a1@something.com'
      authors[1].name.should == 'A2'
      authors[1].email_address.should be_empty
    end
    
    it 'should set the short description of the returned object to the description of the plugin' do
      @desc.about.description = 'A pluging which does something'
      @plug.about_data.short_description.should == @desc.about.description
    end
    
    it 'should set the bug address, if given' do
      @plug.about_data.bug_address.should == "submit@bugs.kde.org"
      @desc.about.bug_address = 'xyz@abc.org'
      @plug.about_data.bug_address.should == 'xyz@abc.org'
    end
    
    it 'should set the copyright text of the plugin, if given' do
      @plug.about_data.copyright_statement.should be_nil
      @desc.about.copyright = 'copyright text'
      @plug.about_data.copyright_statement.should == 'copyright text'
    end
    
    it 'should set the homepage, if given' do
      @plug.about_data.homepage.should == ''
      @desc.about.homepage = 'http://something.com'
      @plug.about_data.homepage.should == 'http://something.com'
    end
    
    it 'should set the plugin icon, if given' do
      @plug.about_data.program_icon_name.should == 'test_plugin'
      @desc.about.icon = '/usr/test.png'
      @plug.about_data.program_icon_name.should == '/usr/test.png'
    end
    
  end
  
end
