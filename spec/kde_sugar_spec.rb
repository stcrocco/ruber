require 'spec/common'

require 'ruber/kde_sugar'

describe 'KDE::Url' do
  
  it 'is serializable using YAML' do
    u = KDE::Url.new 'http:///xyz.org/a%20file%20with%20spaces.txt'
    res = YAML.load(YAML.dump(u))
    res.should == u
    res.should_not equal(u)
  end
  
  it 'is marshallable' do
    u = KDE::Url.new 'http:///xyz.org/a%20file%20with%20spaces.txt'
    res = Marshal.load(Marshal.dump(u))
    res.should == u
    res.should_not equal(u)
  end
  
  describe '.file_url?' do
    
    it 'returns false if the first argument doesn\'t start with a scheme followed by //' do
      KDE::Url.file_url?('http:xyz/abc', true).should be_false
      KDE::Url.file_url?('http:xyz/abc', false).should be_false
      KDE::Url.file_url?('http:/xyz/abc', true).should be_false
      KDE::Url.file_url?('http:/xyz/abc', false).should be_false
    end
    
    context 'when the second argument is true' do
    
      it 'returns true if the first argument looks like an absolute URL with authority' do
        KDE::Url.file_url?('http:///xyz/abc', true).should be_true
      end
      
      it 'returns false if the path isn\'t absolute' do
        KDE::Url.file_url?('http://xyz/abc', true).should be_false
      end
      
    end
    
    context 'when the second argument is false or missing' do
      
      it 'returns true if the first argument looks like an absolute URL with authority' do
        KDE::Url.file_url?('http:///xyz/abc', false).should be_true
        KDE::Url.file_url?('http:///xyz/abc').should be_true
      end
      
      it 'returns true if the first argument looks like a relative URL with authority' do
        KDE::Url.file_url?('http://xyz/abc', false).should be_true
        KDE::Url.file_url?('http://xyz/abc').should be_true
      end


    end
    
  end
  
  describe '#local_file?' do
    
    it 'returns true for urls with file: scheme representing absolute paths' do
      KDE::Url.new('file:///xyz').should be_local_file
    end
    
    it 'returns true for urls with file: scheme representing relative paths' do
      KDE::Url.new('file://xyz').should be_local_file
    end
    
    it 'returns false for urls without scheme' do
      KDE::Url.new('xyz').should_not be_local_file
    end
    
    it 'returns false for urls whose scheme is different from file:' do
      KDE::Url.new('http://xyz').should_not be_local_file
    end
    
  end
  
  describe '#remote_file?' do
    
    it 'returns false if the url has file: scheme' do
      KDE::Url.new('file:///xyz').should_not be_remote_file
      KDE::Url.new('file://xyz').should_not be_remote_file
    end
    
    it 'returns false if the url has no scheme' do
      KDE::Url.new('xyz').should_not be_remote_file
    end
    
    it 'returns true for urls whose scheme is different from file:' do
      KDE::Url.new('http://yxz').should be_remote_file
    end
    
  end
  
  describe '#eql?' do
    it 'returns true if the two URLs are equal according to ==' do
      u1, u2 = 2.times.map{KDE::Url.new 'file:///xyz'}
      u1.should eql(u2)
    end
  end
  
  describe '#hash' do
    
    it 'returns the hash value of the path' do
      u = KDE::Url.new 'file://xyz'
      u.hash.should == u.path.hash
    end
    
  end
  
end

describe 'KDE::MimeType#=~' do
  
  before do
    @mime = KDE::MimeType.mime_type 'application/x-ruby'
  end
  
  it 'should return true if the mimetype is a child of the argument or if they\'re equal and false otherwise' do
    (@mime =~ 'application/x-ruby').should be_true
    (@mime =~ 'text/plain').should be_true
    (@mime =~ 'text/x-python').should be_false
  end
  
  it 'should return invert the match if the argument starts with a !' do
    (@mime =~ '!application/x-ruby').should be_false
    (@mime =~ '!text/plain').should be_false
    (@mime =~ '!text/x-python').should be_true
  end
  
  it 'should return true only if the argument is equal to the mimetype\'s name if the argument starts with =' do
    (@mime =~ '=application/x-ruby').should be_true
    (@mime =~ '=text/plain').should be_false
    (@mime =~ '=text/x-python').should be_false
  end
  
  it 'should make an exact match and invert it if the argument starts with != or =!' do
    (@mime =~ '!=application/x-ruby').should be_false
    (@mime =~ '!=text/plain').should be_true
    (@mime =~ '!=text/x-python').should be_true
    (@mime =~ '=!application/x-ruby').should be_false
    (@mime =~ '=!text/plain').should be_true
    (@mime =~ '=!text/x-python').should be_true
  end
    
end

describe KDE::ComboBox do

  before do
    @combo = KDE::ComboBox.new
    @combo.add_items %w[a b c d]
  end

  describe '#items' do
    
    it 'returns an array containing the items in the combo box' do
      @combo.items.should == %w[a b c d]
    end
    
  end

  describe '#each' do
    
    it 'calls the block passing each item in turn if a block is given' do
      m = flexmock do |mk|
        %w[a b c d].each{|i| mk.should_receive(:test).once.with(i).ordered}
      end
      @combo.each{|i| m.test i}
    end
    
    it 'returns an enumerator whose each method passes each item in turn to the block' do
      m = flexmock do |mk|
        %w[a b c d].each{|i| mk.should_receive(:test).once.with(i).ordered}
      end
      enum = @combo.each
      enum.should be_a(Enumerator)
      enum.each{|i| m.test i}
    end
    
  end
  
end