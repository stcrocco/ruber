require 'spec/framework'
require 'spec/common'

require 'tempfile'

require 'plugins/ruby_syntax_checker/ruby_syntax_checker'

describe Ruber::RubySyntaxChecker::Plugin do
  
  NEEDED_PLUGINS = [:syntax_checker, :autosave, :ruby_runner, :ruby_development]
  
  before :all do
    NEEDED_PLUGINS.each do |pl| 
      dir = File.join 'plugins', pl.to_s
      Ruber[:components].load_plugin dir
    end
  end

  before do
    Ruber[:components].load_plugin 'plugins/ruby_syntax_checker'
  end
  
  after do
    Ruber[:components].unload_plugin :ruby_syntax_checker if Ruber[:ruby_syntax_checker]
  end
  
  after :all do
    NEEDED_PLUGINS.reverse_each{|pl| Ruber[:components].unload_plugin pl}
  end
  
  describe 'when created' do
    
    before do
      @file = Tempfile.open ['', '.rb']
    end
    
    after do
      @file.close
    end
  
    it 'registers a syntax checker of class Ruber::RubySyntaxChecker::Checker for files ending in .rb with the syntax checker' do
        checker = Ruber::RubySyntaxChecker::Checker.new flexmock
        flexmock(Ruber::RubySyntaxChecker::Checker).should_receive(:new).once.with(Ruber::Document).and_return checker
        doc = Ruber[:world].document @file.path
      end
      
    end
  
    describe 'when unloaded' do
    
      before do
        @file = Tempfile.open ['', '.rb']
      end
      
      after do
        @file.close
      end
      
      it 'removes the Ruber::RubySyntaxChecker::Checker syntax checker' do
        Ruber[:components].unload_plugin :ruby_syntax_checker
        flexmock(Ruber::RubySyntaxChecker::Checker).should_receive(:new).never
        doc = Ruber[:world].document @file.path
      end
      
    end
    
end

describe Ruber::RubySyntaxChecker::Checker do
  NEEDED_PLUGINS = [:syntax_checker, :autosave, :ruby_runner, :ruby_development]
  
  before :all do
    NEEDED_PLUGINS.each do |pl| 
      dir = File.join 'plugins', pl.to_s
      Ruber[:components].load_plugin dir
    end
  end
    
  after :all do
    NEEDED_PLUGINS.reverse_each{|pl| Ruber[:components].unload_plugin pl}
  end
    
  describe '#check_syntax' do
    
    before do
      @file = Tempfile.open ['', '.rb']
      @doc = Ruber[:world].document @file.path
      @checker = Ruber::RubySyntaxChecker::Checker.new @doc
    end
    
    after do
      @doc.close false
    end
    
    context 'when the first argument is valid ruby' do
      
      it 'returns nil' do
        str = <<-EOS
class X
  def y
    if z
      1 + 2
    end
  end
end
EOS
        @doc.text = str
        @checker.check_syntax(str, true).should be_nil
      end
      
    end
    
    context 'when the first argument is not valid ruby' do
      
      it 'returns an array of Ruber::SyntaxChecker::SyntaxError with the line of the error if the column is unknown' do
        str = <<-EOS
class X
  def y
    1 +
  end
end
EOS
        exp = [Ruber::SyntaxChecker::SyntaxError.new(3, nil, 'unexpected keyword_end', 'unexpected keyword_end')]
        @checker.check_syntax(str, false).should == exp
      end
      
      it 'determines the column number from lines containing all spaces and a single ^' do
                str = <<-EOS
def x
  Y = 1
end
EOS
        @doc.text = str
        @checker.check_syntax(str, false)[0].column.should == 5
      end
      
      it 'attempts to compute the correct position if the error line before the one with the ^ starts with ...' do
        pending 'find an error which causes the above situation'
      end
      
      it 'works correctly when ruby reports unmatched close parenthesis in a regexp' do
        str = '/xy )/'
        @doc.text = str
        exp = [Ruber::SyntaxChecker::SyntaxError.new(0, nil, 'unmatched close parenthesis: /xy )/', 'unmatched close parenthesis: /xy )/')]
        @checker.check_syntax(str, false).should == exp
      end
      
      it 'works correctly when ruby reports unmatched open parenthesis in a regexp' do
        str = '/xy ( a/'
        @doc.text = str
        exp = [Ruber::SyntaxChecker::SyntaxError.new(0, nil, 'end pattern with unmatched parenthesis: /xy ( a/', 'end pattern with unmatched parenthesis: /xy ( a/')]
        @checker.check_syntax(str, false).should == exp
      end

      it 'works correctly when ruby reports an invalid regexp option' do
        str = '/xy/t'
        @doc.text = str
        exp = [Ruber::SyntaxChecker::SyntaxError.new(0, nil, 'unknown regexp option - t', 'unknown regexp option - t')]
        @checker.check_syntax(str, false).should == exp
      end
      
      it 'works correctly when ruby reports a class definition in a method body' do
        str = <<-EOS
def x
  class Y
  end
end
EOS
        @doc.text = str
        msg = 'class definition in method body'
        exp = [Ruber::SyntaxChecker::SyntaxError.new(1, nil, msg, msg)]
        @checker.check_syntax(str, false).should == exp
      end

      it 'works correctly when ruby reports a module definition in a method body' do
        str = <<-EOS
def x
  module Y
  end
end
EOS
        @doc.text = str
        msg = 'module definition in method body '
        exp = [Ruber::SyntaxChecker::SyntaxError.new(1, nil, msg, msg)]
        @checker.check_syntax(str, false).should == exp
      end

      it 'works correctly when ruby reports a dynamic constant assignment' do
        str = <<-EOS
def x
  Y = 1
end
EOS
        @doc.text = str
        msg = "dynamic constant assignment \n  Y = 1"
        exp = [Ruber::SyntaxChecker::SyntaxError.new(1, 5, msg, msg)]
        @checker.check_syntax(str, false).should == exp
      end
      
      it 'works correctly with unknown syntax errors' do
        error_msg = '-e:10:xyz'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        exp = [Ruber::SyntaxChecker::SyntaxError.new(nil, nil, error_msg, error_msg)]
        @checker.check_syntax('', false).should == exp
      end
      
    end
    
    it 'uses the ruby interpreter stored in the ruby/ruby project option' do
      # To check whether the correct interpreter is being used, a syntax which is
      # correct in ruby 1.8 and incorrect in 1.9 is used
      @doc.own_project[:ruby, :ruby] = '/usr/bin/ruby18'
      str = <<-EOS
if x: y
else z
end
EOS
      @doc.text = str
      @checker.check_syntax(str, false).should be_nil
    end
    
    it 'raises Ruber::SyntaxChecker::SyntaxNotChecked if the given interpreter doesn\'t exist'  do
      @doc.own_project[:ruby, :ruby] = '/usr/bin/nonexisting-ruby'
      lambda{@checker.check_syntax('', false)}.should raise_error(Ruber::SyntaxChecker::SyntaxNotChecked)
    end
    
    context 'if the second argument is true' do
      
      it 'replaces instances of "expected $end" with "expected end of file" in the formatter error message' do
        error_msg = '-e:12: syntax error, expected $end'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'expected end of file'
      end
      
      it 'replaces instances of "expecting $end" with "expecting end of file" in the formatter error message' do
        error_msg = '-e:12: syntax error, expecting $end'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'expecting end of file'
      end
      
      it 'replaces instances of "unexpected $end" with "unexpected end of file" in the formatter error message' do
        error_msg = '-e:12: syntax error, unexpected $end'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'unexpected end of file'
      end
      
      it 'replaces instances of "expected kEND" with "expected `end` keyword" in the formatter error message' do
        error_msg = '-e:12: syntax error, expected kEND'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'expected `end` keyword'
      end
      
      it 'replaces instances of "expecting kEND" with "expecting `end` keyword" in the formatter error message' do
        error_msg = '-e:12: syntax error, expecting kEND'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'expecting `end` keyword'
      end
      
      it 'replaces instances of "unexpected kEND" with "unexpected `end` keyword" in the formatter error message' do
        error_msg = '-e:12: syntax error, unexpected kEND'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'unexpected `end` keyword'
      end

      it 'replaces instances of "expected keyword_end" with "expected `end` keyword" in the formatter error message' do
        error_msg = '-e:12: syntax error, expected keyword_end'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'expected `end` keyword'
      end
      
      it 'replaces instances of "expecting keyword_end" with "expecting `end` keyword" in the formatter error message' do
        error_msg = '-e:12: syntax error, expecting keyword_end'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'expecting `end` keyword'
      end
      
      it 'replaces instances of "unexpected keyword_end" with "unexpected `end` keyword" in the formatter error message' do
        error_msg = '-e:12: syntax error, unexpected keyword_end'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        res = @checker.check_syntax('', true)
        res[0].formatted_message.should == 'unexpected `end` keyword'
      end

      
      
    end

  end
  
  
end