require 'spec/common'

require 'yaml'

require 'ruber/qt_sugar'

describe 'An instance of a Qt class' do
  
  it 'should return false when the nil_object? method is called and the object is not Qt::NilObject, if its class inherits Qt::Object (in the C++ sense)' do
    o = Qt::Object.new
    o.should_not be_nil_object
  end
  
  it 'should raise NoMethodError when the nil_object? method is called and its class doesn\'t inherit Qt::Object (in the C++ sense)' do
  lambda{Qt::Rect.new.nil_object?}.should raise_error(NoMethodError)
  
end
  
  it 'should return true when the nil_object? method is called and the object is Qt::NilObject' do
    Qt::NilObject.should be_nil_object
  end
  
end

describe 'Qt::Point' do
  
  it 'should be serializable using YAML' do
    pt = Qt::Point.new(1,3)
    res = YAML.load(YAML.dump(pt))
    res.should == pt
    res.should_not equal(pt)
  end
  
  it 'should be marshallable' do
    pt = Qt::Point.new(1,3)
    res = Marshal.load(Marshal.dump(pt))
    res.should == pt
    res.should_not equal(pt)
  end
  
end

describe 'Qt::PointF' do
  
  it 'should be serializable using YAML' do
    pt = Qt::PointF.new(1.9,-3.4)
    res = YAML.load(YAML.dump(pt))
    res.should == pt
    res.should_not equal(pt)
  end
  
  it 'should be marshallable' do
    pt = Qt::PointF.new(1.9,-3.4)
    res = Marshal.load(Marshal.dump(pt))
    res.should == pt
    res.should_not equal(pt)
  end
  
end

describe 'Qt::Size' do
  
  it 'should be serializable using YAML' do
    sz = Qt::Size.new(4,3)
    res = YAML.load(YAML.dump(sz))
    res.should == sz
    res.should_not equal(sz)
  end
  
  it 'should be marshallable' do
    sz = Qt::Size.new(4,3)
    res = Marshal.load(Marshal.dump(sz))
    res.should == sz
    res.should_not equal(sz)
  end
  
end

describe 'Qt::SizeF' do
  
  it 'should be serializable using YAML' do
    sz = Qt::SizeF.new(-4.1,3.7)
    res = YAML.load(YAML.dump(sz))
    res.should == sz
    res.should_not equal(sz)
  end
  
  it 'should be marshallable' do
    sz = Qt::SizeF.new(-4.1,3.7)
    res = Marshal.load(Marshal.dump(sz))
    res.should == sz
    res.should_not equal(sz)
  end
  
end

describe 'Qt::Rect' do
  
  it 'should be serializable using YAML' do
    rec = Qt::Rect.new(1,3,5,6)
    res = YAML.load(YAML.dump(rec))
    res.should == rec
    res.should_not equal(rec)
  end
  
  it 'should be marshallable' do
    rec = Qt::Rect.new(1,3,5,6)
    res = Marshal.load(Marshal.dump(rec))
    res.should == rec
    res.should_not equal(rec)
  end

  
end

describe 'Qt::RectF' do
  
  it 'should be serializable using YAML' do
    rec = Qt::RectF.new(1.2,-4.1,3.7,5.8)
    res = YAML.load(YAML.dump(rec))
    res.should == rec
    res.should_not equal(rec)
  end
  
  it 'should be marshallable' do
    rec = Qt::RectF.new(1.2,-4.1,3.7,5.8)
    res = Marshal.load(Marshal.dump(rec))
    res.should == rec
    res.should_not equal(rec)
  end
  
end

describe 'Qt::Color' do
  
  it 'should be serializable using YAML' do
    c= Qt::Color.new(178, 201, 89)
    res = YAML.load(YAML.dump(c))
    res.should == c
    res.should_not equal(c)
  end
  
  it 'should be marshallable' do
    c= Qt::Color.new(178, 201, 89)
    res = Marshal.load(Marshal.dump(c))
    res.should == c
    res.should_not equal(c)
  end
  
end

describe 'Qt::Date' do
  
  it 'should be serializable using YAML' do
    d = Qt::Date.new(2008, 10, 23)
    res = YAML.load(YAML.dump(d))
    res.should == d
    res.should_not equal(d)
  end

  it 'should be marshallable' do
    d = Qt::Date.new(2008, 10, 23)
    res = Marshal.load(Marshal.dump(d))
    res.should == d
    res.should_not equal(d)
  end  
  
end

describe 'Qt::Font' do
  
  it 'should be serializable using YAML' do
    f = Qt::Font.new('Utopia', 13, 10, true)
    res = YAML.load(YAML.dump(f))
    res.should == f
    res.should_not equal(f)
  end
  
  it 'should be marshallable' do
    f = Qt::Font.new('Utopia', 13, 10, true)
    res = Marshal.load(Marshal.dump(f))
    res.should == f
    res.should_not equal(f)
  end
  
end

describe 'Qt::DateTime' do
  
  it 'should be serializable using YAML' do
    d = Qt::DateTime.new(Qt::Date.new(2008, 10, 24), Qt::Time.new(13,49,58,688), Qt::UTC)
    res = YAML.load(YAML.dump(d))
    res.should == d
    res.should_not equal(d)
  end
  
  it 'should be marshallable' do
    d = Qt::DateTime.new(Qt::Date.new(2008, 10, 24), Qt::Time.new(13,49,58,688), Qt::UTC)
    res = Marshal.load(Marshal.dump(d))
    res.should == d
    res.should_not equal(d)
  end
  
end

describe 'Qt::Time' do
  
  it 'should be serializable using YAML' do
    t = Qt::Time.new(14, 36, 52, 140)
    res = YAML.load(YAML.dump(t))
    res.should == t
    res.should_not equal(t)
    res.should be_valid
    
    t = Qt::Time.new(0,0,0)
    res = YAML.load(YAML.dump(t))
    res.should == t
    res.should_not equal(t)
    res.should be_valid
    
    t = Qt::Time.new
    res = YAML.load(YAML.dump(t))
    res.should == t
    res.should_not equal(t)
    res.should_not be_valid
  end
  
  it 'should be marshallable' do
    t = Qt::Time.new(14, 36, 52, 140)
    res = Marshal.load(Marshal.dump(t))
    res.should == t
    res.should_not equal(t)
    res.should be_valid
    
    t = Qt::Time.new(0,0,0)
    res = Marshal.load(Marshal.dump(t))
    res.should == t
    res.should_not equal(t)
    res.should be_valid
    
    t = Qt::Time.new
    res = Marshal.load(Marshal.dump(t))
    res.should == t
    res.should_not equal(t)
    res.should_not be_valid
  end
  
end

describe 'Qt::Url' do
  
  it 'should be serializable using YAML' do
    u = Qt::Url.new 'http://www.kde.org'
    res = YAML.load(YAML.dump(u))
    res.should == u
    res.should_not equal(u)
  end
  
  it 'should be marshallable' do
    u = Qt::Url.new 'http://www.kde.org'
    res = Marshal.load(Marshal.dump(u))
    res.should == u
    res.should_not equal(u)
  end
  
end

module QtNamedConnectSpec
  
  class Sender < Qt::Object
    signals 's1()', 's2(QString)'
    def emit_signal sig, *args
      emit method(sig).call(*args)
    end
  end
  
end

describe 'Qt::Base#named_connect' do
  
  before do 
    @sender = QtNamedConnectSpec::Sender.new
  end
    
  it 'should make a connection' do
    m = flexmock{|mk| mk.should_receive(:test).once}
    @sender.named_connect(SIGNAL('s1()'), 'test'){m.test}
    @sender.emit_signal 's1'
  end
  
  it 'should allow to disconnect the block' do
    m = flexmock{|mk| mk.should_receive(:test).never}
    @sender.named_connect(SIGNAL('s1()'), 'test'){m.test}
    rec = @sender.find_children(Qt::SignalBlockInvocation, 'test')[0]
    @sender.disconnect SIGNAL('s1()'), rec
    @sender.emit_signal 's1'
  end
  
end

describe 'Qt::Base#named_connect' do
  
  before do 
    @sender = QtNamedConnectSpec::Sender.new
  end
    
  it 'should allow to disconnect the block' do
    m = flexmock{|mk| mk.should_receive(:test).never}
    @sender.named_connect(SIGNAL('s1()'), 'test'){m.test}
    @sender.named_disconnect 'test'
    @sender.emit_signal 's1'
  end

end

describe Qt::Variant, '#to_bool' do
  
  it 'calls method_missing with :to_bool' do
    v = Qt::Variant.new false
    def v.method_missing *args
      @method_called = args[0]
      super *args
    end
    v.to_bool.should be_false
    v.instance_variable_get(:@method_called).should == :to_bool
  end
  
end

describe Qt::Layout do
  
  it 'includes QtEnumerable' do
    Qt::Layout.ancestors.should include(QtEnumerable)
  end
  
  describe '#each' do
    
    it 'passes to the block each widget in turn if called with a block' do
      #Since Qt::Layout is an abstract class, we fake calls to count and item_at,
      #which are pure virtual, with mocks
      w = Qt::Widget.new
      layout = Qt::Layout.new w
      w.layout = layout
      widgets = [Qt::PushButton, Qt::VBoxLayout, Qt::CheckBox].map{|c| c.new}
      res = []
      flexmock(layout).should_receive(:count).once.and_return(3)
      flexmock(layout).should_receive(:item_at).with(0).once.and_return(Qt::WidgetItem.new(widgets[0]))
      flexmock(layout).should_receive(:item_at).with(1).once.and_return(widgets[1])
      flexmock(layout).should_receive(:item_at).with(2).once.and_return(Qt::WidgetItem.new(widgets[2]))
      layout.each{|w| res << w}
      res.should == widgets
    end
    
    it 'returns an enumerator if no block is given' do
      w = Qt::Widget.new
      layout = Qt::Layout.new w
      w.layout = layout
      widgets = [Qt::PushButton, Qt::VBoxLayout, Qt::CheckBox].map{|c| c.new}
      res = []
      flexmock(layout).should_receive(:count).once.and_return(3)
      flexmock(layout).should_receive(:item_at).with(0).once.and_return(Qt::WidgetItem.new(widgets[0]))
      flexmock(layout).should_receive(:item_at).with(1).once.and_return(widgets[1])
      flexmock(layout).should_receive(:item_at).with(2).once.and_return(Qt::WidgetItem.new(widgets[2]))
      e = layout.each
      e.each{|w| res << w}
      res.should == widgets
    end
    
  end
  
end

shared_examples_for 'any box layout' do
  
  it 'includes QtEnumerable' do
    @layout.class.ancestors.should include(QtEnumerable)
  end
  
  it 'has an each method which passes to the block each widget in turn if called with a block' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [Qt::PushButton, Qt::VBoxLayout, Qt::CheckBox].map{|c| c.new}
    widgets.each{|w| @layout.send w.is_a?(Qt::Widget) ? :add_widget : :add_layout, w}
    res = []
    @layout.each{|w| res << w}
    res.should == widgets
  end
  
  it 'has an each method which returns an enumerator if no block is given' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [Qt::PushButton, Qt::VBoxLayout, Qt::CheckBox].map{|c| c.new}
    res = []
    widgets.each{|w| @layout.send w.is_a?(Qt::Widget) ? :add_widget : :add_layout, w}
    e = @layout.each
    e.each{|w| res << w}
    res.should == widgets
  end
    
end

describe Qt::BoxLayout do
  
  before do
    @layout = Qt::BoxLayout.new(Qt::Horizontal)
  end
  
  it_behaves_like 'any box layout'
  
end

describe Qt::VBoxLayout do
  
  before do
    @layout = Qt::VBoxLayout.new
  end
  
  it_behaves_like 'any box layout'
  
end

describe Qt::HBoxLayout do
  
  before do
    @layout = Qt::HBoxLayout.new
  end
  
  it_behaves_like 'any box layout'
  
end

describe Qt::StackedLayout do

  before do
    @layout = Qt::StackedLayout.new
  end
  
  it 'includes QtEnumerable' do
    @layout.class.ancestors.should include(QtEnumerable)
  end
  
  it 'has an each method which passes to the block each widget in turn if called with a block' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [Qt::PushButton, Qt::LineEdit, Qt::CheckBox].map{|c| c.new}
    widgets.each{|w| @layout.add_widget w}
    res = []
    @layout.each{|w| res << w}
    res.should == widgets
  end
  
  it 'has an each method which returns an enumerator if no block is given' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [Qt::PushButton, Qt::LineEdit, Qt::CheckBox].map{|c| c.new}
    res = []
    widgets.each{|w| @layout.add_widget w}
    e = @layout.each
    e.each{|w| res << w}
    res.should == widgets
  end
  
end

describe Qt::FormLayout do
  
  before do
    @layout = Qt::FormLayout.new
  end
  
  it 'includes QtEnumerable' do
    @layout.class.ancestors.should include(QtEnumerable)
  end
  
  it 'has an each method which passes to the block each widget in turn if called with a block' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [['l1', Qt::PushButton], ['l2', Qt::LineEdit], ['l3', Qt::CheckBox]].map{|c| [Qt::Label.new(c[0]), c[1].new]}
    widgets.each{|w| @layout.add_row w[0], w[1]}
    res = []
    @layout.each{|w| res << w}
    res.should == widgets.flatten
  end
  
  it 'has an each method which returns an enumerator if no block is given' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [['l1', Qt::PushButton], ['l2', Qt::LineEdit], ['l3', Qt::CheckBox]].map{|c| [Qt::Label.new(c[0]), c[1].new]}
    widgets.each{|w| @layout.add_row w[0], w[1]}
    res = []
    e = @layout.each
    e.each{|w| res << w}
    res.should == widgets.flatten
  end
  
end

describe Qt::GridLayout do
  
  before do
    @layout = Qt::GridLayout.new
  end
  
  it 'includes QtEnumerable' do
    @layout.class.ancestors.should include(QtEnumerable)
  end
  
  it 'has an each method which passes to the block each widget in turn if called with a block' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [[Qt::TextEdit, Qt::HBoxLayout], [Qt::Label, Qt::LineEdit], [Qt::VBoxLayout, Qt::CheckBox]].map{|c1, c2| [c1.new, c2.new]}
    add = lambda{|w, r, c|w.is_a?(Qt::Widget) ? @layout.add_widget(w, r, c) : @layout.add_layout(w, r, c) }
    widgets.each_with_index do |w, r| 
      add.call w[0], r, 0
      add.call w[1], r, 1
    end
    res = []
    @layout.each{|w| res << w}
    res.should == widgets.flatten
  end
  
  it 'has an each method which returns an enumerator if no block is given' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [[Qt::TextEdit, Qt::HBoxLayout], [Qt::Label, Qt::LineEdit], [Qt::VBoxLayout, Qt::CheckBox]].map{|c1, c2| [c1.new, c2.new]}
    add = lambda{|w, r, c|w.is_a?(Qt::Widget) ? @layout.add_widget(w, r, c) : @layout.add_layout(w, r, c) }
    widgets.each_with_index do |w, r| 
      add.call w[0], r, 0
      add.call w[1], r, 1
    end
    res = []
    e = @layout.each
    e.each{|w| res << w}
    res.should == widgets.flatten
  end
  
  it 'passes widgets spanning more than one row or column only once' do
    w = Qt::Widget.new
    w.layout = @layout
    widgets = [[Qt::TextEdit, Qt::HBoxLayout], [Qt::LineEdit], [Qt::VBoxLayout, Qt::CheckBox]].map do |c1, c2| 
      c2 ? [c1.new, c2.new] : [c1.new]
    end
    add = lambda{|w, r, c, r1, c1|w.is_a?(Qt::Widget) ? @layout.add_widget(w, r, c, r1, c1) : @layout.add_layout(w, r, c, r1, c1) }
    widgets.each_with_index do |w, r| 
      if w.size == 1
        add.call w[0], r, 0, r, 1
      else
        add.call w[0], r, 0, r, 0
        add.call w[1], r, 1, r, 1
      end
    end
    res = []
    @layout.each{|w| res << w}
    res.should == widgets.flatten
  end
  
end