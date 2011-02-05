require './spec/framework'
require './spec/common'
require 'plugins/auto_end/auto_end'
require 'tempfile'

module InsertionChecker
  
  def it_should_insert_end cond, text, initial_text, exp_text, cursor_pos = [2, 0]
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
          flexmock(@doc).should_receive(:active_view).and_return @view
          @doc.block_signals true
          @doc.text= initial_text.sub '%', ''
          @doc.block_signals false
          #avoid messing up the text with indentation
          flexmock(@view).should_receive(:execute_action).with('tools_align').by_default
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
  
  before do
    Ruber[:components].load_plugin 'plugins/auto_end/'
    @file = Tempfile.new ['auto_end_test', '.rb']
    @doc = Ruber[:documents].document @file.path
    @ext = @doc.extension(:auto_end)
  end
  
  after do
    Ruber[:components].unload_plugin :auto_end
    @file.close true
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
    
    context 'and the last line contains a module' do
      
      it_should_insert_end "if the module is at the beginning of the line and followed by spaces, an identifier, possible spaces and end of line", "module xY_12a\n", "module X\n%\nend", "module X\nmodule xY_12a\n\nend\nend"
      
      it_should_insert_end "if the module is at the beginning of the line, preceded only by spaces and followed by spaces, an identifier, possible spaces and end of line", "  module xY_12a \n", "module X\n%\nend", "module X\n  module xY_12a \n\nend\nend"
      
      it 'does not insert an end keyword if the identifier is followed by anything but spaces or other identifers separated by ::' do
        @doc.block_signals true
        @doc.text = "module X\n\nend"
        @doc.block_signals false
        @doc.insert_text KTextEditor::Cursor.new(1,0), 'module Y a.b'
        @doc.text.should == "module X\nmodule Y a.b\nend"
      end
      
      it_should_insert_end "if the module is at the beginning of the line and followed by spaces, a sequence of identifiers separated by ::, possible spaces and end of line", "module xY_12a::Ac::By\n", "module X\n%\nend", "module X\nmodule xY_12a::Ac::By\n\nend\nend"

    end
    
    context 'and the last line contains a class' do
      
      it_should_insert_end "if the class is at the beginning of the line and followed by spaces, an identifier, possible spaces and end of line", "class xY_12a\n", "module X\n%\nend", "module X\nclass xY_12a\n\nend\nend"
      
      it_should_insert_end "if the class is at the beginning of the line and followed by spaces, an identifier, a <, another identifier, possible spaces and end of line", "class xY_12a < Ba6_1\n", "module X\n%\nend", "module X\nclass xY_12a < Ba6_1\n\nend\nend"
      
      it_should_insert_end "if the class is at the beginning of the line and followed by spaces, an identifier, a <<, another identifier, possible spaces and end of line", "class xY_12a << Ba6_1\n", "module X\n%\nend", "module X\nclass xY_12a << Ba6_1\n\nend\nend"
      
      it_should_insert_end "in all the previous cases if there are more than one identifier separated by :: instead of a single identifier", "class A::B < C::D\n", "module X\n%\nend", "module X\nclass A::B < C::D\n\nend\nend"
      
    end
    
    context "and the last line contains a def" do
      
      it_should_insert_end "if the def is at the beginning of the line", "def xyz a, b\n", "class X\n%\nend", "class X\ndef xyz a, b\n\nend\nend"
      
      it_should_insert_end 'if the def is preceded only by spaces', "  def xyz a, b\n", "class X\n%\nend", "class X\n  def xyz a, b\n\nend\nend"

    end
    
    context "and the last line contains an if " do
      
      it_should_insert_end "if the if is at the beginning of the line", "if kkk\n", "class X\n%\nend", "class X\nif kkk\n\nend\nend", [2, 0]
      
      it_should_insert_end "if the if is preceded only by whitespaces", "  if kkk\n", "class X\n%\nend", "class X\n  if kkk\n\nend\nend", [2, 0]
      
      it_should_insert_end 'if the if is preceded by an =', "x =if kkk\n",
          "class X\n%\nend", "class X\nx =if kkk\n\nend\nend"
      
      it_should_insert_end 'if the if is preceded by an = followed by spaces', "x = if kkk\n", "class X\n%\nend", "class X\nx = if kkk\n\nend\nend"
      
    end
    
    context "and the line contains a do" do
      
      it_should_insert_end "if the do is at the end of the line", "x.each do\n", "def y x\n%\nend", "def y x\nx.each do\n\nend\nend", [2, 0]
      
      it_should_insert_end "if the do is only followed by whitespaces", "  x.each do\n", "def y x\n%\nend", "def y x\n  x.each do\n\nend\nend", [2, 0]
      
      it_should_insert_end "if the do is followed by spaces and a pipe char", "  x.each do |a|\n", "def y x\n%\nend", "def y x\n  x.each do |a|\n\nend\nend", [2, 0]
      
      it 'does nothing if the first character of the line is a #' do
        @doc.block_signals true
        @doc.text = "def x\n\nend"
        @doc.block_signals false
        @doc.insert_text KTextEditor::Cursor.new(1,0), "# a.each do\n"
        @doc.text.should == "def x\n# a.each do\n\nend"
      end
      
      it 'does nothing if the line starts with spaces followed by a #' do
        @doc.block_signals true
        @doc.text = "def x\n\nend"
        @doc.block_signals false
        @doc.insert_text KTextEditor::Cursor.new(1,0), " # a.each do\n"
        @doc.text.should == "def x\n # a.each do\n\nend"
      end
      
    end
    
    context "and the last line contains a begin" do
      
      it_should_insert_end "if the begin is at the beginning of the line", "begin kkk\n", "class X\n%\nend", "class X\nbegin kkk\n\nend\nend", [2, 0]

      it_should_insert_end "if the begin is preceded only by whitespaces", "  begin kkk\n", "class X\n%\nend", "class X\n  begin kkk\n\nend\nend", [2, 0]
      
      it_should_insert_end 'if the begin is preceded by an =', "x =begin kkk\n",
      "class X\n%\nend", "class X\nx =begin kkk\n\nend\nend"
      
      it_should_insert_end 'if the begin is preceded by an = followed by spaces', "x = begin kkk\n", "class X\n%\nend", "class X\nx = begin kkk\n\nend\nend"
      
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