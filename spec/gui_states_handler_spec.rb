require 'spec/common'
require 'ruber/gui_states_handler'

describe Ruber::GuiStatesHandler do
  
  describe '.included' do
    
    class TestObject < Qt::Object
    end
    
    it 'creates the "ui_state_changed(QString, bool)" signal if included in a class derived from Qt::Object' do
      flexmock(TestObject).should_receive(:signals).with("ui_state_changed(QString, bool)").once
      TestObject.send :include, Ruber::GuiStatesHandler
    end
    
    it 'doesn\'t attempt to create the "ui_state_changed(QString, bool)" signal if included in a class not derived from Qt::Object' do
      cls = Class.new
      flexmock(cls).should_receive(:signals).never
      cls.send :include, Ruber::GuiStatesHandler
    end
    
    it 'doesn\'t attempt to create the "ui_state_changed(QString, bool)" signal if included in a modules' do
      cls = Module.new
      flexmock(cls).should_receive(:signals).never
      cls.send :include, Ruber::GuiStatesHandler
    end
    
  end
  
  describe '#initialize_states_handler' do
    
    it 'creates an empty hash of states and an empty hash of state handlers' do
      o = Object.new
      o.extend Ruber::GuiStatesHandler
      o.send :initialize_states_handler
      o.instance_variable_get(:@gui_state_handler_states).should == {}
      o.instance_variable_get(:@gui_state_handler_handlers).should == {}
    end
    
  end
  
  describe '#register_action_handler' do
    
    before do
      @handler = Object.new
      @handler.extend Ruber::GuiStatesHandler
      @handler.send :initialize_states_handler
    end
    
    it 'creates a new Data object for the action, passing it the action, the block and the extra_id entry of the optional hash as argument' do
      flexmock(Ruber::GuiStatesHandler::Data).should_receive(:new).once.with(KDE::Action, Proc, nil).and_return Object.new
      flexmock(Ruber::GuiStatesHandler::Data).should_receive(:new).once.with(KDE::Action, Proc, :a).and_return Object.new
      @handler.register_action_handler(KDE::Action.new(nil), ['x']){}
      @handler.register_action_handler(KDE::Action.new(nil), ['x'], :extra_id => :a){}
    end
    
    it 'adds the Data object to the entries corresponding to the states in the second argument in the state handlers hash' do
      a1 = KDE::Action.new(nil)
      a2 = KDE::Action.new(nil)
      blk1 = Proc.new{true}
      blk2 = Proc.new{false}
      @handler.register_action_handler a1, ['x'], &blk1
      h = @handler.instance_variable_get(:@gui_state_handler_handlers)
      data1 = Ruber::GuiStatesHandler::Data.new(a1, blk1, nil)
      h['x'].should == [data1]
      @handler.register_action_handler a2, ['x', 'y'], :extra_id => :a, &blk2
      data2 = Ruber::GuiStatesHandler::Data.new(a2, blk2, :a)
      h['x'].should == [data1, data2]
      h['y'].should == [data2]
    end
    
    it 'treats a single string passed as second argument as an array with only that string' do
      a = KDE::Action.new(nil)
      blk = Proc.new{true}
      @handler.register_action_handler a, 'x', &blk
      h = @handler.instance_variable_get(:@gui_state_handler_handlers)
      h['x'].should == [Ruber::GuiStatesHandler::Data.new(a, blk, nil)]
    end
    
    it 'convert any symbol in the second argument to a string' do
      h = @handler.instance_variable_get(:@gui_state_handler_handlers)
      @handler.register_action_handler(KDE::Action.new(nil), [:a, 'b']){}
      h['a'].should_not be_empty
      h[:a].should be_empty
    end
    
    it 'raises ArgumentError if no block is given and the second argument is an array with more than one element' do
      lambda{@handler.register_action_handler KDE::Action.new(nil), ['x', 'y']}.should raise_error(ArgumentError, "If more than one state is supplied, a block is needed")
    end

    
    it 'creates a default handler which returns true or false according to the value of the state if no block is given and the second argument is a string or symbol or an array with a single element' do
      h = @handler.instance_variable_get(:@gui_state_handler_handlers)
      @handler.register_action_handler(KDE::Action.new(nil), 'a')
      @handler.register_action_handler(KDE::Action.new(nil), :b)
      h['a'][0].handler.call('a' => true).should be_true
      h['a'][0].handler.call('a' => false).should be_false
      h['b'][0].handler.call('b' => true).should be_true
      h['b'][0].handler.call('b' => false).should be_false

    end
    
    it 'creates a default handler which returns true or false according to the opposite of the value of the state if no block is given and the second argument is a string or symbol starting with !' do
      h = @handler.instance_variable_get(:@gui_state_handler_handlers)
      @handler.register_action_handler(KDE::Action.new(nil), '!a')
      @handler.register_action_handler(KDE::Action.new(nil), :"!b")
      h['a'][0].handler.call('a' => true).should be_false
      h['a'][0].handler.call('a' => false).should be_true
      h['b'][0].handler.call('b' => true).should be_false
      h['b'][0].handler.call('b' => false).should be_true
    end
    
    it 'calls the handler passing it the gui states and enables or disables the action according to the returned value if the :check option is given' do
      a1 = KDE::Action.new(nil)
      a2 = KDE::Action.new(nil)
      @handler.change_state 'a', true
      @handler.change_state 'b', false
      flexmock(a1).should_receive(:enabled=).with(true).once 
      flexmock(a2).should_receive(:enabled=).with(false).once
      @handler.register_action_handler(a1, 'a', :check => true)
      @handler.register_action_handler(a2, "b", :check => true)
    end
    
    it 'doesn\'t call the handlerif the :check option is not given' do
      a1 = KDE::Action.new(nil)
      a2 = KDE::Action.new(nil)
      @handler.change_state 'a', true
      @handler.change_state 'b', false
      flexmock(a1).should_receive(:enabled=).never
      flexmock(a2).should_receive(:enabled=).never
      @handler.register_action_handler(a1, 'a', :check => false)
      @handler.register_action_handler(a2, "b", :check => false)
    end
    
  end
  
  describe '#remove_action_handler_for' do
    
    before do
      @handler = Object.new
      @handler.extend Ruber::GuiStatesHandler
      @handler.send :initialize_states_handler
    end
    
    describe ', when the first argument is a KDE::Action' do
      
      it 'removes all the handlers corresponding to the action from the handler list' do
        a = KDE::Action.new(nil){self.object_name = 'a'}
        @handler.register_action_handler(KDE::Action.new(nil), %w[x y]){}
        @handler.register_action_handler(a, %w[x z]){}
        @handler.register_action_handler(KDE::Action.new(nil), %w[z w]){}
        @handler.remove_action_handler_for a
        @handler.instance_variable_get(:@gui_state_handler_handlers).each_value.any? do |v|
          v.any?{|d| d.action.equal? a}
        end.should be_false
      end
      
    end
    
    describe ', when the first argument is a string' do
      
      it 'removes all the handlers corresponding to actions having the first argument as object name if the second argument is nil' do
        a1 = KDE::Action.new(nil){self.object_name = 'a'}
        a2= KDE::Action.new(nil){self.object_name = 'a'}
        @handler.register_action_handler(a1, %w[x z]){}
        @handler.register_action_handler(KDE::Action.new(nil), %w[x y]){}
        @handler.register_action_handler(a2, %w[z w], :extra_id => 'x'){}
        @handler.remove_action_handler_for 'a'
        @handler.instance_variable_get(:@gui_state_handler_handlers).each_value.any? do |v|
          v.any?{|d| d.action.object_name == 'a'}
        end.should be_false
      end
      
      it 'removes all the handlers corresponding to actions having the first argument as object name and the second as extra_id if the second argument is not nil' do
        a1 = KDE::Action.new(nil){self.object_name = 'a'}
        a2= KDE::Action.new(nil){self.object_name = 'a'}
        @handler.register_action_handler(a1, %w[x z]){}
        @handler.register_action_handler(KDE::Action.new(nil), %w[x y]){}
        @handler.register_action_handler(a2, %w[z w], :extra_id => 'x'){}
        @handler.remove_action_handler_for 'a', 'x'
        @handler.instance_variable_get(:@gui_state_handler_handlers).each_value.any? do |v|
          v.any?{|d| d.action.object_name == 'a' and d.extra_id == 'x'}
        end.should be_false
        @handler.instance_variable_get(:@gui_state_handler_handlers).each_value.any? do |v|
          v.any?{|d| d.action.object_name == 'a' and d.extra_id != 'x'}
        end.should be_true
      end
      
      it 'removes all entries corresponding to empty arrays from the handlers hash' do
        a1 = KDE::Action.new(nil){self.object_name = 'a'}
        a2= KDE::Action.new(nil){self.object_name = 'a'}
        @handler.register_action_handler(a1, %w[x z]){}
        @handler.register_action_handler(KDE::Action.new(nil), %w[x y]){}
        @handler.register_action_handler(a2, %w[z w], :extra_id => 'x'){}
        @handler.remove_action_handler_for 'a'
        hash = @handler.instance_variable_get(:@gui_state_handler_handlers)
        hash.should_not have_key('z')
        hash.any?{|k, v| v.empty? }.should_not be_true
      end
      
    end
    
    describe '#change_state' do
      
      class TestObject < Qt::Object
        include Ruber::GuiStatesHandler
        def initialize
          super
          initialize_states_handler
        end
      end
      
      before do
        @handler = TestObject.new
      end
      
      it 'sets the state corresponding to the first argument to true or false depending on the second argument' do
        @handler.change_state 'x', true
        @handler.instance_variable_get(:@gui_state_handler_states)['x'].should be_true
        @handler.change_state 'x', false
        @handler.instance_variable_get(:@gui_state_handler_states)['x'].should be_false
        @handler.change_state 'x', 3
        @handler.instance_variable_get(:@gui_state_handler_states)['x'].should be_true
        @handler.change_state 'x', nil
        @handler.instance_variable_get(:@gui_state_handler_states)['x'].should be_false
      end
      
      it 'converts the first argument to a string' do
        @handler.change_state :x, true
        @handler.instance_variable_get(:@gui_state_handler_states)['x'].should be_true
        @handler.instance_variable_get(:@gui_state_handler_states)[:x].should be_nil
      end
      
      it 'calls the handler of each action associated with the state passing it the states hash' do
        @handler.instance_variable_get(:@gui_state_handler_states)['y'] = false
        m1 = flexmock{|m| m.should_receive(:test).once.with({'x' => true, 'y' => false})}
        m2 = flexmock{|m| m.should_receive(:test).once.with({'x' => true, 'y' => false})}
        m3 = flexmock{|m| m.should_receive(:test).never}
        @handler.register_action_handler(KDE::Action.new(nil), %w[x y], :check => false){|states| m1.test states}
        @handler.register_action_handler(KDE::Action.new(nil), %w[x], :check => false){|states| m2.test states}
        @handler.register_action_handler(KDE::Action.new(nil), %w[y], :check => false){|states| m3.test states}
        @handler.change_state 'x', true
      end
      
      it 'enables or disables the actions associated with the state according to the value returned by the handler' do
        @handler.instance_variable_get(:@gui_state_handler_states)['y'] = false
        actions = 3.times.map{KDE::Action.new nil}
        m1 = flexmock{|m| m.should_receive(:test).once.with({'x' => true, 'y' => false}).and_return true}
        m2 = flexmock{|m| m.should_receive(:test).once.with({'x' => true, 'y' => false}).and_return false}
        m3 = flexmock{|m| m.should_receive(:test).never}
        flexmock(actions[0]).should_receive(:enabled=).with(true).once
        flexmock(actions[1]).should_receive(:enabled=).with(false).once
        flexmock(actions[2]).should_receive(:enabled=).never
        @handler.register_action_handler(actions[0], %w[x y], :check => false){|states| m1.test states}
        @handler.register_action_handler(actions[1], %w[x], :check => false){|states| m2.test states}
        @handler.register_action_handler(actions[2], %w[y], :check => false){|states| m3.test states}
        @handler.change_state 'x', true
      end
      
      it 'emits the "ui_state_changed(QString, bool)" signal passing the name of the state and the value if self is a Qt::Object' do
        m = flexmock{|mk| mk.should_receive(:state_changed).once.with('x', true)}
        @handler.connect(SIGNAL('ui_state_changed(QString, bool)')){|state, val| m.state_changed state, val}
        @handler.change_state 'x', 3
      end
      
      it 'should not attempt to emit the "ui_state_changed" signal if self is not a Qt::Object' do
        cls = Class.new do
          include Ruber::GuiStatesHandler
          def initialize
            initialize_states_handler
          end
        end
        @handler = cls.new
        flexmock(@handler).should_receive(:emit).never
        @handler.change_state 'x', 3
      end
      
    end
    
    describe '#state' do
      
      before do
        @handler = Object.new
        @handler.extend Ruber::GuiStatesHandler
        @handler.send :initialize_states_handler
      end
      
      it 'returns the value of the state, after converting the name to a string' do
        @handler.instance_variable_get(:@gui_state_handler_states)['a'] = true
        @handler.instance_variable_get(:@gui_state_handler_states)['b'] = false
        @handler.state('a').should be_true
        @handler.state(:b).should be_false
      end
      
      it 'returns nil if the state is not known' do
        @handler.state('a').should be_nil
        @handler.state(:b).should be_nil
      end
      
    end
    
  end
  
end