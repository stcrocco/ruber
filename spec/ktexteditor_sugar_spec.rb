require './spec/common'
require 'ruber/ktexteditor_sugar'

describe KTextEditor::Cursor do
  
  describe '#inspect' do
    
    it 'returns a string containing the class, the object id and the line and column associated with the cursor' do
      line = 12
      col = 38
      cur = KTextEditor::Cursor.new line, col
      exp = "<KTextEditor::Cursor:#{cur.object_id} line=#{line} column=#{col}"
      cur.inspect.should == exp
    end
    
  end
  
  describe '#==' do
    
    it 'returns true if the argument is a Cursor with the same line and column' do
      line = 10
      col = 24
      c1, c2 = 2.times.map{KTextEditor::Cursor.new line, col}
      c1.should == c2
    end
    
    it 'returns false if the argument is a Cursor with a different line or column number' do
      cursor = KTextEditor::Cursor.new 10, 34
      cursors = 
        [
          KTextEditor::Cursor.new(10, 21),
          KTextEditor::Cursor.new(2, 34),
          KTextEditor::Cursor.new(1, 9)
        ]
      cursors.each{|c| cursor.should_not == c}
    end
    
    it 'returns false if the other object is not a Cursor' do
      cursor = KTextEditor::Cursor.new(10, 34).should_not == "x"
    end
    
  end
  
  describe '#dup' do
    
    before do
      @cur = KTextEditor::Cursor.new 23, 57
    end
    
    it 'returns a copy of self' do
      res = @cur.dup
      res.should == @cur
      res.should_not equal(@cur)
    end
    
    it 'doesn\'t copy the frozen state of self' do
      res = @cur.dup
      res.should_not be_frozen
      @cur.freeze
      res = @cur.dup
      res.should_not be_frozen
    end
    
  end
  
  describe '#clone' do
    
    before do
      @cur = KTextEditor::Cursor.new 23, 57
    end
    
    it 'returns a copy of self' do
      res = @cur.clone
      res.should == @cur
      res.should_not equal(@cur)
    end
    
    it 'copies the frozen state of self' do
      res = @cur.clone
      res.should_not be_frozen
      @cur.freeze
      res = @cur.clone
      res.should be_frozen
    end
    
  end
  
end