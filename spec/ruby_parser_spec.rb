YAML::ENGINE.yamler = 'syck'
require 'spec/framework'
require 'spec/common'

require 'stringio'

require 'plugins/ruby_parser/ruby_parser.rb'


describe Ruber::RubyParser::Plugin do
  
  before do
    Ruber[:components].load_plugin 'plugins/ruby_parser'
    @plug = Ruber[:ruby_parser]
  end
  
  after do
    Ruber[:components].unload_plugin :ruby_parser if Ruber[:ruby_parser]
  end
  
  it 'doesn\'t raise exceptions if YARD can\'t be loaded' do
    main = eval 'self', TOPLEVEL_BINDING
    flexmock(main).should_receive(:require).with('yard').once.and_raise LoadError
    lambda{load './plugins/ruby_parser/ruby_parser.rb'}.should_not raise_error
  end
  
  describe '#parse' do
    
    context 'when called with a string as argument' do
      
      it 'returns a YARD::CodeObjects::Base corresponding to the root of the code' do
        str = <<EOS
  module X
    class Y
      def z
      end
    end
  end
  
  def f
  end
EOS

        res = @plug.parse str
        res.should be_a(YARD::CodeObjects::RootObject)
      end
      
      it 'returns nil if YARD wasn\'t found' do
        str = <<EOS
  module X
    class Y
      def z
      end
    end
  end
EOS
        yard = YARD
        main = eval 'self', TOPLEVEL_BINDING
        main.class.send :remove_const, :YARD
        @plug.parse(str).should be_nil
        ::YARD = yard
      end
      
    end
    
    context 'when called with an argument which responds to #read' do
      
      it 'reads the contents of the object and returns a YARD::CodeObjects::Base corresponding to the root of the file' do
        str = <<EOS
  module X
    class Y
      def z
      end
    end
  end
EOS
        io = StringIO.new str
        res = @plug.parse io
        res.should be_a(YARD::CodeObjects::RootObject)
      end
      
      it 'returns nil if YARD wasn\'t found' do
        str = <<EOS
  module X
    class Y
      def z
      end
    end
  end
EOS
        main = eval 'self', TOPLEVEL_BINDING
        yard = YARD
        main.class.send :remove_const, :YARD
        io = StringIO.new str
        @plug.parse(io).should be_nil
        ::YARD = yard
      end
      
    end

    
  end
  
end