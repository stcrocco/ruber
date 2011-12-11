require 'spec/framework'
require 'spec/common'

require 'tempfile'

require 'plugins/yaml_syntax_checker/yaml_syntax_checker'

describe Ruber::YAMLSyntaxChecker::Plugin do
  
  before :all do
    Ruber[:components].load_plugin 'plugins/syntax_checker'
  end

  before do
    Ruber[:components].load_plugin 'plugins/yaml_syntax_checker'
  end
  
  after do
    Ruber[:components].unload_plugin :yaml_syntax_checker if Ruber[:yaml_syntax_checker]
  end
  
  after :all do
    Ruber[:components].unload_plugin :syntax_checker
  end
  
  describe 'when created' do
    
    before do
      @file = Tempfile.open ['', '.yaml']
    end
    
    after do
      @file.close
    end
  
    it 'registers a syntax checker of class Ruber::YAMLSyntaxChecker::Checker for files ending in .yaml with the syntax checker' do
      checker = Ruber::YAMLSyntaxChecker::Checker.new nil
      flexmock(Ruber::YAMLSyntaxChecker::Checker).should_receive(:new).once.with(Ruber::Document).and_return checker
      doc = Ruber[:world].document @file.path
    end
    
  end
  
  describe 'when unloaded' do
    
    before do
      @file = Tempfile.open ['', '.yaml']
    end
    
    after do
      @file.close
    end
    
    it 'removes the Ruber::YAMLSyntaxChecker::Checker syntax checker' do
      Ruber[:components].unload_plugin :yaml_syntax_checker
      flexmock(Ruber::YAMLSyntaxChecker::Checker).should_receive(:new).never
      doc = Ruber[:world].document @file.path
    end
    
  end
  
end

describe Ruber::YAMLSyntaxChecker::Checker do
  
  before :all do
    Ruber[:components].load_plugin 'plugins/syntax_checker'
  end
  
  after :all do
    Ruber[:components].unload_plugin :syntax_checker
  end
    
  describe '#check_syntax' do
    
    before do
      @checker = Ruber::YAMLSyntaxChecker::Checker.new nil
    end
    
    context 'when the first argument is valid YAML' do
      
      it 'returns nil' do
        str = <<-EOS
- x
- y
- z:
   a
- w:
   b
EOS
        @checker.check_syntax(str, true).should be_nil
      end
      
    end
    
    context 'when the first argument is not valid YAML' do
      
      it 'returns an array of Ruber::YAMLSyntaxChecker::SyntaxError with the line and column of the error' do
        str = <<-EOS
- x
- y
- {
EOS
        exp = [Ruber::YAMLSyntaxChecker::SyntaxError.new(3, 0, 'Syntax error', 'Syntax error')]
        @checker.check_syntax(str, true).should == exp
      end
      
      it 'reports 0 as line number if the line number is less than 0' do
        flexmock(YAML).should_receive(:parse).once.and_raise(ArgumentError, 'Syntax error on line -1, col 2')
        exp = [Ruber::YAMLSyntaxChecker::SyntaxError.new(0, 2, 'Syntax error', 'Syntax error')]
        @checker.check_syntax('', true).should == exp
      end
      
      it 'reports 0 as column number if the column number is less than 0' do
        flexmock(YAML).should_receive(:parse).once.and_raise(ArgumentError, 'Syntax error on line 3, col -2')
        exp = [Ruber::YAMLSyntaxChecker::SyntaxError.new(3, 0, 'Syntax error', 'Syntax error')]
        @checker.check_syntax('', true).should == exp
      end

      
      it 'returns an empty array if it can\'t parse the error message' do
        flexmock(YAML).should_receive(:parse).once.and_raise(ArgumentError, 'xyz')
        @checker.check_syntax('', true).should == []
      end
      
    end

  end
  
end