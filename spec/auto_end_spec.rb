require './spec/framework'
require './spec/common'
require 'plugins/auto_end/auto_end'
require 'tempfile'

module InsertionChecker
  
  def it_checks_for_syntax_errors_when cond, inserted_text, existing_text = ''
    lines = existing_text.split "\n"
    insert_pos = lines.find_and_map do |l|
      if l.include? '%'
        [lines.index(l), l.index('%')]
      end
    end
    insert_pos ||= [existing_text.each_line.count, 0]
    insert_pos = KTextEditor::Cursor.new *insert_pos

    context "when #{cond}" do
      
      context 'and the document is active' do
        
        before do
          @doc.activate
          @view = @doc.create_view
          @doc.text = ''
          flexmock(@doc).should_receive(:active_view).and_return @view
          @doc.block_signals true
          @doc.text= existing_text.sub '%', ''
          @doc.block_signals false
          #avoid messing up the text with indentation
          flexmock(@view).should_receive(:execute_action).with('tools_align').by_default
        end
        
        it 'checks the syntax of the document' do
          flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).with(:format => false, :update => false).once.and_return :errors => []
          @doc.insert_text insert_pos, inserted_text
        end
        
      end
      
      context 'and the active view is not associated with the document' do
        
        before do
          @doc.deactivate
          flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).never
        end
        
        it 'does nothing' do
          flexmock(@doc).should_receive(:active_view).and_return nil
          old_text = @doc.text
          @doc.insert_text insert_pos, inserted_text
        end
        
      end
      
    end
    
  end
  
  def it_doesnt_check_for_syntax_errors_when cond, line, existing_text = ''
    
    lines = existing_text.split "\n"
    insert_pos = lines.find_and_map do |l|
      if l.include? '%'
        [lines.index(l), l.index('%')]
      end
    end
    insert_pos ||= [existing_text.each_line.count, 0]
    insert_pos = KTextEditor::Cursor.new *insert_pos
    
    context "when #{cond}" do
      
      context "and the view is active" do
        
        before do
          @doc.activate
          @view = @doc.create_view
          @doc.text = ''
          flexmock(@doc).should_receive(:active_view).and_return @view
          @doc.block_signals true
          @doc.text= existing_text.sub '%', ''
          @doc.block_signals false
          #avoid messing up the text with indentation
          flexmock(@view).should_receive(:execute_action).with('tools_align').by_default
        end
        
        it 'doesn\'t check the syntax of the document' do
          flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).never
          @doc.insert_text insert_pos, line
        end
        
      end
      
      context 'and the active view is not associated with the document' do
        
        before do
          @doc.deactivate
          flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).never
        end
        
        it 'does nothing' do
          flexmock(@doc).should_receive(:active_view).and_return nil
          old_text = @doc.text
          @doc.insert_text insert_pos, line
        end
        
      end

      
    end

    
  end
  
  def it_should_insert_end cond, text, initial_text, exp_text, error_type, cursor_pos = [2, 0],  error_message = ''
    lines = initial_text.split "\n"
    insert_pos = lines.find_and_map do |l|
      if l.include? '%'
        [lines.index(l), l.index('%')]
      end
    end
    insert_pos ||= [initial_text.each_line.count, 0]
    insert_pos = KTextEditor::Cursor.new *insert_pos
    
    context cond do
    
      context "and the active view is associated with the document" do
        
        before do
          @view = @doc.create_view
          @doc.text = ''
          flexmock(@doc).should_receive(:active_view).and_return @view
          @doc.block_signals true
          @doc.text= initial_text.sub '%', ''
          @doc.block_signals false
          #avoid messing up the text with indentation
          flexmock(@view).should_receive(:execute_action).with('tools_align').by_default
          error = {:errors => [OpenStruct.new(:error_type => error_type, :error_message => error_message)]}
          flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).with(:format => false, :update => false).once.and_return error
        end
        
        it "inserts an an empty line followed by and end keyword" do
          lines = text.split
          @doc.insert_text insert_pos, text
          @doc.text.should == exp_text
        end
        
        it 'indents the text' do
          flexmock(@view).should_receive(:execute_action).with('tools_align').once
          @doc.insert_text insert_pos, text
        end
        
        it 'moves the cursor to the line before the end' do
          @doc.insert_text insert_pos, text
          @view.cursor_position.should == KTextEditor::Cursor.new(*cursor_pos)
        end
        
      end
    
      context 'and the active view is not associated with the document' do
        
        before do
          flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).never
        end
        
        it 'does nothing' do
          flexmock(@doc).should_receive(:active_view).and_return nil
          old_text = @doc.text
          @doc.insert_text insert_pos, text
          @doc.text.should == old_text
        end
        
      end
      
    end
          
  end
  
end

describe Ruber::AutoEnd::Extension do
  
  extend InsertionChecker
  
  before :all do
    Ruber[:components].load_plugin 'plugins/autosave'
    Ruber[:components].load_plugin 'plugins/ruby_runner'
    Ruber[:components].load_plugin 'plugins/ruby_development'
    Ruber[:components].load_plugin 'plugins/syntax_checker'
    Ruber[:components].load_plugin 'plugins/ruby_syntax_checker'
  end
  
  before do
    Ruber[:components].load_plugin 'plugins/auto_end/'
    @file = Tempfile.new ['auto_end_test', '.rb']
    @doc = Ruber[:world].document @file.path
    @ext = @doc.extension(:auto_end)
  end
  
  after do
    Ruber[:components].unload_plugin :auto_end
    @file.close true
  end
  
  after :all do
    Ruber[:components].unload_plugin :ruby_syntax_checker
    Ruber[:components].unload_plugin :syntax_checker
    Ruber[:components].unload_plugin :ruby_development
    Ruber[:components].unload_plugin :autosave
    Ruber[:components].unload_plugin :ruby_runner
  end
  
  it 'includes the Extension module' do
    Ruber::AutoEnd::Extension.should include(Ruber::Extension)
  end
  
  it 'inherits Qt::Object' do
    Ruber::AutoEnd::Extension.ancestors.should include(Qt::Object)
  end
  
  context 'when created' do
  
    it 'connects the text_inserted(KTextEditor::Range, QObject*) signal of the document with the text_inserted(KTextEditor::Range) slot' do
      range = KTextEditor::Range.new 2, 3, 5, 6
      flexmock(@ext).should_receive(:text_inserted).once.with range
      @doc.instance_eval{emit text_inserted(range, self)}
    end
        
  end
  
  context 'when a piece of text not ending in a newline is inserted' do
    
    it 'does nothing' do
      @doc.text = "xyz\nabc"
      @doc.insert_text KTextEditor::Cursor.new(1,2), 'X'
      @doc.text.should == "xyz\nabXc"
    end
    
  end
  
  context 'when a piece of text ending with a newline is inserted' do
    
    it_checks_for_syntax_errors_when 'the line contains the word "module"', "abc module xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "class"', "abc class xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "if" preceded only by whitespaces', "   if abc\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "if" preceded by an equal sign whitespaces', "a = if abc\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the word "if" preceded by anything other than an equal sign and/or spaces', "abc if xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "unless" at the beginning of the line, maybe preceded only by spaces', "   unless xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "unless" preceded by an equal sign and maybe by spaces', " abc =  unless xyz\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the "unless" word, but not at the beginning of line or preceded by an equal sign', "  abc unless xyz"
    
    it_checks_for_syntax_errors_when 'the line contains the word "do" followed by optional spaces the end of line', "abc do\n"
        
    it_checks_for_syntax_errors_when 'the line contains the word "do" followed by optional spaces and the pipe character', "abc do |xyz| \n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains "do" but not as a standalone word', "abcdo\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the word do but it is followed by something other than the end of line or a pipe character', "abc do xyz"
    
    it_checks_for_syntax_errors_when 'the line contains the word "def" at the begining of line (optionally preceded by spaces) and followed by a space', "  def \n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the word "def" but not at the beginning of the line (optionally preceded by spaces)', "abc def \n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the string "def" but not followed by spaces', " defx \n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "case" at the beginning of the line, maybe preceded only by spaces', "   case xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "case" preceded by an equal sign and maybe by spaces', " abc =  case xyz\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the "case" word, but not at the beginning of line or preceded by an equal sign', "  abc case xyz"
    
    it_checks_for_syntax_errors_when 'the line contains the word "while" at the beginning of the line, maybe preceded only by spaces', "   while xyz\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the "while" word, but not at the beginning of line or preceded by an equal sign', "  abc while xyz"
    
    it_checks_for_syntax_errors_when 'the line contains the word "until" at the beginning of the line, maybe preceded only by spaces', "   until xyz\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the "until" word, but not at the beginning of line or preceded by an equal sign', "  abc until xyz"
    
    it_checks_for_syntax_errors_when 'the line contains the word "for" at the beginning of the line, maybe preceded only by spaces', "   for xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "for" preceded by an equal sign and maybe by spaces', " abc =  for xyz\n"
    
    it_doesnt_check_for_syntax_errors_when 'the line contains the "for" word, but not at the beginning of line or preceded by an equal sign', "  abc for xyz"
    
    it_checks_for_syntax_errors_when 'the line contains the word "begin" at the beginning of the line, maybe preceded by spaces', "   begin xyz\n"
    
    it_checks_for_syntax_errors_when 'the line contains the word "begin" preceded by an equal sign and optionally by space', "  a = begin xyz\n"
    
    context ', the syntax check returns errors' do
      
      before do
        @view = @doc.create_view
        @doc.text = ''
        flexmock(@doc).should_receive(:active_view).and_return @view
        #avoid messing up the text with indentation
        flexmock(@view).should_receive(:execute_action).with('tools_align').by_default
        @doc.activate
      end
      
      context 'and the last error is of type :missing_end' do
        
        before do
          errors = {:errors => [OpenStruct.new(:error_type => :xyz, :error_message => ''), OpenStruct.new(:error_type => :missing_end, :error_message => 'missing kEND')]}
        flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).with(:format => false, :update => false).once.and_return errors

        end
        
        it "inserts an an empty line followed by an =end if the line starts with =begin" do
          @doc.insert_text KTextEditor::Cursor.new, "abc\n=begin xyz\n"
          @doc.text.should == "abc\n=begin xyz\n\n=end"
        end
        
        it 'inserts an empty line followed by an end keyword if the line starts with something other than =begin' do
          @doc.insert_text KTextEditor::Cursor.new, "abc\ndef xyz\n"
          @doc.text.should == "abc\ndef xyz\n\nend"
        end
        
        it 'indents the text' do
          flexmock(@view).should_receive(:execute_action).with('tools_align').once
          @doc.insert_text KTextEditor::Cursor.new, "def xyz\n"
        end
        
        it 'moves the cursor to the line before the end' do
          @doc.insert_text KTextEditor::Cursor.new, "def xyz\n"
          @view.cursor_position.should == KTextEditor::Cursor.new(1,0)
        end
                
      end
      
      context 'and the last error is not of type :missing_end' do
        
        it 'doesn\'t alter the text' do
        errors = {:errors => [OpenStruct.new(:error_type => :xyz, :error_message => ''), OpenStruct.new(:error_type => :abc, :error_message => '')]}
        flexmock(@doc.extension(:syntax_checker)).should_receive(:check_syntax).with(:format => false, :update => false).once.and_return errors
        @doc.insert_text KTextEditor::Cursor.new, "def a\nxyz)"
        @doc.text.should == "def a\nxyz)"
        end
        
      end
      
    end
    
  end
  
  it 'doesn\'t insert end keywords in the middle of a multi-line text' do
    view = @doc.create_view
    flexmock(@doc).should_receive(:active_view).and_return view
    text = "class X\ndef y\n\nend\nend"
    @doc.insert_text KTextEditor::Cursor.new(0,0), text
    @doc.text.should == text
  end
  
end