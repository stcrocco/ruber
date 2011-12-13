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
  
  describe '#active?' do
    
    it 'returns true if the object is active' do
      @obj.instance_variable_set(:@active, true)
      @obj.should be_active
    end
    
    it 'returns false if the the object is not active' do
      @obj.instance_variable_set(:@active, false)
      @obj.should_not be_active
    end
    
  end
  
  describe '#deactivate' do
    
    it 'calls #active= with false as argument' do
      flexmock(@obj).should_receive(:active=).with(false).once
      @obj.deactivate
    end
    
  end
  
  describe '#activate' do
    
    it 'calls #active= with true as argument' do
      flexmock(@obj).should_receive(:active=).with(true).once
      @obj.activate
    end
    
  end
  
  describe '#active=' do
    
    it 'sets the @active instance value to the argument converted to a boolean' do
      @obj.active = 'x'
      @obj.instance_variable_get(:@active).should == true
      @obj.active = nil
      @obj.instance_variable_get(:@active).should == false
    end
    
    context 'when the argument is a false value' do
    
      context 'if the object was active' do
        
        before do
          @obj.instance_variable_set :@active, true
        end
        
        it 'calls the object\'s do_deactivation method after changing the @active instance variable' do
          $do_deactivation_called = false
          $object_active = true
          def @obj.do_deactivation
            $object_active = self.active?
            $do_deactivation_called = true
          end
          @obj.active = false
          $object_active.should be_false
          $do_deactivation_called.should be_true
        end
        
      end
      
      context 'if the object was already inactive' do
        
        before do
          @obj.instance_variable_set :@active, false
        end
        
        it 'doesn\'t call the do_deactivation method' do
          flexmock(@obj).should_receive(:do_deactivation).never
          @obj.active = false
        end
        
      end
      
    end
    
    context 'when the argument is a true value' do
    
      context 'if the object was inactive' do
        
        before do
          @obj.instance_variable_set :@active, false
        end
        
        it 'calls the object\'s do_activation method after changing the @active instance variable' do
          $do_activation_called = false
          $object_active = true
          def @obj.do_activation
            $object_active = self.active?
            $do_activation_called = true
          end
          @obj.active = true
          $object_active.should be_true
          $do_activation_called.should be_true
        end
        
      end
      
      context 'if the object was already active' do
        
        before do
          @obj.instance_variable_set :@active, true
        end
        
        it 'doesn\'t call the do_activation method' do
          flexmock(@obj).should_receive(:do_activation).never
          @obj.active = true
        end
        
      end
      
    end
    
  end
  
  describe '#do_deactivation' do
    
    it 'emits the deactivated signal if the class including the module has that signal' do
      mk = flexmock{|m| m.should_receive(:deactivated).once}
      @obj.connect(SIGNAL(:deactivated)){mk.deactivated}
      @obj.send :do_deactivation
    end
    
    it 'doesn\'t emit the signal if the including class doesn\'t have the deactivated signal' do
      class << @obj
        undef_method :deactivated
      end
      lambda{@obj.send :do_deactivation}.should_not raise_error
    end
    
    it 'doesn\'t emit the signal if the including class doesn\'t inherit from Qt::Object' do
      obj = Object.new
      obj.extend Ruber::Activable
      lambda{obj.send :do_deactivation}.should_not raise_error
    end

  end
  
  describe '#do_activation' do
    
    it 'emits the activated signal if the class including the module has that signal' do
      mk = flexmock{|m| m.should_receive(:activated).once}
      @obj.connect(SIGNAL(:activated)){mk.activated}
      @obj.send :do_activation
    end
    
    it 'doesn\'t emit the signal if the including class doesn\'t have the activated signal' do
      class << @obj
        undef_method :activated
      end
      lambda{@obj.send :do_activation}.should_not raise_error
    end
    
    it 'doesn\'t emit the signal if the including class doesn\'t inherit from Qt::Object' do
      obj = Object.new
      obj.extend Ruber::Activable
      lambda{obj.send :do_activation}.should_not raise_error
    end
    
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