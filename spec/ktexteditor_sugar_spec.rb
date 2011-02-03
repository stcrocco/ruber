require './spec/common'
require 'ruber/ktexteditor_sugar'

describe KTextEditor::Cursor do
  
  describe '#inspect' do
    
    it 'returns a string containing the class, the object id and the line and column associated with the cursor' do
      line = 12
      col = 38
      cur = KTextEditor::Cursor.new line, col
      exp = "<KTextEditor::Cursor:#{cur.object_id} line=#{line} column=#{col}>"
      cur.inspect.should == exp
    end
    
    it 'returns a string containing the class, the object id and the string DISPOSED if the Cursor has been disposed' do
      range = KTextEditor::Cursor.new 1,2
      range.dispose
      range.inspect.should == "<KTextEditor::Cursor:#{range.object_id} DISPOSED>"
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

describe KTextEditor::Range do
  
  describe '#inspect' do
    
    it 'returns a string containing the class, the object id and the starting and ending line and column' do
      start_line = 12
      start_col = 38
      end_line = 15
      end_col = 20
      range = KTextEditor::Range.new start_line, start_col, end_line, end_col
      exp = "<KTextEditor::Range:#{range.object_id} start=(#{start_line};#{start_col}) end=(#{end_line};#{end_col})>"
      range.inspect.should == exp
    end
    
    it 'returns a string containing the class, the object id and the string DISPOSED if the Range has been disposed' do
      range = KTextEditor::Range.new 1,2,3,4
      range.dispose
      range.inspect.should == "<KTextEditor::Range:#{range.object_id} DISPOSED>"
    end
    
  end
  
  describe '==' do
    
    it 'returns true if the argument is a Range with the same start and end' do
      r1 = KTextEditor::Range.new 12, 4, 13, 5
      r2 = KTextEditor::Range.new 12, 4, 13, 5
      r1.should == r2
    end
    
    it 'returns false if the argument is not a Range' do
      r = KTextEditor::Range.new 12, 4, 13, 5
      r.should_not == 'x'
    end
    
    it 'returns false if the argument is a range with different start or end' do
      range = KTextEditor::Range.new 12, 4, 13, 5
      ranges = [
        KTextEditor::Range.new(11,4,13,5),
        KTextEditor::Range.new(12,4,13,9),
        KTextEditor::Range.new(13,2,15,6)
      ]
      ranges.each{|r| r.should_not == range}
    end
    
  end
  
  describe '#dup' do
    
    before do
      @range = KTextEditor::Range.new 23, 57, 46, 23
    end
    
    it 'returns a copy of self' do
      res = @range.dup
      res.should == @range
      res.should_not equal(@range)
    end
    
    it 'doesn\'t copy the frozen state of self' do
      res = @range.dup
      res.should_not be_frozen
      @range.freeze
      res = @range.dup
      res.should_not be_frozen
    end
    
  end
  
  describe '#clone' do
    
    before do
      @range = KTextEditor::Range.new 23, 57, 46, 23
    end
    
    it 'returns a copy of self' do
      res = @range.clone
      res.should == @range
      res.should_not equal(@range)
    end
    
    it 'copies the frozen state of self' do
      res = @range.clone
      res.should_not be_frozen
      @range.freeze
      res = @range.clone
      res.should be_frozen
    end
    
  end

  
  
end