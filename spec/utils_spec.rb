require 'spec/common'

describe Kernel do
  
  describe '#silently' do
    
    it 'calls the block after setting the $VERBOSE variable to nil' do
      $VERBOSE = true
      res = true
      silently{res = $VERBOSE}
      res.should be_nil
    end
    
    it 'restores the original value of the $VERBOSE variable after calling the block' do
      $VERBOSE= true
      res = true
      silently{res = $VERBOSE}
      res.should be_nil
      $VERBOSE.should == true
    end
    
    it 'restores the original value of the $VERBOSE variable even if the block raises an exception' do
      $VERBOSE= true
      res = true
      lambda do 
        silently do 
          res = $VERBOSE
          raise Exception
        end
      end.should raise_error
      res.should be_nil
      $VERBOSE.should == true
      
    end
    
  end
  
end

describe 'Ruber::Signaler' do
  
  it 'should create a new, Ruber::Signaler::SignalerCls-derived class with the given signals when the "create" class method is called' do
    cls = Ruber::Signaler.create 's1()', 's2(QString)', 's3(QObject*)'
    cls.superclass.should == Qt::Object
    methods = cls.instance_methods.map{|s| s.to_s}
    methods.should include('s1')
    methods.should include('s2')
    methods.should include('s3')
  end
  
  it 'should provide a private signaler_object= method which sets the @__signaler instance variable' do
    cls = Class.new do
      include Ruber::Signaler
      Signaler = Ruber::Signaler.create 's1(QString)', 's2(QPoint, QRect)'
    end
    
    cls.new.private_methods.map{|m| m.to_s}.should include('signaler_object=')
    obj = cls.new
    sig = cls::Signaler.new
    obj.send :signaler_object=, sig
    obj.instance_variable_get(:@__signaler).should equal(sig)
  end

  it 'should provide a "connect!" instance method, which works as the standard Qt connect method, when called with a block' do
    cls = Class.new do
      include Ruber::Signaler
      Signaler = Ruber::Signaler.create 's1(QString)', 's2(QPoint, QRect)'
      
      def initialize
        @__signaler = Signaler.new
      end
      
    end
    str = "test"
    pt = Qt::Point.new(-4,2)
    rect = Qt::Rect.new(5,-7,10,8)
    m = flexmock('m') do |mk|
      mk.should_receive(:s1).with(str).once
      mk.should_receive(:s2).with(pt, rect).once
    end
    obj = cls.new
    obj.connect!(SIGNAL('s1(QString)')){|s| m.s1(s)}
    obj.connect!(SIGNAL('s2(QPoint, QRect)')) {|p, r| m.s2(p, r)}
    obj.instance_eval{emit!('s1', str)}
    obj.instance_eval{emit!('s2', pt, rect)}
  end
  
  it 'should provide a "connect!" instance method which works as the standard Qt connect method, when called with four arguments' do
    
    cls = Class.new do
      include Ruber::Signaler
      SignalerCls = Ruber::Signaler.create 'test_signal(int, QString)'
      def initialize
        @__signaler = SignalerCls.new
      end
    end

    eval <<-EOS
      class Obj < Qt::Object
        slots 'sl(int, QString)'
        signals 'si(int, QString)'
        
        def initialize mock
          super()
          @mock = mock
        end
        
        def sl n, s
          @mock.test(n, s)
        end
      end
    EOS
    
    obj = cls.new
    m = flexmock('mock'){|mk| mk.should_receive(:test).twice.with(2,"test")}
    
    test_obj = Obj.new m
    test_obj.connect(SIGNAL('si(int, QString)')){|n, s| m.test(n, s)}
    obj.connect! SIGNAL('test_signal(int, QString)'), test_obj, SLOT('sl(int, QString)')
    obj.connect! SIGNAL('test_signal(int, QString)'), test_obj, SIGNAL('si(int, QString)')
    obj.send :emit!, 'test_signal', 2, 'test'
  end
  
  it 'should provide a disconnect! method which works as Qt::Object#disconnect' do
    cls = Class.new do
      include Ruber::Signaler
      SignalerCls = Ruber::Signaler.create 'test_signal(int, QString)'
      def initialize
        self.signaler_object = SignalerCls.new
      end
    end
    
    obj = cls.new
    
    def (obj.instance_variable_get(:@__signaler)).disconnect *args
    end
    
    test = Qt::Object.new
    flexmock(obj.instance_variable_get(:@__signaler)).should_receive(:disconnect).once.with_no_args.once
    flexmock(obj.instance_variable_get(:@__signaler)).should_receive(:disconnect).once.with( SIGNAL('test_signal(int, QString)'))
    flexmock(obj.instance_variable_get(:@__signaler)).should_receive(:disconnect).once.with( SIGNAL('test_signal(int, QString)'), test)
    flexmock(obj.instance_variable_get(:@__signaler)).should_receive(:disconnect).once.with( SIGNAL('test_signal(int, QString)'), test, SLOT('test_slot()'))
    obj.disconnect!
    obj.disconnect!(SIGNAL('test_signal(int, QString)'))
    obj.disconnect!(SIGNAL('test_signal(int, QString)'), test)
    obj.disconnect!(SIGNAL('test_signal(int, QString)'), test, SLOT('test_slot()'))
  end
  
  it 'should provide a private "emit!" method which calls the emit_signal method of the signaler object' do
    cls = Class.new do
      include Ruber::Signaler
      SignalerCls = Ruber::Signaler.create 'test_signal(int, QString)'
      def initialize
        self.signaler_object = SignalerCls.new
      end
    end
    obj = cls.new
    obj.private_methods.map{|m| m.to_s}.should include("emit!")
    m = flexmock("test"){|mk| mk.should_receive(:test).with(3, 'test').once}
    obj.connect!(SIGNAL('test_signal(int, QString)')){|i, s| m.test i, s}
    obj.send(:emit!, :test_signal, 3, "test")
  end
  
end

describe 'Dictionary#reverse_each' do
  
  it 'should call the block with each key/value pair in reverse order' do
    pairs = [['x', 3], ['a', 2], ['b', 5]]
    d = Dictionary.alpha
    pairs.each{|p| d << p}
    m = flexmock do |mk|
      pairs.sort_by{|k, v| k}.reverse.each{|i| mk.should_receive(:test).with(i).globally.ordered.once}
    end
    d.reverse_each do |k, v| 
                   m.test [k, v]
    end
  end
  
end

describe 'Array#to_h' do
  
  it 'should use each entry of the array as key/value pair if no argument is given' do
    a = [[:a, 1], [:b, 2], [:c, 3]]
    a.to_h.should == {:a => 1, :b => 2, :c => 3}
  end
  
  it 'should use each entry of the array as key/value pair if the argument is true' do
    a = [[:a, 1], [:b, 2], [:c, 3]]
    a.to_h(true).should == {:a => 1, :b => 2, :c => 3}
  end
  
  it 'should consider the array as a list of keys and values if the argument is false' do
    a = [:a, 1, :b, 2, :c, 3]
    a.to_h(false).should == {:a => 1, :b => 2, :c => 3}
  end
  
end

describe Ruber::Activable do
  
  class SimpleActivable < Qt::Object
    signals :activated, :deactivated
    include Ruber::Activable
    def initialize
      super
      @active = false
    end
  end
  
  before do
    @cls = self.class.const_get(:SimpleActivable)
    @obj = @cls.new
  end
  
  it 'should return true or false, depending on whether it\'s active or not when the active? method is called' do
    @obj.should_not be_active
    @obj.instance_variable_set(:@active, true)
    @obj.should be_active
  end
  
  it 'should set the @active instance variable to false when the deactivate method is called' do
    @obj.deactivate
    @obj.should_not be_active
    @obj.instance_variable_set(:@active, true)
    @obj.deactivate
    @obj.should_not be_active
  end
  
  it 'should emit the "deactivated" signal when the deactivated method is called, unless it was already inactive' do
    m1 = flexmock{|m| m.should_receive(:deactivated).once}
    m2 = flexmock{|m| m.should_receive(:deactivated).never}
    @obj.connect(SIGNAL(:deactivated)){m2.deactivated}
    @obj.deactivate
    @obj.disconnect
    @obj.connect(SIGNAL(:deactivated)){m1.deactivated}
    @obj.instance_variable_set(:@active, true)
    @obj.deactivate
  end
  
  it 'should set the @active instance variable to true when the activate method is called' do
    @obj.activate
    @obj.should be_active
    @obj.instance_variable_set(:@active, false)
    @obj.activate
    @obj.should be_active
  end
  
  it 'should emit the "activated" signal when the activated method is called, unless it was already active' do
    m1 = flexmock{|m| m.should_receive(:activated).never}
    m2 = flexmock{|m| m.should_receive(:activated).once}
    @obj.connect(SIGNAL(:activated)){m2.activated}
    @obj.activate
    @obj.disconnect
    @obj.connect(SIGNAL(:activated)){m1.activated}
    @obj.instance_variable_set(:@active, true)
    @obj.activate
  end
  
  it 'should set the @active instance variable to the value passed as argument when the active= method is called' do
    @obj.active= false
    @obj.should_not be_active
    @obj.active= true
    @obj.should be_active
    @obj.active= false
    @obj.should_not be_active
  end
  
  it 'should convert the argument to a boolean value when the active= method is called' do
    @obj.active= nil
    @obj.active?.should be_false
    @obj.active= "abc"
    @obj.active?.should be_true
  end
  
  it 'should emit the "deactivated" signal when the active= method is called with false as argument and the object was active' do
    m1 = flexmock{|m| m.should_receive(:deactivated).once}
    m2 = flexmock{|m| m.should_receive(:deactivated).never}
    @obj.connect(SIGNAL(:deactivated)){m2.deactivated}
    @obj.active = false
    @obj.disconnect
    @obj.connect(SIGNAL(:deactivated)){m1.deactivated}
    @obj.instance_variable_set(:@active, true)
    @obj.active = false
  end
  
  it 'should emit the "activated" signal when the active= method is called with true as argument and the object was inactive' do
    m1 = flexmock{|m| m.should_receive(:activated).never}
    m2 = flexmock{|m| m.should_receive(:activated).once}
    @obj.connect(SIGNAL(:activated)){m2.activated}
    @obj.active = true
    @obj.disconnect
    @obj.connect(SIGNAL(:activated)){m1.activated}
    @obj.instance_variable_set(:@active, true)
    @obj.active = true
  end

  
  it 'should not attempt to emit signals if the object is not a Qt::Object' do
    obj = Object.new
    obj.extend Ruber::Activable
    obj.instance_variable_set(:@active, false)
    lambda{obj.activate}.should_not raise_error
    obj.should be_active
    lambda{obj.deactivate}.should_not raise_error
    obj.should_not be_active
    lambda{obj.active = true}.should_not raise_error
    obj.should be_active
    lambda{obj.active = false}.should_not raise_error
    obj.should_not be_active
  end
  
  it 'should not attempt to emit signals if the object is a Qt::Object but doesn\'t provide the needed signals' do
    obj = Qt::Object.new
    obj.extend Ruber::Activable
    obj.instance_variable_set(:@active, false)
    lambda{obj.activate}.should_not raise_error
    obj.should be_active
    lambda{obj.deactivate}.should_not raise_error
    obj.should_not be_active
    lambda{obj.active = true}.should_not raise_error
    obj.should be_active
    lambda{obj.active = false}.should_not raise_error
    obj.should_not be_active
  end

  
end

describe 'String#split_lines' do
  
  it 'should return an array with each entry corresponding to a line' do
    "a b c\nd e f\n\ng h i\n".split_lines.should == ['a b c', 'd e f','', 'g h i']
  end
  
end

describe Kernel do

  describe '#string_like?' do
    
    it 'should return false' do
      Object.new.should_not be_string_like
    end
    
  end
  
  describe '#obj_binding' do
    
    it 'should return the binding of the object' do
      obj = Object.new
      obj.instance_variable_set(:@x, 7)
      eval( "@x", obj.obj_binding).should == 7
    end
    
  end
  
end

describe String do
  
  describe '#string_like?' do
    
    it 'should return true' do
      String.new.should be_string_like
      "abc".should be_string_like
    end
    
  end
  
end

describe Symbol do
  
  describe '#string_like?' do
    
    it 'should return true' do
      :abc.should be_string_like
    end
    
  end
  
end

describe Shellwords, '.split_with_quotes' do
  
  it 'works as Shellwords.split if there are no quotes in the argument' do
    arg = "-a xyx --bc ab x=cd"
    Shellwords.split_with_quotes(arg).should == Shellwords.split(arg)
  end
  
  it 'encloses in double quotes the tokens which where enclosed in quotes in the argument, unless the token contains double quotes' do
    arg = "-a xyz --bc 'ab x=cd' xh 'a1 bc'"
    exp = ['-a', 'xyz', '--bc', '"ab x=cd"', 'xh', '"a1 bc"']
    Shellwords.split_with_quotes(arg).should == exp
  end
  
  it 'encloses in single quotes the tokens which where enclosed in quotes in the argument, if the token contains double quotes' do
    arg = "-a xyz --bc 'ab \"x\"=cd' xh 'a1 bc'"
    exp = ['-a', 'xyz', '--bc', "'ab \"x\"=cd'", 'xh', '"a1 bc"']
    Shellwords.split_with_quotes(arg).should == exp
  end

  
end