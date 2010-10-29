require 'spec/common'

require 'ktexteditor'
require 'ruber/editor/ktexteditor_wrapper'

describe Ruber::KTextEditorWrapper do
  
  class SimpleWrapped < Qt::Object
    
    include Ruber::KTextEditorWrapper
    
    attr_reader :doc
    def initialize
      super
      @doc = KTextEditor::EditorChooser.editor('katepart').create_document( self)
    end
    
  end
  
  describe '.prepare_wrapper_connections' do
    
    it 'takes two arguments' do
      lambda{Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, {}}.should_not raise_error
    end
    
    it 'creates signals for the class given as first argument having the keys of the hash as names and the arguments obtained by rearranging the arguments of the wrapped signal as indicated in the second entry of the value' do
      data = {
        'first_signal' => ['QObject*, QString', [1, 0]],
        'second_signal' => ['int, int, QObject*', [2,0,1]]
        }
      flexmock(SimpleWrapped).should_receive(:signals).once.with('first_signal(QString, QObject*)')
      flexmock(SimpleWrapped).should_receive(:signals).once.with('second_signal(QObject*, int, int)')
      Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, data
    end
    
    it 'replaces nil with "QObject*" in the new argument list if the class isn\'t a Qt::Widget' do
      data = {
        'first_signal' => ['QObject*, QString', [1, 0, nil]],
      }
      flexmock(SimpleWrapped).should_receive(:signals).once.with('first_signal(QString, QObject*, QObject*)')
      Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, data
    end
    
    it 'replaces nil with "QWidget*" in the new argument list if the class is a Qt::Widget' do
      data = {
        'first_signal' => ['QObject*, QString', [1, 0, nil]],
      }
      flexmock(SimpleWrapped).should_receive(:ancestors).and_return [Qt::Widget, SimpleWrapped]
      flexmock(SimpleWrapped).should_receive(:signals).once.with('first_signal(QString, QObject*, QWidget*)')
      Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, data
    end
    
    it 'creates a slot in the class passed as first argument for each entry in the hash which has the same argument list as the original signal and the name given by "__emit_sig_signal", wehere sig is the signal name' do
      data = {
        'first_signal' => ['QObject*, QString', [1, 0]],
        'second_signal' => ['int, int, QObject*', [2,0,1]]
      }
      flexmock(SimpleWrapped).should_receive(:slots).once.with('__emit_first_signal_signal(QObject*, QString)')
      flexmock(SimpleWrapped).should_receive(:slots).once.with('__emit_second_signal_signal(int, int, QObject*)')
      Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, data
    end
    
    it 'creates a method in the class with the same name passed to the slot which calls the corresponding signal using as argument those in the argument list, correctly sorted, and self where the second array in the entry has nil' do
      data = {
        'first_signal' => ['QObject*, QString', [1, 0]],
        'second_signal' => ['int, int, QObject*', [2,0,1]],
        'third_signal' => ['QString, KTextEditor::Document*', [nil, 0]]
      }
      methods = []
      methods << <<-EOS
def __emit_first_signal_signal(a0, a1)
  emit first_signal(a1, a0)
end
      EOS
      
      methods << <<-EOS
def __emit_second_signal_signal(a0, a1, a2)
  emit second_signal(a2, a0, a1)
end
      EOS
      
      methods << <<-EOS
def __emit_third_signal_signal(a0, a1)
  emit third_signal(self, a0)
end
      EOS
      
      methods.each{|m| flexmock(SimpleWrapped).should_receive(:class_eval).once.with(m)}
      Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, data
    end
    
    it 'returns a hash whose keys are the hash keys converted to camelcase and with the arguments added and whose entries are the names of the created slots' do
      data = {
        'first_signal' => ['QObject*, QString', [1, 0]],
        'second_signal' => ['int, int, QObject*', [2,0,1]],
        'third_signal' => ['QString', [nil, 0]]
      }
      res = Ruber::KTextEditorWrapper.prepare_wrapper_connections SimpleWrapped, data
      exp = {
        'firstSignal(QObject*, QString)' => '__emit_first_signal_signal(QObject*, QString)',
        'secondSignal(int, int, QObject*)' => '__emit_second_signal_signal(int, int, QObject*)',
        'thirdSignal(QString)' => '__emit_third_signal_signal(QString)',
        }
      res.should == exp
    end
    
  end
  
  describe '#initialize_wrapper' do
    
    before do
      @w = SimpleWrapped.new
    end
    
    it 'takes two arguments' do
      lambda{@w.send :initialize_wrapper, Qt::Object.new, {}}.should_not raise_error
    end
    
    it 'calls the connect_wrapped_signals method passing it the second argument' do
      flexmock(@w).should_receive(:connect_wrapped_signals).once.with({'a' => 'b'})
      @w.send :initialize_wrapper, Qt::Object.new, {'a' => 'b'}
    end
    
    it 'creates an interface proxy passing it the argument' do
      obj = Qt::Object.new
      prx = Ruber::KTextEditorWrapper::InterfaceProxy.new obj
      flexmock(Ruber::KTextEditorWrapper::InterfaceProxy).should_receive(:new).once.with(obj).and_return prx
      @w.send :initialize_wrapper, obj, {}
      @w.instance_variable_get(:@_interface).should be_a(Ruber::KTextEditorWrapper::InterfaceProxy)
      @w.instance_variable_get(:@_wrapped).should equal(obj)
    end
    
  end
  
  describe '#internal' do
    
    before do
      @w = SimpleWrapped.new
      @w.send :initialize_wrapper, @w.doc, {}
    end
    
    it 'returns the argument passed to initialize_wrapper' do
      @w.send(:internal).should equal(@w.doc)
    end
    
  end
  
  
  describe '#interface' do
    
    before do
      @w = SimpleWrapped.new
      @w.send :initialize_wrapper, @w.doc, {}
    end
    
    it 'sets the proxy\'s interface to the argument' do
      @w.interface('modification_interface')
      @w.instance_variable_get(:@_interface).instance_variable_get(:@interface).should be_a(KTextEditor::ModificationInterface)
    end
    
    it 'returns the proxy' do
      @w.interface('modification_interface').should be_a(Ruber::KTextEditorWrapper::InterfaceProxy)
    end
    
  end
  
  describe '#connect_wrapped_signals' do
    
    before do
      @w = SimpleWrapped.new
      def @w.connect *args
      end
      @w.send :initialize_wrapper, @w.doc, {}
    end
    
    it 'takes one argument' do
      lambda{@w.send :connect_wrapped_signals, {}}.should_not raise_error
    end
    
    it 'calls the connect method of the wrapped object for each entry in the argument, using the wrapped object as sender and self as receiver' do
      flexmock(@w).should_receive(:connect).once.with(@w.doc, SIGNAL('a'), @w, SLOT('b'))
      flexmock(@w).should_receive(:connect).once.with(@w.doc, SIGNAL('c'), @w, SLOT('d'))
      @w.send :connect_wrapped_signals, {'a' => 'b', 'c' => 'd'}
    end
    
  end
  
  describe '#method_missing' do
    
    before do
      @w = SimpleWrapped.new
      @w.send :initialize_wrapper, @w.doc, {}
    end
    
    it 'attempts to call the superclass method' do
      @w.objectName = 'xyz'
      @w.object_name.should == 'xyz'
    end
    
    it 'calls the method with the same name, arguments and block in the wrapped object if the superclass method raises NoMethodError' do
      flexmock(@w.doc).should_receive(:test).with('xyz', Proc).once
      @w.test('xyz'){puts 'xyz'}
    end
    
    it 'calls the method with the same name, arguments and block in the wrapped object if the superclass method raises NameError' do
      lambda{@w.instance_eval("text")}.should_not raise_error
    end
    
    it 'calls the method with the same name, arguments and block in the wrapped object if the superclass method raises NotImplementedError' do
      pending 'I don\'t remember when calling super causes a NotImplementedError exception, so I can\'t test this situation right now'
    end
    
  end
  
    
end

describe Ruber::KTextEditorWrapper::InterfaceProxy do
  
  before do
    @doc = KTextEditor::EditorChooser.editor('katepart').create_document(nil)
  end
  
  describe ', when created' do
    
    it 'takes the wrapped object as argument and stores it' do
      proxy = nil
      lambda{proxy = Ruber::KTextEditorWrapper::InterfaceProxy.new @doc}.should_not raise_error
      proxy.instance_variable_get(:@obj).should equal(@doc)
    end
    
    it 'has a nil interface' do
      proxy = Ruber::KTextEditorWrapper::InterfaceProxy.new @doc
      proxy.instance_variable_get(:@interface).should be_nil
    end
    
  end
  
  describe '#interface=, when called with a string or symbol' do
    
    before do
      @proxy = Ruber::KTextEditorWrapper::InterfaceProxy.new @doc
    end
    
    it 'stores the object cast to the interface obtained from the string passed as argument' do
      @proxy.interface = 'mark_interface'
      @proxy.instance_variable_get(:@interface).should be_a(KTextEditor::MarkInterface)
      @proxy.interface = :modification_interface
      @proxy.instance_variable_get(:@interface).should be_a(KTextEditor::ModificationInterface)
    end
    
  end
  
    describe '#interface=, when called with a class' do
    
    before do
      @proxy = Ruber::KTextEditorWrapper::InterfaceProxy.new @doc
    end
    
    it 'stores the object cast to the class given as argument' do
      @proxy.interface = KTextEditor::MarkInterface
      @proxy.instance_variable_get(:@interface).should be_a(KTextEditor::MarkInterface)
    end
    
  end
  
  describe '#method_missing' do
    
    class SimpleWrapped < Qt::Object
      
      include Ruber::KTextEditorWrapper
      
      attr_reader :doc
      def initialize
        super
        @doc = KTextEditor::EditorChooser.editor('katepart').create_document( self)
        initialize_wrapper @doc, {}
      end
      
    end
    
    before do
      @obj = SimpleWrapped.new
      @proxy = Ruber::KTextEditorWrapper::InterfaceProxy.new @obj.doc
    end
    
    it 'calls the same method on the stored interface' do
      @proxy.interface = :modification_interface
      lambda{@proxy.modified_on_disk_warning = true}.should_not raise_error
      flexmock(@proxy.instance_variable_get(:@interface)).should_receive(:modified_on_disk_warning=).once.with(true)
      @proxy.modified_on_disk_warning = true
    end
    
    it 'replaces any argument whose class mixes-in Ruber::KTextEditorWrapper with the wrapped object' do
      @proxy.interface = :modification_interface
      #A method called test_method doesn't exist in the interface. However, this
      #is enough to test that the @doc argument is converted to the correct class
      #without my having to search for an actual method taking a document as argument
      flexmock(@proxy.instance_variable_get(:@interface)).should_receive(:test_method).once.with(@obj.doc, true)
      @proxy.test_method @obj, true
    end
    
  end
    
end
