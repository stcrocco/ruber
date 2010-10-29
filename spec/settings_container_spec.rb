require 'spec/common'
require 'pathname'
require 'set'

require 'ruber/settings_container'

class SimpleContainer
  
  include Ruber::SettingsContainer
  
  def initialize back
    setup_container back
  end
  
end

describe 'Ruber::SettingsContainer' do
  
  before do
    @back = flexmock('backend')
    @back.should_ignore_missing
    @obj = Object.new
    @obj.extend Ruber::SettingsContainer
  end
  
  it 'should create the needed instance variables in the setup_container method' do
    @obj.send :setup_container, @back
    iv = @obj.instance_variables.map{|v| v.to_s}
    %w[@known_options @options @backend @dialog @widgets @dialog_title].each{|i| iv.should include(i)}
  end
  
  it 'should set the @backend instance variable to the object passed as first argument' do
    @obj.send :setup_container, @back
    @obj.instance_variable_get(:@backend).should equal(@back)
  end
  
  it 'should set the @dialog instance variable to nil' do
    @obj.send :setup_container, @back
    @obj.instance_variable_get(:@dialog).should be_nil
  end
  
  it 'should set the base directory to the value of the second argument, if given' do
    @obj.send :setup_container, @back, '/home/stefano'
    @obj.instance_variable_get(:@base_directory).should == '/home/stefano'
  end
  
  it 'should set the base directory to nil, if only one argument is given' do
    @obj.send :setup_container, @back
    @obj.instance_variable_get(:@base_directory).should be_nil
  end
  
  it 'should raise ArgumentError if the second argument is given, but it\'s not an absolute path' do
    lambda{@obj.send :setup_container, @back, 'dir1/dir2'}.should raise_error(ArgumentError, "The second argument to setup_container should be either an absolute path or nil")
  end
  
  it 'sets the dialog_class instance variable to SettingsDialog' do
    @obj.send :setup_container, @back
    @obj.instance_variable_get(:@dialog_class).should == Ruber::SettingsDialog
  end
  
end

describe 'Ruber::SettingsContainer#add_option' do
  
  before do
    @back = flexmock('backend')
    @back.should_ignore_missing
    
    @cont = SimpleContainer.new @back
    @opt = OS.new({:name => :o1, :default => 'abc', :group => :G1})
  end
  
  it 'should add the new option to the list of known options' do
    @cont.add_option @opt
    @cont.instance_variable_get(:@known_options)[[:G1, :o1]].should == @opt
  end
  
  it 'should set the value of the option to that is returned by the backend' do
    @back.should_receive(:[]).with(@opt).once.and_return('xyz')
    @cont.add_option @opt
    @cont.instance_variable_get(:@options)[[:G1, :o1]].should == 'xyz'
  end
  
  it 'should call the delete_dialog method' do
    flexmock(@cont).should_receive(:delete_dialog).once
    @cont.add_option @opt
  end
  
  it 'should raise ArgumentError if an option with the same name and group is already known' do
    @cont.add_option @opt
    lambda{@cont.add_option @opt}.should raise_error(ArgumentError, "An option with name #{@opt.name} belonging to group #{@opt.group} already exists")
  end
  
  
end

describe 'Ruber::SettingsContainer#remove_option' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @opt = OS.new({:name => :o1, :default => 'abc', :group => :G1})
    @cont.add_option @opt
  end
  
  it 'should remove the option whose group and name correspond to the given arguments from the list of known options, when called with two arguments' do
    @cont.remove_option @opt.group, @opt.name
    @cont.instance_variable_get(:@known_options).should_not include([@opt.group, @opt.name])
  end
  
  it 'should remove the option whose group and name correspond to the given arguments from the list of option values, when called with two arguments' do
    @cont.remove_option @opt.group, @opt.name
    @cont.instance_variable_get(:@options).should_not include([@opt.group, @opt.name])
  end
  
  it 'should remove the option corresponding to the one passed as argument from the list of known options, when called with one argument' do
    @cont.remove_option @opt
    @cont.instance_variable_get(:@known_options).should_not include([@opt.group, @opt.name])
  end
  
  it 'should remove the option corresponding to the one passed as argument from the list of option values, when called with one argument' do
    @cont.remove_option @opt
    @cont.instance_variable_get(:@options).should_not include([@opt.group, @opt.name])
  end
  
  it 'should do nothing if an option corresponding to the given argument(s) isn\'t known' do
    old_known = @cont.instance_variable_get(:@known_options).dup
    old_options = @cont.instance_variable_get(:@options).dup
    @cont.remove_option(:o2, :G1)
    @cont.instance_variable_get(:@known_options).should == old_known
    @cont.instance_variable_get(:@options).should == old_options
    @cont.remove_option(OS.new({:name => :o1, :group => :G2}))
    @cont.instance_variable_get(:@known_options).should == old_known
    @cont.instance_variable_get(:@options).should == old_options
  end
  
    it 'should call the delete_dialog method' do
    flexmock(@cont).should_receive(:delete_dialog).once
    @cont.remove_option @opt
  end
  
end

describe 'Ruber::SettingsContainer#has_option?' do
  
  before do
    @back = flexmock('backend')
    @back.should_ignore_missing
    
    @cont = SimpleContainer.new @back
    @opt = OS.new({:name => :o1, :default => 'abc', :group => :G1})
  end
  
  it 'returns true if an option with the given name belonging to the given group is known' do
    @cont.add_option @opt
    @cont.should have_option(@opt.group, @opt.name)
  end
  
  it 'returns false if no options with the given name belonging to the given group are known' do
    @cont.add_option @opt
    @cont.should_not have_option(:G2, @opt.name)
    @cont.should_not have_option(:G1, :x)
    @cont.should_not have_option(:G2, :x)
  end
  
end

describe 'Ruber::SettingsContainer#[]' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    
    @cont = SimpleContainer.new @back
    @options = [OS.new({:name => :o1, :default => 'abc', :group => :G1}), OS.new({:name => :o2, :default => 3, :group => :G2})]
    @back.should_receive(:[]).with(@options[0]).once.and_return('xyz').by_default
    @back.should_receive(:[]).with(@options[1]).once.and_return(3).by_default
    @options.each{|o| @cont.add_option o}
  end

  it 'should return the value of the option with group and name equal to the arguments if called with two arguments' do
    @cont[:G1, :o1].should == 'xyz'
    @cont[:G2, :o2].should == 3
  end
  
  it 'should raise IndexError if the option corresponding to the group and name given isn\'t known, when called with two arguments' do
    lambda{@cont[:G1, :o2]}.should raise_error("An option called o2 belonging to group G1 doesn't exist")
    lambda{@cont[:G2, :o1]}.should raise_error("An option called o1 belonging to group G2 doesn't exist")
    lambda{@cont[:G4, :o3]}.should raise_error("An option called o3 belonging to group G4 doesn't exist")
  end
  
  it 'should treat the value of the option with group and name corresponding to the first two arguments as a path relative to the base directory and return the full path to it, if the third argument is :abs or :absolute and the value is a string' do
    base = '/home/stefano'
    @cont.instance_variable_set :@base_directory, base
    @cont[:G1, :o1, :abs].should == File.join(base, 'xyz')
    @cont[:G1, :o1, :absolute].should == File.join(base, 'xyz')
  end
  
  it 'should treat the value of the option with group and name corresponding to the first two arguments as a path relative to the base directory and return the full path to it, if the third argument is :abs or :absolute and the value is a Pathname' do
    base = '/home/stefano'
    @cont.instance_variable_set :@base_directory, base
    @cont[:G1, :o1] = Pathname.new('xyz')
    @cont[:G1, :o1, :abs].should == Pathname.new(base)+'xyz'
    @cont[:G1, :o1, :absolute].should == Pathname.new(base)+'xyz'
  end
  
  it 'should ignore the third argument if it is different from :abs and :absolute' do
    base = '/home/stefano'
    @cont.instance_variable_set :@base_directory, base
    @cont[:G1, :o1, :xtz].should == 'xyz'
    @cont[:G1, :o1, 3].should == 'xyz'
  end
  
  it 'should ignore the third argument if the value is not a string or a Pathname' do
    base = '/home/stefano'
    @cont.instance_variable_set :@base_directory, base
    @cont[:G1, :o1] = nil
    @cont[:G1, :o1, :abs].should == nil
    @cont[:G1, :o1] = %w[a b c]
    @cont[:G1, :o1, :abs].should == %w[a b c]
  end
  
  it 'should ignore the third argument if the base directory is set to nil' do
    @cont[:G1, :o1, :abs].should == 'xyz'
    @cont[:G1, :o1, :absolute].should == 'xyz'
  end
  
  it 'should return an instance of class Ruber::SettingsContainer::Proxy set to the group passed as argument (even if no options of that group are known) if called with one argument' do
    pr1 = flexmock('proxy1')
    pr2 = flexmock('proxy2')
    flexmock(Ruber::SettingsContainer::Proxy).should_receive(:new).once.with(@cont, :G1).and_return pr1
    flexmock(Ruber::SettingsContainer::Proxy).should_receive(:new).once.with(@cont, :G3).and_return pr2
    @cont[:G1].should equal(pr1)
    @cont[:G3].should equal(pr2)
  end
  
  it 'raises IndexError if a settings with the given name and group doesn\'t exist' do
    lambda{@cont[:G1, :ox]}.should raise_error(IndexError)
    lambda{@cont[:Gx, :o1]}.should raise_error(IndexError)
  end
  
  it 'doesn\'t raises IndexError if only the group name is given' do
    lambda{@cont[:Gx]}.should_not raise_error
  end
  
end

describe 'Ruber::SettingsContainer#[]=' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    
    @cont = SimpleContainer.new @back
    @options = [OS.new({:name => :o1, :default => 'abc', :group => :G1}), OS.new({:name => :o2, :default => 3, :group => :G2})]
    @back.should_receive(:[]).with(@options[0]).once.and_return('xyz').by_default
    @back.should_receive(:[]).with(@options[1]).once.and_return(3).by_default
    @options.each{|o| @cont.add_option o}
  end
  
  it 'should set the content of the option corresponding to the first two arguments to the value passed as third argument' do
    @cont[:G1, :o1] = 'ijk'
    @cont[:G1, :o1].should == 'ijk'
    @cont[:G2, :o2] = 7
    @cont[:G2, :o2].should == 7
  end
  
  it 'should make the value passed as third argument relative to the base directory, and store it as the content corresponding to the first two arguments, if the relative_path method of the option returns true' do
    base = '/home/stefano'
    @cont.instance_variable_set(:@base_directory, base)
    @options[0].relative_path = true
    @cont[:G1, :o1] = File.join base, 'dir1/dir2'
    @cont[:G1, :o1].should == 'dir1/dir2'
  end
  
it 'should not attemp to make the value relative to the base directory if the value isn\'t a string' do
  base = '/home/stefano'
  @cont.instance_variable_set(:@base_directory, base)
  @options[0].relative_path = true
  @cont[:G1, :o1] = 3
  @cont[:G1, :o1].should == 3
end

  
  it 'should not attemp to make the value relative to the base directory if the base directory is nil' do
    @options[0].relative_path = true
    @cont[:G1, :o1] = '/home/stefano/dir1/dir2'
    @cont[:G1, :o1].should == '/home/stefano/dir1/dir2'
  end
  
  it 'should not attemp to make the value relative to the base directory if the value isn\'t an absolute path' do
    base = '/home/stefano'
    @cont.instance_variable_set(:@base_directory, base)
    @options[0].relative_path = true
    @cont[:G1, :o1] = 'stefano/dir1/dir2'
    @cont[:G1, :o1].should == 'stefano/dir1/dir2'
  end
  
  it 'should raise IndexError if no option corresponding to the first two arguments exist' do
    lambda{@cont[:G1, :o2]=1}.should raise_error(IndexError, 'No option called o2 and belonging to group G1 exists')
    lambda{@cont[:G2, :o1]='x'}.should raise_error(IndexError, 'No option called o1 and belonging to group G2 exists')
    lambda{@cont[:G3, :o4]=%w[a b]}.should raise_error(IndexError, 'No option called o4 and belonging to group G3 exists')
  end
  
end

describe 'Ruber::SettingsContainer#default' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @options = [OS.new({:name => :o1, :default => 'abc', :group => :G1}), OS.new({:name => :o2, :default => 3, :group => :G2})]
    @options.each{|o| @cont.add_option o}
  end
  
  it 'should return the default value for the option corresponding to the arguments' do
    obj = Object.new
    @cont.add_option OS.new({:name => :o2, :group => :G1, :default => obj})
    @cont.default(:G1, :o1).should == 'abc'
    @cont.default(:G2, :o2).should == 3
    @cont.default(:G1, :o2).should equal(obj)
  end
  
  it 'should raise IndexError if no options corresponding to the arguments exist' do
    lambda{@cont.default :G1, :o2}.should raise_error(IndexError, 'No option called o2 and belonging to group G1 exists')
    lambda{@cont.default :G2, :o1}.should raise_error(IndexError, 'No option called o1 and belonging to group G2 exists')
    lambda{@cont.default :G3, :o4}.should raise_error(IndexError, 'No option called o4 and belonging to group G3 exists')
  end
  
end

describe 'Ruber::SettingsContainer#relative_path?' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @options = [OS.new({:name => :o1, :default => 'abc', :group => :G1, :relative_path => true}), OS.new({:name => :o2, :default => 3, :group => :G2})]
    @options.each{|o| @cont.add_option o}
  end
  
  it 'should return true if the given option is a relative path option and false otherwise' do
    @cont.relative_path?(:G1, :o1).should be_true
    @cont.relative_path?(:G2, :o2).should be_false
  end
  
  it 'should return true if the given option doesn\'t have a relative_path method' do
    flexmock(@options[0]).should_receive(:relative_path).and_raise(NoMethodError)
    @cont.relative_path?(:G1, :o1).should be_false
  end
  
end

describe 'Ruber::SettingsContainer#add_widget' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
  end
  
  it 'should add the argument to the list of widgets, according to the caption specified in the argument' do
    widgets = [
      OS.new({:caption => 'G1', :class_obj => Qt::Widget}),
      OS.new({:caption => 'G2', :class_obj => Qt::PushButton}),
      OS.new({:caption => 'G1', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'G2', :class_obj => Qt::CheckBox})
    ]
    widgets.each{|w| @cont.add_widget w}
    @cont.instance_variable_get(:@widgets).should == widgets
  end
  
  it 'should call the delete_dialog method' do
    flexmock(@cont).should_receive(:delete_dialog).times(4)
    widgets = [
      OS.new({:caption => 'G1', :class_obj => Qt::Widget}),
      OS.new({:caption => 'G2', :class_obj => Qt::PushButton}),
      OS.new({:caption => 'G1', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'G2', :class_obj => Qt::CheckBox})
    ]
    widgets.each{|w| @cont.add_widget w}
  end
  
end

describe 'Ruber::SettingsContainer#remove_widget' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @widgets = [
      OS.new({:caption => 'G1', :class_obj => Qt::Widget}),
      OS.new({:caption => 'G1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'G2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'G2', :class_obj => Qt::Widget})
      ]
    @widgets.each{|w| @cont.add_widget w}
  end
  
  it 'should remove the given widget from the list' do
    @cont.remove_widget @widgets[0].dup
    widgets = @cont.instance_variable_get(:@widgets).should == @widgets[1..-1]
  end
  
  it 'should call the delete_dialog method' do
    flexmock(@cont).should_receive(:delete_dialog).times(2)
    @cont.remove_widget @widgets[0]
    @cont.remove_widget @widgets[1]
  end
  
  it 'should do nothing if the object passed as argument doesn\'t correspond to a registered widget' do
    flexmock(@cont).should_receive(:delete_dialog).never
    @cont.remove_widget OS.new({:caption => 'G1', :class_obj => Qt::LineEdit})
    @cont.instance_variable_get(:@widgets).should == @widgets
  end
  
end

describe 'Ruber::SettingsContainer#dialog_title=' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
  end
  
  it 'should set the @dialog_title instance variable' do
    @cont.send :dialog_title=, 'Test'
    @cont.instance_variable_get(:@dialog_title).should == 'Test'
  end
  
  it 'should call the delete_dialog method' do
    flexmock(@cont).should_receive(:delete_dialog).once
    @cont.send :dialog_title=, 'Test'
  end
  
end

describe 'Ruber::SettingsContainer#dialog' do
  
  include FlexMock::ArgumentTypes
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
  end
  
  it 'should return the dialog object if it exists' do
    dlg = flexmock 'dialog'
    @cont.instance_variable_set :@dialog, dlg
    flexmock(Ruber::SettingsDialog).should_receive(:new).never
    @cont.dialog.should equal(dlg)
  end
  
  it 'creates and returns a new instance of the class specified in the dialog_class instance variable if the dialog doesn\'t exist' do
    dlg = Qt::Dialog.new
    flexmock(Qt::Dialog).should_receive(:new).once.and_return dlg
    @cont.instance_variable_set :@dialog_class, Qt::Dialog
    res = @cont.dialog
    res.should be_instance_of Qt::Dialog
  end
  
  it 'should create a new dialog, passing it self, a list of options and a list of widgets, store it in the @dialog instance variable and return it if the dialog object is nil' do
    widgets = [
      OS.new({:caption => 'G1', :class_obj => Qt::Widget}),
      OS.new({:caption => 'G1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'G2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'G2', :class_obj => Qt::Widget})
    ]
    widgets.each{|w| @cont.add_widget w}
    opts = [OS.new({:name => :o1, :default => 'abc', :group => :G1}), OS.new({:name => :o2, :default => 3, :group => :G2})]
    values = ['x', 5]
    opts.each_index do |i| 
      @cont.add_option opts[i]
      @cont[opts[i].group, opts[i].name] = values[i]
    end
    flexmock(Ruber::SettingsDialog).should_receive(:new).once.with @cont, on{|a| Set.new(a) == Set.new(opts)}, on{|w| Set.new(w) == Set.new(widgets)}, nil
    @cont.dialog
  end
  
  it 'should set the title of the dialog to the @dialog_title instance variable, if set' do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return @mw
    @cont.dialog.window_title.should == KDE::Application.instance.application_name
    @cont.send :delete_dialog
    @cont.send :dialog_title=, 'Test title'
    @cont.dialog.window_title.should == 'Test title'
  end
  
end

describe 'Ruber::SettingsContainer#delete_dialog' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @dlg = flexmock('dialog'){|m| m.should_ignore_missing}
    @cont.instance_variable_set :@dialog, @dlg
  end
  
  it 'should call the delete_later method on the dialog object' do
    @dlg.should_receive(:delete_later).once
    @cont.send :delete_dialog
  end
  
  it 'should set the @dialog instance variable to nil' do
    @cont.send :delete_dialog
    @cont.instance_variable_get(:@dialog).should be_nil
  end
  
  it 'should do nothing if the @dialog instance variable is nil' do
    @cont.instance_variable_set :@dialog, nil
    lambda{@cont.send :delete_dialog}.should_not raise_error
  end
  
end

describe 'Ruber::SettingsContainer#write' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @options_data = [
      OS.new({:group => 'G1', :name => :o1, :default => 'a'}),
      OS.new({:group => 'G1', :name => :o2, :default => -1}),
      OS.new({:group => 'G2', :name => :o1, :default => nil}),
      OS.new({:group => 'G2', :name => :o3, :default => (1..4)})
      ]
    @options_values = ['b', 5, /a/, nil]
    @options_data.each_index do |i| 
      data = @options_data[i]
      @cont.add_option data
      @cont[data.group, data.name] = @options_values[i]
    end
  end
  
  it 'should call the write method of the backend, passing it the value returned by the collect_options method' do
    exp = @options_data.zip(@options_values).inject({}){|res, i| res[i[0]] = i[1]; res}
    flexmock(@cont).should_receive(:collect_options).once.and_return exp
    @back.should_receive(:write).once.with(exp)
    @cont.write
  end
  
end

describe 'Ruber::SettingsContainer#collect_options' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = SimpleContainer.new @back
    @options_data = [
      OS.new({:group => 'G1', :name => :o1, :default => 'a'}),
      OS.new({:group => 'G1', :name => :o2, :default => -1}),
      OS.new({:group => 'G2', :name => :o1, :default => nil}),
      OS.new({:group => 'G2', :name => :o3, :default => (1..4)})
    ]
    @options_values = ['b', 5, /a/, nil]
    @options_data.each_index do |i| 
      data = @options_data[i]
      @cont.add_option data
      @cont[data.group, data.name] = @options_values[i]
    end
  end
  
  it 'should return a hash having the option objects as keys and the corresponding values as keys' do
    exp = @options_data.zip(@options_values).inject({}){|res, i| res[i[0]] = i[1]; res}
    @cont.send(:collect_options).should == exp
  end
  
end

describe 'Ruber::SettingsContainer::Proxy' do
  
  before do
    @back = flexmock('backend')
    @back.should_ignore_missing
    
    @cont = SimpleContainer.new @back
    @opt = OS.new({:name => :o1, :default => 'abc', :group => :G1})
  end
  
  it 'should inherit BasicObject' do
    Ruber::SettingsContainer::Proxy.ancestors.should include(BasicObject)
  end
  
  it 'should call the [] method of the container, passing the group and the received arguments, when the [] method is called' do
    proxy = Ruber::SettingsContainer::Proxy.new @cont, :G1
    flexmock(@cont).should_receive(:[]).once.with(:G1, :o1, nil).and_return 'a'
    flexmock(@cont).should_receive(:[]).once.with(:G1, :o2, nil).and_return 3
    flexmock(@cont).should_receive(:[]).once.with(:G1, :o1, :abs).and_return ENV['HOME']
    proxy[:o1].should == 'a'
    proxy[:o2].should == 3
    proxy[:o1, :abs].should == ENV['HOME']
  end
  
  it 'should call the []= method of the container, passing the group and the received arguments, when the []= method is called' do
    proxy = Ruber::SettingsContainer::Proxy.new @cont, :G1
    flexmock(@cont).should_receive(:[]=).once.with(:G1, :o1, 1)
    proxy[:o1] = 1
  end
  
  it 'should treat a call to a missing method as a call to [method_name, *args], if the method doesn\'t end in =' do
    proxy = Ruber::SettingsContainer::Proxy.new @cont, :G1
    flexmock(@cont).should_receive(:[]).once.with(:G1, :o1).and_return 'a'
    flexmock(@cont).should_receive(:[]).once.with(:G1, :o2).and_return 3
    flexmock(@cont).should_receive(:[]).once.with(:G1, :o1, :abs).and_return ENV['HOME']
    proxy.o1.should == 'a'
    proxy.o2.should == 3
    proxy.o1(:abs).should == ENV['HOME']
  end
  
  it 'should treat a call to a missing method as a call to [method_name, *args]=, if the method ends in =' do
    proxy = Ruber::SettingsContainer::Proxy.new @cont, :G1
    flexmock(@cont).should_receive(:[]=).once.with(:G1, :o1, 'b')
    flexmock(@cont).should_receive(:[]=).once.with(:G1, :o2, 5)
    flexmock(@cont).should_receive(:[]=).once.with(:G1, :o1, ENV['HOME'])
    proxy.o1= 'b'
    proxy.o2= 5
    proxy.o1= ENV['HOME']
  end
  
end