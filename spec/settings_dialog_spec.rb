require 'spec/common'

require 'ruber/settings_dialog'
require 'ruber/settings_container'

describe 'Ruber::SettingsDialog, when created' do
  
  include FlexMock::ArgumentTypes
  
  before do
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
  end
  
  it 'should set its title to the fourth argument, if given' do
    dlg = Ruber::SettingsDialog.new @cont, {}, [], 'Title'
    dlg.window_title.should == 'Title'
    dlg = Ruber::SettingsDialog.new @cont, {}, []
    dlg.window_title.should == KDE::Application.instance.application_name
  end
  
  it 'should store the first argument in the @container instance variable' do
    dlg = Ruber::SettingsDialog.new @cont, {}, []
    dlg.instance_variable_get(:@container).should equal(@cont)
  end  
  
  it 'should create the widgets specified in the third argument and store it in the @pages instance variable, grouped by captions' do
    @widgets.each{|w| @cont.add_widget w}
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    res = dlg.instance_variable_get(:@widgets)
    res['C1'][0].should be_a(Qt::CheckBox)
    res['C1'][1].should be_a(Qt::ComboBox)
    res['C2'][0].should be_a(Qt::LineEdit)
    res['C2'][1].should be_a(Qt::PushButton)
    res['C2'][1].text.should == 'test'
  end
  
  it 'should add an @settings_dialog instance variable and set it to self for each widget it creates' do
    @widgets.each{|w| @cont.add_widget w}
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    widgets = dlg.instance_variable_get(:@widgets).values.flatten
    widgets.each{|w| w.instance_variable_get(:@settings_dialog).should equal(dlg)}
  end
  
  it 'should add a page for each caption and store the corresponding PageWidgetItems in the @page_items instance variable' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    dlg.instance_variable_get(:@page_items).size.should == 2
  end
  
  it 'should create a page for each caption, in alphabetical order, with the widgets stored in a vertical layout, from first to last' do
    @widgets.unshift @widgets.delete_at(1)
    @widgets.each{|w| @cont.add_widget w}
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    items = dlg.instance_variable_get :@page_items
    
    l = items[0].widget.layout
    l.should be_a(Qt::VBoxLayout)
    l.item_at(0).widget.should be_a(Qt::CheckBox)
    l.item_at(1).widget.should be_a(Qt::ComboBox)
    
    l = items[1].widget.layout
    l.item_at(0).widget.should be_a(Qt::LineEdit)
    l.item_at(1).widget.should be_a(Qt::PushButton)
  end
  
  it 'should use the first specified icon for each page' do
    %w[xyz.png 123.png 456.png abc.png].each_with_index{|p, i| @widgets[i].pixmap = p}
    @widgets.each{|w| @cont.add_widget w}
    icons = [KDE::Icon.new( 'xyz.png'), KDE::Icon.new('123.png')]
    flexmock(KDE::Icon).should_receive(:new).once.with('xyz.png').and_return(icons[0])
    flexmock(KDE::Icon).should_receive(:new).once.with('123.png').and_return(icons[1])
    flexmock(KDE::Icon).should_receive(:new).with('abc.png').never
    flexmock(KDE::Icon).should_receive(:new).with('456.png').never
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    items = dlg.instance_variable_get :@page_items
  end
  
  it 'should create an instance of the SettingsDialogManager class, passing it self, the widgets and the options' do
    options = {
      OS.new({:group => 'G1', :name => :o1, :default => 2}) => 3, 
      OS.new({:group => :G2, :name => :o2, :default => 'xyz'}) => 'abc'
    }
    @widgets.each{|w| @cont.add_widget w}
    flexmock(Ruber::SettingsDialogManager).should_receive(:new).once.with(Ruber::SettingsDialog, options, on{|a| a.map(&:class) == [Qt::CheckBox, Qt::ComboBox, Qt::LineEdit, Qt::PushButton]})
    dlg = Ruber::SettingsDialog.new @cont, options, @widgets
  end
  
end

describe 'Ruber::SettingsDialog#read_settings' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
  end
  
  it 'should call the read_settings method of each widget which provides it' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    widgets = dlg.instance_variable_get(:@widgets)
    
    widgets['C1'][0].instance_eval do
      def read_settings
      end
    end
    flexmock(widgets['C1'][0]).should_receive(:read_settings).once
    
    widgets['C1'][1].instance_eval do
      def read_settings
      end
    end
    flexmock(widgets['C1'][1]).should_receive(:read_settings).once
    
    widgets['C2'][0].instance_eval do
      def read_settings
      end
    end
    flexmock(widgets['C2'][0]).should_receive(:read_settings).once
    
    dlg.read_settings
  end
  
  it 'should call the read_settings method of the option manager' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg.instance_variable_get(:@manager)).should_receive(:read_settings).once
    dlg.read_settings
  end
  
end

describe 'Ruber::SettingsDialog#store_settings' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
  end
  
  it 'should call the store_settings method of each widget which provides it' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    widgets = dlg.instance_variable_get(:@widgets)
    
    widgets['C1'][0].instance_eval do
      def store_settings
      end
    end
    flexmock(widgets['C1'][0]).should_receive(:store_settings).once
    
    widgets['C1'][1].instance_eval do
      def store_settings
      end
    end
    flexmock(widgets['C1'][1]).should_receive(:store_settings).once
    
    widgets['C2'][0].instance_eval do
      def store_settings
      end
    end
    flexmock(widgets['C2'][0]).should_receive(:store_settings).once
    
    dlg.store_settings
  end
  
  it 'should call the store_settings method of the option manager' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg.instance_variable_get(:@manager)).should_receive(:store_settings).once
    dlg.store_settings
  end
  
  it 'should call the "write" method of the container, after all the store_settings methods have been called' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    widgets = dlg.instance_variable_get(:@widgets)
    widgets['C1'][0].instance_eval do
      def store_settings
      end
    end
    flexmock(dlg.instance_variable_get(:@manager)).should_receive(:store_settings).once.globally.ordered
    flexmock(widgets['C1'][0]).should_receive(:store_settings).once.globally.ordered
    flexmock(@cont).should_receive(:write).once.globally.ordered
    dlg.store_settings
  end
  
  it 'should be called when the Ok button is clicked' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg).should_receive(:store_settings).once
    dlg.instance_eval{emit okClicked}
  end
  
  it 'should be called when the Apply button is clicked' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg).should_receive(:store_settings).once
    dlg.instance_eval{emit applyClicked}
  end
  
end

describe 'Ruber::SettingsDialog#read_default_settings' do
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
  end
  
  it 'should call the read_default_settings method of each widget which provides it' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    widgets = dlg.instance_variable_get(:@widgets)
    
    widgets['C1'][0].instance_eval do
      def read_default_settings
      end
    end
    flexmock(widgets['C1'][0]).should_receive(:read_default_settings).once
    
    widgets['C1'][1].instance_eval do
      def read_default_settings
      end
    end
    flexmock(widgets['C1'][1]).should_receive(:read_default_settings).once
    
    widgets['C2'][0].instance_eval do
      def read_default_settings
      end
    end
    flexmock(widgets['C2'][0]).should_receive(:read_default_settings).once
    
    dlg.read_default_settings
  end
  
  it 'should call the read_default_settings method of the option manager' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg.instance_variable_get(:@manager)).should_receive(:read_default_settings).once
    dlg.read_default_settings
  end
  
  it 'should be called when the Default button is clicked' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg).should_receive(:read_default_settings).once
    dlg.instance_eval{emit defaultClicked}
  end
  
end

describe 'Ruber::SettingsDialog#exec' do
  
  before(:all) do
    class ::KDE::PageDialog
      def exec
      end
    end
  end
  
  after(:all) do
    class ::KDE::PageDialog
      undef_method :exec
    end
  end
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
  end
  
  it 'should call the read_settings method' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg).should_receive(:read_settings).once
    dlg.exec
  end
  
  it 'should make the first page current' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
# It seems that comparing the objects themselves doesn't work, as they seem to 
# have different object_id s. To avoid problems, we give a name to each
    dlg.instance_variable_get(:@page_items).each_with_index{|w, i| w.object_name = i.to_s}
    dlg.current_page = dlg.instance_variable_get(:@page_items)[1]
    dlg.exec
    dlg.current_page.object_name.should == '0'
  end
  
  it 'should give focus to the first widget in the page' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg.instance_variable_get(:@widgets)['C1'][0]).should_receive(:set_focus).once
    dlg.exec
  end
  
  it 'shouldn\'t attempt to make the first page current if there are no pages' do
    dlg = Ruber::SettingsDialog.new @cont, [], []
    lambda{dlg.exec}.should_not raise_error
  end
  
end

describe 'Ruber::SettingsDialog#show' do
  
  before(:all) do
    class ::KDE::PageDialog
      def show
      end
    end
  end
  
  after(:all) do
    class ::KDE::PageDialog
      undef_method :show
    end
  end
  
  before do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
  end
  
  it 'should call the read_settings method' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg).should_receive(:read_settings).once
    dlg.show
  end
  
  it 'should make the first page current' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    # It seems that comparing the objects themselves doesn't work, as they seem to 
    # have different object_id s. To avoid problems, we give a name to each
    dlg.instance_variable_get(:@page_items).each_with_index{|w, i| w.object_name = i.to_s}
    dlg.current_page = dlg.instance_variable_get(:@page_items)[1]
    dlg.show
    dlg.current_page.object_name.should == '0'
  end
  
  it 'should give focus to the first widget in the page' do
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    flexmock(dlg.instance_variable_get(:@widgets)['C1'][0]).should_receive(:set_focus).once
    dlg.show
  end
  
end

describe 'SettingsDialog#widgets' do
  
  it 'should return an array containing all the added widgets' do
    @mw = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).by_default.and_return @mw
    @back = flexmock('backend'){|m| m.should_ignore_missing}
    @cont = Object.new
    @cont.extend Ruber::SettingsContainer
    @cont.send :setup_container, @back
    @widgets = [
      OS.new({:caption => 'C1', :class_obj => Qt::CheckBox}),
      OS.new({:caption => 'C2', :class_obj => Qt::LineEdit}),
      OS.new({:caption => 'C2', :code => 'Qt::PushButton.new("test")'}),
      OS.new({:caption => 'C1', :class_obj => Qt::RadioButton, :code => 'Qt::ComboBox.new'})
    ]
    dlg = Ruber::SettingsDialog.new @cont, [], @widgets
    res = dlg.widgets
    internal = dlg.instance_variable_get(:@widgets)
    res.size.should == 4
    res.should include(internal['C1'][0])
    res.should include(internal['C1'][1])
    res.should include(internal['C2'][0])
    res.should include(internal['C2'][1])
  end
  
end