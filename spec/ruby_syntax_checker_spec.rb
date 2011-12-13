require 'spec/framework'
require 'spec/common'

require 'tempfile'

require 'plugins/ruby_syntax_checker/ruby_syntax_checker'

describe Ruber::RubySyntaxChecker::Plugin do

  RSpec::Matchers.define :be_same_error_as do |other_err|
    match do |err|
      err.line == other_err.line and err.column == other_err.column and
          err.message == other_err.message and err.formatted_message ==
          other_err.formatted_message
    end
  end
  
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
      
      it 'returns an array of Ruber::RubySyntaxChecker::SyntaxError with the line of the error if the column is unknown' do
        str = <<-EOS
class X
  def y
    1 +
  end
end
EOS
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(3, nil, 'unexpected keyword_end', 'unexpected keyword_end')
        @checker.check_syntax(str, false)[0].should be_same_error_as(exp)
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
      
      context 'when ruby reports a syntax error' do

        error_types = [
          [:missing_end, "ruby reports a missing end keyword", 'class X;def y;end'],
          [:extra_end, "ruby reports an unexpected end keyword at EOF", 'class X;def y;end;end;end'],
          [:misplaced_end, "ruby reports an unexpected end keyword not at EOF", 'def x;1+end'],
          [:missing_close_paren, "ruby reports an expected )", 'def x;1*(2+1;end'],
          [:extra_close_paren, "ruby reports an unexpected )", 'x;1*2+1)'],
          [:missing_close_bracket, "ruby reports an expected ]", 'x=['],
          [:extra_close_bracket, "ruby reports an unexpected ]", 'x=]'],
          [:missing_close_brace, "ruby reports an expected }", 'x={'],
          [:extra_close_brace, "ruby reports an unexpected }", 'x=}'],
          [:extra_else, "ruby reports an unexpected else", "x;else;end"],
          [:missing_quote, "ruby reports an unterminated string", "def x;'"],
          [:missing_regexp_close_paren, "ruby reports unmatched open parenthesis in regexp", '/xy ( a/'],
          [:extra_regexp_close_paren, "ruby reports unmatched close parenthesis in regexp", '/xy ) a/'],
          [:missing_regexp_close_bracket, "ruby reports premature end of char-class", '/ xy [/'],
          [:unknown_regexp_option, "ruby reports an unknown regexp option", '/a/t'],
          [:dynamic_constant_assignment , "ruby reports a dynamic constant assignment", 'def x;X=2;end'],
          [:extra_when, "ruby reports an unexpected when keyword", 'when 2 then 3'],
          [:extra_rescue, "ruby reports an unexpected rescue keyword", 'rescue'],
          [:extra_ensure, "ruby reports an unexpected ensure keyword", 'ensure'],
          [:missing_block_comment_end, "ruby reports an embedded document meets end of file", '=begin'],
          [:missing_heredoc_end, "ruby reports it can't find the end of a heredoc", "str=<<EOS"]
        ]

        error_types.each do |type, cond, code|
          it "sets the error_type attribute of the error object to #{type} if #{cond}" do
            errors = @checker.check_syntax(code, false)
            errors[0].error_type.should == type
          end
        end
        
      end
      
      it 'works correctly when ruby reports unmatched open parenthesis in a regexp' do
        str = '/xy ( a/'
        @doc.text = str
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(0, nil, 'end pattern with unmatched parenthesis: /xy ( a/', 'end pattern with unmatched parenthesis: /xy ( a/')
        @checker.check_syntax(str, false)[0].should be_same_error_as(exp)
      end
      
      it 'works correctly when ruby reports the premature end of a character class' do
        str = '/xy [ a/'
        @doc.text = str
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(0, nil, 'premature end of char-class: /xy [ a/', 'premature end of char-class: /xy [ a/')
        @checker.check_syntax(str, false)[0].should be_same_error_as(exp)
      end

      it 'works correctly when ruby reports an invalid regexp option' do
        str = '/xy/t'
        @doc.text = str
        exp = [Ruber::RubySyntaxChecker::SyntaxError.new(0, nil, 'unknown regexp option - t', 'unknown regexp option - t')]
        @checker.check_syntax(str, false)[0].should be_same_error_as(exp[0])
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
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(1, nil, msg, msg)
        @checker.check_syntax(str, false)[0].should == exp
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
        exp = [Ruber::RubySyntaxChecker::SyntaxError.new(1, nil, msg, msg)]
        @checker.check_syntax(str, false).should == exp
      end
      
      it 'works correctly when ruby reports an unterminated string' do
        @doc.text = 'def x;"'
        msg = "unterminated string meets end of file "
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(0, nil, msg, msg)
        @checker.check_syntax(@doc.text, false)[0].should be_same_error_as(exp)
      end
      
      it 'works correctly when ruby reports an unterminated block comment' do
        @doc.text = '=begin x'
        msg = "embedded document meets end of file "
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(0, nil, msg, msg)
        @checker.check_syntax(@doc.text, false)[0].should be_same_error_as(exp)
      end
      
      it 'works correctly when ruby reports an unterminated heredoc' do
        @doc.text = "str=<<EOS"
        msg = 'can\'t find string "EOS" anywhere before EOF '
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(0, nil, msg, msg)
        @checker.check_syntax(@doc.text, false)[0].should be_same_error_as(exp)
      end

      it 'works correctly when ruby reports a dynamic constant assignment' do
        str = <<-EOS
def x
  Y = 1
end
EOS
        @doc.text = str
        msg = "dynamic constant assignment \n  Y = 1"
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(1, 5, msg, msg)
        @checker.check_syntax(str, false)[0].should be_same_error_as(exp)
      end
      
      it 'works correctly with unknown syntax errors' do
        error_msg = '-e:10:xyz'
        flexmock(Open3).should_receive(:popen3).once.and_return error_msg
        exp = Ruber::RubySyntaxChecker::SyntaxError.new(nil, nil, error_msg, error_msg)
        @checker.check_syntax('', false)[0].should be_same_error_as(exp)
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