require 'spec/common'

require 'set'

require 'ruber/settings_dialog_manager'
require 'ruber/settings_dialog'
require 'ruber/settings_container'

describe 'Ruber::SettingsDialogManager' do
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @options = {
      OS.new({:name => :o1, :default => 'abc', :group => :G1}) => 'abc', 
      OS.new({:name => :o2, :default => 3, :group => :G2}) => 1
    }
    @options.each do |k, v|
      @cont.add_option k
      @cont[k.group, k.name] = v
    end
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
  end
    
  it 'should inherit from Qt::Object' do
    dlg = Ruber::SettingsDialog.new @cont, [], []
    manager = Ruber::SettingsDialogManager.new dlg, @options.keys, []
    manager.should be_a(Qt::Object)
  end
  
  it 'should call the setup_option method for each option when created' do
    dlg = Ruber::SettingsDialog.new @cont, [], []
    $settings_dialog_manager_constructor = Set.new
    class Ruber::SettingsDialogManager
      alias_method :old_setup_option, :setup_option
      def setup_option opt
        $settings_dialog_manager_constructor << opt
      end
    end
    manager = Ruber::SettingsDialogManager.new dlg, @options.keys, []
    $settings_dialog_manager_constructor.should == Set.new(@options.keys)
    class Ruber::SettingsDialogManager
      alias_method :setup_option, :old_setup_option
    end
  end
  
end

describe 'Ruber::SettingsDialogManager#setup_option' do
  
  include FlexMock::ArgumentTypes
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @options = {
      OS.new({:name => :o1, :default => 'abc', :group => :G1}) => 'abc', 
      OS.new({:name => :o2, :default => 3, :group => :G2}) => 1,
      OS.new({:name => :o3, :default => nil, :group => :G1}) => /a/
    }
    w = Qt::Widget.new
    w1 = Qt::LineEdit.new( w){|le| le.object_name = '_G1__o1'}
    
    @widgets = [ w, Qt::SpinBox.new{|s| s.object_name = '_G2__o2'} ]
    
    @options.each do |k, v|
      @cont.add_option k
      @cont[k.group, k.name] = v
    end
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @dlg = Ruber::SettingsDialog.new nil, [], []
  end
  
  it 'should call the setup_automatic_option method if one of the widgets, or one of their children has an object name made of: underscore, option group, double underscore, option name' do
    manager = Ruber::SettingsDialogManager.new @dlg, [], @widgets
    options = @options.invert
    lineedit = @widgets[0].find_child(Qt::LineEdit)
    flexmock(manager).should_receive(:setup_automatic_option).once.with(options['abc'], lineedit, @widgets[0])
    flexmock(manager).should_receive(:setup_automatic_option).once.with(options[1], @widgets[1], @widgets[1])
    flexmock(manager).should_receive(:setup_automatic_option).never.with(options[nil], any, any)
    @options.each_key{|v| manager.send :setup_option, v}
  end
  
end

describe 'Ruber::SettingsDialogManager#setup_automatic_option, if the widget has a signle signal in the "signal" property' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @dlg = Ruber::SettingsDialog.new nil, [], []
  end
  
  it 'should connect the object\'s signal with the SettingsDialogManager "settings_changed" slot' do
    widgets = [Qt::LineEdit.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('textChanged(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    def manager.connect;end #needed because otherwise flexmock refuses to create a mock for it, saying it's undefined
    flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL('textChanged(QString)'), manager, SLOT(:settings_changed)).once
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
  end
  
  it 'should automatically determine the signature of the signal, if only the name is given' do
    widgets = [Qt::LineEdit.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('textChanged')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    def manager.connect;end #needed because otherwise flexmock refuses to create a mock for it, saying it's undefined
    flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL('textChanged(QString)'), manager, SLOT(:settings_changed)).once
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
  end
  
  it 'should raise ArgumentError if the signature of the signal isn\'t given and no signal matches the given name' do
    widgets = [Qt::LineEdit.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('my_signal')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    lambda do
      manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
    end.should raise_error(ArgumentError, "No signal with name 'my_signal' exist")
  end
  
  it 'should raise ArgumentError if the signature of the signal isn\'t given and more than one signal has the given name' do
    widgets = [Qt::ComboBox.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('currentIndexChanged')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
      lambda do
        manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
      end.should raise_error(ArgumentError, "Ambiguous signal name, 'currentIndexChanged'")
  end
  
  it 'should associate the option with widget and its "read" property, if given' do
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'read', Qt::Variant.new('text_from_option')
    end
    widgets = [w]
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text_from_option']
  end
  
  it 'should associate the option with widget and its "store" property, if given' do
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'store', Qt::Variant.new('text_to_option')
    end
    widgets = [w]
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text_to_option']
  end
  
  it 'should raise ArgumentError if the widget has the read and/or the store properties together with the access property' do
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'store', Qt::Variant.new('text_to_option')
      wi.set_property 'access', Qt::Variant.new('option')
    end
    
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    lambda do 
      manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    end.should raise_error(ArgumentError, 'The widget _G1__o1 has both the access property and one or both of the store and read properties')
    
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'read', Qt::Variant.new('option_to_text')
      wi.set_property 'access', Qt::Variant.new('option')
    end
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    lambda do 
      manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    end.should raise_error(ArgumentError, 'The widget _G1__o1 has both the access property and one or both of the store and read properties')
    
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'store', Qt::Variant.new('text_to_option')
      wi.set_property 'read', Qt::Variant.new('option_to_text')
      wi.set_property 'access', Qt::Variant.new('option')
    end
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    lambda do 
      manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    end.should raise_error(ArgumentError, 'The widget _G1__o1 has both the access property and one or both of the store and read properties')
  end
  
  it 'should use the widget\'s "access" insteaod of the "store" property, if it exists' do
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'access', Qt::Variant.new('option')
    end
    widgets = [w]
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'option']
  end
  
  it 'should derive the "read" property from the widget\'s "access" property, if it exists, by removing the ending ? or ! (if it exists) and by adding an ending =' do
    w = Qt::LineEdit.new do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'access', Qt::Variant.new('option')
    end
    widgets = [w]
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'option=']
    
    w.set_property 'access', Qt::Variant.new('option?')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'option=']
    
    w.set_property 'access', Qt::Variant.new('option!')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'option=']

  end
  
  it 'should associate the option with the widget\'s top-level widget for reading, storing or both if respectively the "read", "store" or "access" property begin with $' do
    top = Qt::Widget.new
    w = Qt::LineEdit.new(top) do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'read', Qt::Variant.new('$text_from_option')
      wi.set_property 'store', Qt::Variant.new('option_from_text')
    end
    widgets = [top]
    manager = Ruber::SettingsDialogManager.new @dlg, [], top
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, top
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [top, 'text_from_option']
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'option_from_text']
    
    top = Qt::Widget.new
    w = Qt::LineEdit.new(top) do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'read', Qt::Variant.new('text_from_option')
      wi.set_property 'store', Qt::Variant.new('$option_from_text')
    end
    widgets = [top]
    manager = Ruber::SettingsDialogManager.new @dlg, [], top
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, top
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text_from_option']
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [top, 'option_from_text']
    
    top = Qt::Widget.new
    w = Qt::LineEdit.new(top) do |wi| 
      wi.object_name = '_G1__o1'
      wi.set_property 'signal', Qt::Variant.new('textChanged(QString)')
      wi.set_property 'access', Qt::Variant.new('$option')
    end
    widgets = [top]
    manager = Ruber::SettingsDialogManager.new @dlg, [], top
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), w, top
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [top, 'option=']
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [top, 'option']
  end

  it 'should generate the "store" property from the name of the signal, removing the changed/edited/modified words from its end, if the object has neither "store" nor the "access" property' do
    w = Qt::LineEdit.new{|wi| wi.object_name = '_G1__o1'}
    opt = OS.new({:name => :o1, :group => :G1, :default => 'abc'})
    
    w.set_property 'signal',  Qt::Variant.new( 'textChanged(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'textModified(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'textEdited(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_changed(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_modified(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_edited(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'state(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'state']
  end
  
    it 'should generate the "store" property from the name of the signal, removing the changed/edited/modified words from its end, if the object has neither "store" nor the "access" property' do
    w = Qt::LineEdit.new{|wi| wi.object_name = '_G1__o1'}
    opt = OS.new({:name => :o1, :group => :G1, :default => 'abc'})
    
    w.set_property 'signal',  Qt::Variant.new( 'textChanged(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'textModified(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'textEdited(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_changed(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_modified(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_edited(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'text']
    
    w.set_property 'signal',  Qt::Variant.new( 'state(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:store].should == [w, 'state']
  end
  
  it 'should generate the "read" property from the name of the signal, removing the changed/edited/modified words from its end and adding a final =, if the object has neither "read" nor the "access" property' do
    w = Qt::LineEdit.new{|wi| wi.object_name = '_G1__o1'}
    opt = OS.new({:name => :o1, :group => :G1, :default => 'abc'})
    
    w.set_property 'signal',  Qt::Variant.new( 'textChanged(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text=']
    
    w.set_property 'signal',  Qt::Variant.new( 'textModified(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text=']
    
    w.set_property 'signal',  Qt::Variant.new( 'textEdited(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text=']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_changed(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text=']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_modified(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text=']
    
    w.set_property 'signal',  Qt::Variant.new( 'text_edited(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'text=']
    
    w.set_property 'signal',  Qt::Variant.new( 'state(QString)')
    manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
    manager.send :setup_automatic_option, opt, w, w
    manager.instance_variable_get(:@associations)[w.object_name][:read].should == [w, 'state=']
  end

end

describe 'Ruber::SettingsDialogManager#setup_automatic_option, when the widget specifies more than one signal' do

  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @dlg = Ruber::SettingsDialog.new nil, [], []
  end  
  
  it 'should connect each of its signals to the settings_changed slot' do
    widgets = [Qt::LineEdit.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('[textChanged(QString), textEdited(QString)]')
    widgets[0].set_property 'access', Qt::Variant.new('text')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    def manager.connect;end #needed because otherwise flexmock refuses to create a mock for it, saying it's undefined
    flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL('textChanged(QString)'), manager, SLOT(:settings_changed)).once
    flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL('textEdited(QString)'), manager, SLOT(:settings_changed)).once
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
  end
  
  it 'should automatically determine the signatures of the signals' do
    widgets = [Qt::LineEdit.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('[textChanged, textEdited]')
    widgets[0].set_property 'access', Qt::Variant.new('text')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    def manager.connect;end #needed because otherwise flexmock refuses to create a mock for it, saying it's undefined
    flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL('textChanged(QString)'), manager, SLOT(:settings_changed)).once
    flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL('textEdited(QString)'), manager, SLOT(:settings_changed)).once
    manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
  end
  
  it 'should raise ArgumentError if the widget doesn\'t have the "access" property or both the "store" and the "read" properties' do
    widgets = [Qt::LineEdit.new{|w| w.object_name = '_G1__o1'}]
    widgets[0].set_property 'signal', Qt::Variant.new('[textChanged, textEdited]')
    manager = Ruber::SettingsDialogManager.new @dlg, [], widgets
    lambda do
      manager.send :setup_automatic_option, OS.new({:name => :o1, :group => :G1, :default => 'abc'}), widgets[0], widgets[0]
    end.should raise_error(ArgumentError, "When more signals are specified, you need to specify also the access property or both the read and store properties")
  end
  
end

describe 'Ruber::SettingsDialogManager#setup_automatic_option, when no signal is specified' do
  
  defaults = [
    [ Qt::CheckBox , 'toggled(bool)', "checked?"],
    [Qt::PushButton , 'toggled(bool)', "checked?"],
    [KDE::PushButton , 'toggled(bool)', "checked?"],
    [KDE::ColorButton, 'changed(QColor)', "color"],
    [KDE::IconButton, 'iconChanged(QString)', "icon"],
    [Qt::LineEdit , 'textChanged(QString)', "text"],
    [KDE::LineEdit , 'textChanged(QString)', "text"],
    [KDE::RestrictedLine, 'textChanged(QString)', "text"],
    [Qt::ComboBox, 'currentIndexChanged(int)', "current_index"],
    [KDE::ComboBox, 'currentIndexChanged(int)', "current_index"],
    [KDE::ColorCombo, 'currentIndexChanged(int)', "color"],
    [Qt::TextEdit, 'textChanged(QString)', "text"],
    [KDE::TextEdit, 'textChanged(QString)', "text"],
    [Qt::PlainTextEdit, 'textChanged(QString)', "text"],
    [Qt::SpinBox, 'valueChanged(int)', "value"],
    [KDE::IntSpinBox, 'valueChanged(int)', "value"],
    [Qt::DoubleSpinBox, 'valueChanged(double)', "value"],
    [KDE::IntNumInput, 'valueChanged(int)', "value"],
    [KDE::DoubleNumInput, 'valueChanged(double)', "value"],
    [Qt::TimeEdit, 'timeChanged(QTime)', "time"],
    [Qt::DateEdit, 'dateChanged(QDate)', "date"],
    [Qt::DateTimeEdit, 'dateTimeChanged(QDateTime)', "date_time"],
    [Qt::Dial, 'valueChanged(int)', "value"],
    [Qt::Slider, 'valueChanged(int)', "value"],
    [KDE::DatePicker, 'dateChanged(QDate)', "date"],
    [KDE::DateTimeWidget, 'valueChanged(QDateTime)', "date_time"],
    [KDE::DateWidget, 'changed(QDate)', "date"],
    [KDE::FontComboBox, 'currentFontChanged(QFont)', "current_font"],
    [KDE::FontRequester, 'fontSelected(QFont)', "font"],
    [KDE::UrlRequester, 'textChanged(QString)', "url"]
  ]
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @dlg = Ruber::SettingsDialog.new nil, [], []
  end
  
  defaults.each do |cls, *s|
    desc = "should behave as if the widget had'#{s[0]}' for the \"signal\" property and '#{s[1]}' for the \"accessor\" property, if the object is of class #{cls} and neither the 'access' nor the 'read' and 'store' properties have been specified"
    it desc do
      extend FlexMock::ArgumentTypes
      widgets = [cls.new{|w| w.object_name = '_G1__o1'}]
      opt = OS.new({:name => :o1, :group => :G1, :default => 'x'})
      manager = Ruber::SettingsDialogManager.new @dlg, [opt], widgets
      def manager.connect;end
      flexmock(manager).should_receive(:connect).once.with(widgets[0], SIGNAL(s[0]), manager, SLOT(:settings_changed))
      manager.send :setup_automatic_option, opt, widgets[0], widgets[0]
      assoc = manager.instance_variable_get(:@associations)
      assoc['_G1__o1'][:store][1].should == s[1]
      assoc['_G1__o1'][:read][1].should == s[1].sub(/[\?!]$/, '') + '='
    end
  end
  
  defaults.each do |cls, *s|
    desc = "should behave as if the widget had'#{s[0]}' for the \"signal\" property if the object is of class #{cls} and the 'access' property has been specified"
    it desc do
      extend FlexMock::ArgumentTypes
      w = cls.new do |w|
        w.object_name = '_G1__o1'
        w.set_property 'access', Qt::Variant.new('option')
      end
      opt = OS.new({:name => :o1, :group => :G1, :default => 'x'})
      manager = Ruber::SettingsDialogManager.new @dlg, [opt], [w]
      def manager.connect;end
      flexmock(manager).should_receive(:connect).once.with(w, SIGNAL(s[0]), manager, SLOT(:settings_changed))
      manager.send :setup_automatic_option, opt, w, w
      assoc = manager.instance_variable_get(:@associations)
      assoc['_G1__o1'][:store][1].should == 'option'
      assoc['_G1__o1'][:read][1].should == 'option='
    end
  end
  
  defaults.each do |cls, *s|
    desc = "should behave as if the widget had'#{s[0]}' for the \"signal\" property if the object is of class #{cls} and the 'read' and 'store' properties have been specified"
    it desc do
      extend FlexMock::ArgumentTypes
      w = cls.new do |w|
        w.object_name = '_G1__o1'
        w.set_property 'read', Qt::Variant.new('option=')
        w.set_property 'store', Qt::Variant.new('option')
      end
      opt = OS.new({:name => :o1, :group => :G1, :default => 'x'})
      manager = Ruber::SettingsDialogManager.new @dlg, [opt], [w]
      def manager.connect;end
      flexmock(manager).should_receive(:connect).once.with(w, SIGNAL(s[0]), manager, SLOT(:settings_changed))
      manager.send :setup_automatic_option, opt, w, w
      assoc = manager.instance_variable_get(:@associations)
      assoc['_G1__o1'][:store][1].should == 'option'
      assoc['_G1__o1'][:read][1].should == 'option='
    end
  end
  
    it 'should raise ArgumentError if the object is of an unknown class' do
      w = Qt::Frame.new{|w| w.object_name = '_G1__o1'}
      manager = Ruber::SettingsDialogManager.new @dlg, [], [w]
      opt = OS.new({:name => :o1, :group => :G1, :default => 'x'})
      lambda do
        manager.send :setup_automatic_option, opt, w, w
      end.should raise_error(ArgumentError, "No default signal exists for class Qt::Frame, you need to specify one")
    end
  
end

describe 'Ruber::SettingsDialog#convert_value' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @dlg = @cont.dialog
    @manager = @dlg.instance_variable_get(:@manager)
  end
  
  it 'should return the firts argument if both argument are of the same class' do
    str1 = "abc"
    @manager.send(:convert_value, str1, "xyz").should equal(str1)
    @manager.send(:convert_value, 1, 2).should == 1
  end
  
  it 'should return the first argument if there\'s no conversion method from the class of the first to the class of the second' do
    a = [1,2, 3]
    @manager.send(:convert_value, a, "xyz").should equal(a)
    h = {:a => 1, :b => 2}
    @manager.send(:convert_value, h, []).should equal(h)
  end
  
  it 'should convert a string to a symbol and vice versa' do
    @manager.send(:convert_value, :xyz, "abc").should == 'xyz'
    @manager.send(:convert_value, 'xyz', :abc).should == :xyz
  end
  
  it 'should convert a string to a KDE::Url and vice versa' do
    @manager.send(:convert_value, ENV['HOME'], KDE::Url.new).should == KDE::Url.from_path(ENV['HOME'])
    @manager.send(:convert_value, KDE::Url.from_path(ENV['HOME']), '').should == ENV['HOME']
    @manager.send(:convert_value, KDE::Url.new, '').should == ''
  end

  it 'should convert a string to a FixNum and vice versa' do
    @manager.send(:convert_value, 1, '').should == '1'
    @manager.send(:convert_value, '1', 0).should == 1
  end
  
  it 'should convert a string to a Float and vice versa' do
    @manager.send(:convert_value, 1.2, '').should == 1.2.to_s
    @manager.send(:convert_value, '1.2', 1.0).should == 1.2
  end
  
  it 'should not convert true to false or vice versa' do
    @manager.send(:convert_value, true, false).should be_true
    @manager.send(:convert_value, false, true).should be_false
  end
  
end

describe 'Ruber::SettingsDialog#read_settings' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @options = [
      OS.new({:name => :o1, :default => 3, :group => :G1}),
      OS.new({:name => :o2, :default => "abc", :group => :G2}),
      OS.new({:name => :o3, :default => true, :group => :G1}),
      ]
    @option_values = [-2, "xyz", false]
    @options.each{|o| @cont.add_option o}
    @options.zip(@option_values).each{|op, val| @cont[op.group, op.name] = val}
  end
  
  it 'should call the read methods associated to each option, passing as argument the value of the option read from the option container' do
    widgets_data = [
      OS.new({:caption => 'C1', :code => 'Qt::LineEdit.new{|w| w.object_name = "_G2__o2"}'}),
      OS.new({:caption => 'C1', :code => 'Qt::CheckBox.new{|w| w.object_name = "_G1__o3"}'})
      ]
    widgets_data.each{|w| @cont.add_widget w}
    dlg = @cont.dialog
    flexmock(dlg.find_child(Qt::LineEdit, '_G2__o2')).should_receive(:text=).once.with('xyz')
    flexmock(dlg.find_child(Qt::CheckBox, '_G1__o3')).should_receive(:checked=).once.with(false)
    dlg.instance_variable_get(:@manager).read_settings
  end
  
  it 'should convert the values stored in the options by passing them to the "convert_value" method before updating the widgets' do
    opt = OS.new({:name => :o1, :group => :G3, :default => :abc})
    @cont.add_option opt
    @cont[:G2, :o2] = ENV['HOME']
    @cont[:G3, :o1] = :xyz
    widgets_data = [
      OS.new({:caption => 'C1', :code => 'Qt::LineEdit.new{|w| w.object_name = "_G3__o1"}'}),
      OS.new({:caption => 'C1', :code => 'KDE::UrlRequester.new{|w| w.object_name = "_G2__o2"}'})
    ]
    widgets_data.each{|w| @cont.add_widget w}
    dlg = @cont.dialog
    flexmock(dlg.find_child(Qt::LineEdit, '_G3__o1')).should_receive(:text=).once.with('xyz')
    flexmock(dlg.find_child(KDE::UrlRequester, '_G2__o2')).should_receive(:url=).once.with KDE::Url.from_path(ENV['HOME'])
    manager = dlg.instance_variable_get(:@manager)
    flexmock(manager).should_receive(:convert_value).once.with(ENV['HOME'], KDE::Url.new).and_return(KDE::Url.from_path(ENV['HOME']))
    flexmock(manager).should_receive(:convert_value).once.with(:xyz, '').and_return('xyz')
    manager.read_settings
  end
  
end

describe 'Ruber::SettingsDialogManager#store_settings' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @options = [
      OS.new({:name => :o1, :default => 3, :group => :G1}),
      OS.new({:name => :o2, :default => "abc", :group => :G2}),
      OS.new({:name => :o3, :default => true, :group => :G1}),
      ]
    @option_values = [-2, "xyz", false]
    @options.each{|o| @cont.add_option o}
    @options.zip(@option_values).each{|op, val| @cont[op.group, op.name] = val}
  end
  
  it 'store the value of each option, read using the corresponding "store" method, in the container' do
    widgets_data = [
      OS.new({:caption => 'C1', :code => 'Qt::LineEdit.new{|w| w.object_name = "_G2__o2"}'}),
      OS.new({:caption => 'C1', :code => 'Qt::CheckBox.new{|w| w.object_name = "_G1__o3"}'})
    ]
    widgets_data.each{|w| @cont.add_widget w}
    dlg = @cont.dialog
    flexmock(dlg.find_child(Qt::LineEdit, '_G2__o2')).should_receive(:text).once.and_return('hello')
    flexmock(dlg.find_child(Qt::CheckBox, '_G1__o3')).should_receive(:checked?).once.and_return true
    flexmock(@cont).should_receive(:[]=).once.with(:G1, :o3, true)
    flexmock(@cont).should_receive(:[]=).once.with(:G2, :o2, 'hello')
    dlg.instance_variable_get(:@manager).store_settings
    
  end
  
  it 'should convert the values stored in the options by passing them to the "convert_value" method before updating the container' do
    opt = OS.new({:name => :o1, :group => :G3, :default => :abc})
    @cont.add_option opt
    @cont[:G2, :o2] = ''
    @cont[:G3, :o1] = :abcd
    widgets_data = [
      OS.new({:caption => 'C1', :code => 'Qt::LineEdit.new{|w| w.object_name = "_G3__o1"}'}),
      OS.new({:caption => 'C1', :code => 'KDE::UrlRequester.new{|w| w.object_name = "_G2__o2"}'})
    ]
    widgets_data.each{|w| @cont.add_widget w}
    dlg = @cont.dialog
    flexmock(dlg.find_child(Qt::LineEdit, '_G3__o1')).should_receive(:text).once.and_return('xyz')
    flexmock(dlg.find_child(KDE::UrlRequester, '_G2__o2')).should_receive(:url).once.and_return KDE::Url.from_path(ENV['HOME'])
    manager = dlg.instance_variable_get(:@manager)
    flexmock(manager).should_receive(:convert_value).once.with(KDE::Url.from_path(ENV['HOME']), '').and_return(ENV['HOME'])
    flexmock(manager).should_receive(:convert_value).once.with('xyz', :abcd).and_return(:xyz)
    flexmock(@cont).should_receive(:[]=).once.with(:G3, :o1, :xyz)
    flexmock(@cont).should_receive(:[]=).once.with(:G2, :o2, ENV['HOME'])
    manager.store_settings
  end
  
end

describe 'Ruber::SettingsDialog#read_default_settings' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @options = [
      OS.new({:name => :o1, :default => 3, :group => :G1}),
      OS.new({:name => :o2, :default => "abc", :group => :G2}),
      OS.new({:name => :o3, :default => true, :group => :G1}),
      ]
    @option_values = [-2, "xyz", false]
    @options.each{|o| @cont.add_option o}
    @options.zip(@option_values).each{|op, val| @cont[op.group, op.name] = val}
  end
  
  it 'should call the read methods associated to each option, passing as argument the default value of the option read from the option container' do
    widgets_data = [
      OS.new({:caption => 'C1', :code => 'Qt::LineEdit.new{|w| w.object_name = "_G2__o2"}'}),
      OS.new({:caption => 'C1', :code => 'Qt::CheckBox.new{|w| w.object_name = "_G1__o3"}'})
    ]
    widgets_data.each{|w| @cont.add_widget w}
    dlg = @cont.dialog
    flexmock(dlg.find_child(Qt::LineEdit, '_G2__o2')).should_receive(:text=).once.with(@options[1].default)
    flexmock(dlg.find_child(Qt::CheckBox, '_G1__o3')).should_receive(:checked=).once.with(@options[2].default)
    dlg.instance_variable_get(:@manager).read_default_settings
  end
  
  it 'should convert the default values of the options by passing them to the "convert_value" method before updating the widgets' do
    opt = OS.new({:name => :o1, :group => :G3, :default => :abc})
    @cont.add_option opt
    @cont[:G2, :o2] = ENV['HOME']
    @cont[:G3, :o1] = :xyz
    widgets_data = [
      OS.new({:caption => 'C1', :code => 'Qt::LineEdit.new{|w| w.object_name = "_G3__o1"}'}),
      OS.new({:caption => 'C1', :code => 'KDE::UrlRequester.new{|w| w.object_name = "_G2__o2"}'})
    ]
    widgets_data.each{|w| @cont.add_widget w}
    dlg = @cont.dialog
    flexmock(@cont).should_receive(:default).once.with(:G2, :o2).and_return('/usr')
    flexmock(@cont).should_receive(:default).once.with(:G3, :o1).and_return(:abc)
    flexmock(dlg.find_child(Qt::LineEdit, '_G3__o1')).should_receive(:text=).once.with('abc')
    flexmock(dlg.find_child(KDE::UrlRequester, '_G2__o2')).should_receive(:url=).once.with KDE::Url.from_path('/usr')
    manager = dlg.instance_variable_get(:@manager)
    flexmock(manager).should_receive(:convert_value).once.with('/usr', KDE::Url.new).and_return(KDE::Url.from_path('/usr'))
    flexmock(manager).should_receive(:convert_value).once.with(:abc, '').and_return('abc')
    manager.read_default_settings
  end
  
end

describe 'Ruber::SettingsDialogManager#settings_changed' do
  
  it 'should enable the Apply button of the dialog' do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default    
    back = flexmock('backend'){|m| m.should_ignore_missing}
    cont = Object.new
    cont.extend Ruber::SettingsContainer
    cont.send :setup_container, back
    dlg = cont.dialog
    flexmock(dlg).should_receive(:enable_button_apply).once.with(true)
    dlg.instance_variable_get(:@manager).send :settings_changed
  end
  
end