require 'spec/framework'
require 'spec/common'

require 'tempfile'
require 'fileutils'
require 'set'

require 'lib/ruber/project_dir_scanner'

describe Ruber::ProjectDirScanner do
  
  before do
    @dir = File.join Dir.tmpdir, random_string(10)
    FileUtils.mkdir @dir
    @prj = Ruber::Project.new File.join(@dir, 'xyz.ruprj'), 'XYZ'
    @scanner = Ruber::ProjectDirScanner.new @prj
  end
  
  after do
    FileUtils.rm_rf @dir
  end
  
  it 'derives from Qt::Object' do
    Ruber::ProjectDirScanner.ancestors.should include(Qt::Object)
  end
  
  context 'when created' do
    it 'takes a Ruber::Project as argument' do
      lambda{Ruber::ProjectDirScanner.new(@prj)}.should_not raise_error
    end
  end
  
  context 'whenever the general/project_files project setting changes' do
        
    it 'updates its rules' do
      @scanner.file_in_project?('abc').should be_false
      @prj[:general, :project_files] = {:include => ['abc'], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?('abc').should be_true
    end
    
    it 'emits the :rules_changed signal' do
      mk = flexmock{|m| m.should_receive(:rules_changed).once}
      @scanner.connect(SIGNAL(:rules_changed)){mk.rules_changed}
      @prj[:general, :project_files] = {:include => ['abc'], :exclude => [], :extensions => ['*.rb']}
    end
    
  end
  
  describe '#file_in_project?' do
    
    it 'returns true if the argument matches one of the exact include rules' do
      @prj[:general, :project_files] = {:include => %w[./xyz ./abc ./123], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?(File.join(@prj.project_dir, 'abc')).should be_true
    end
    
    it 'returns true if the argument matches one of the regexp include rules' do
      @prj[:general, :project_files] = {:include => [/a/, /x/], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?(File.join(@prj.project_dir, 'xyz')).should be_true
    end
    
    it 'returns true if the argument matches one of the include extensions' do
      @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb', '*.yaml']}
      @scanner.file_in_project?(File.join(@prj.project_dir, 'abc.rb')).should be_true
    end
    
    it 'returns false if the file isn\'t in the project directory' do
      @prj[:general, :project_files] = {:include => %w[xyz abc 123], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?('/usr/abc').should be_false
    end
    
    it 'treats the argument as a path relative to the project directory if it isn\'t an absolute path' do
      @prj[:general, :project_files] = {:include => %w[xyz abc 123], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?('abc').should be_true
    end
    
    it 'returns false if the file doesn\'t match any include rule' do
      @scanner.file_in_project?(File.join(@prj.project_dir, 'abc.xyz')).should be_false
    end
    
    it 'returns false if the file matches one of the file exclude rules' do
      @prj[:general, :project_files] = {:include => %w[xyz abc 123], :exclude => ['abc', 'AbC.rb'], :extensions => ['*.rb']}
      @scanner.file_in_project?(File.join(@prj.project_dir, 'abc')).should be_false
      @scanner.file_in_project?(File.join(@prj.project_dir, 'AbC.rb')).should be_false
    end
       
    it 'returns false if the file matches one of the exclude regexps' do
      @prj[:general, :project_files] = {:include => [/a/], :exclude => [/a/], :extensions => []}
      @scanner.file_in_project?(File.join(@prj.project_dir, 'abc')).should be_false
    end
    
    it 'it considers the whole path of the file, not just the filename' do
      @prj[:general, :project_files] = {:include => [%r{a/.*}], :exclude => [%r{b/.*}], :extensions => ['*.rb']}
      @scanner.file_in_project?(File.join(@prj.project_dir, 'a', 'xyz')).should be_true
      @scanner.file_in_project?(File.join(@prj.project_dir, 'b', 'xyz.rb')).should be_false
    end
    
    it 'returns nil if the file name ends with a slash' do
      @prj[:general, :project_files] = {:include => [%r{a/.*}], :exclude => [%r{b/.*}], :extensions => ['*.rb']}
      @scanner.file_in_project?('xyz/').should be_nil
    end
    
    it 'returns false if the path represents a remote URL' do
      @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?("http://#{@dir}/abc.xyz.rb").should be_false
    end
    
    it 'works normally if the path represents a local url' do
      @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb']}
      @scanner.file_in_project?("file://#{@dir}/abc.xyz.rb").should be_true
    end
    
  end
  
  describe '#project_files' do
    
    it 'returns a set of all the files belonging to the project' do
      tree = ['f1.rb', 'f2.rb', ['d1', 'f3.rb', 'f4.rb', 'f5.rb'], 'f6', 'f7.xyz']
      base = make_dir_tree tree, @dir 
      base.sub! %r{^#{@dir}/?}, ''
      @prj[:general, :project_files] = {:include => [File.join(base, 'f7.xyz')], :exclude => [File.join(base, 'f2.rb'), File.join(base, 'd1/f4.rb')], :extensions => ['*.rb']}
      res = @scanner.project_files
      res.should be_a Set
      exp = Set.new(%w[f1.rb d1/f3.rb d1/f5.rb f7.xyz].map{|f| File.join @dir, base, f})
      res.should == exp
    end
    
  end
  
  context 'when a new file is created in the project directory' do
    
    #Testing this correctly would need an event loop running, which we can't have
    #inside tests. So we have to manually have the dir watcher emit signals
    
    before do
      @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb']}
    end
    
    context 'and the file belongs to the project' do
    
      it 'emits the file_added signal passing the absolute name of the file' do
        file = File.join @dir, 'test.rb'
        mk = flexmock{|m| m.should_receive(:file_added).once.with File.join(@dir, 'test.rb')}
        @scanner.connect(SIGNAL('file_added(QString)')){|f| mk.file_added f}
        @scanner.instance_variable_get(:@watcher).instance_eval{emit created(file)}
      end
      
    end
    
    context 'and the file doesn\'t belong to the project' do
    
      it 'does nothing' do
        file = File.join @dir, 'test.xyz'
        mk = flexmock{|m| m.should_receive(:file_added).never}
        @scanner.connect(SIGNAL('file_added(QString)')){|f| mk.file_added f}
        @scanner.instance_variable_get(:@watcher).instance_eval{emit created(file)}
      end
      
    end
    
  end
  
  context 'when a new file is removed from the project directory' do
    
    #Testing this correctly would need an event loop running, which we can't have
    #inside tests. So we have to manually have the dir watcher emit signals
    
    before do
      @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb']}
    end
    
    context 'and the file used to belong to the project' do
    
      it 'emits the file_removed signal passing the absolute name of the file' do
        file = File.join @dir, 'test.rb'
        mk = flexmock{|m| m.should_receive(:file_removed).once.with File.join(@dir, 'test.rb')}
        @scanner.connect(SIGNAL('file_removed(QString)')){|f| mk.file_removed f}
        @scanner.instance_variable_get(:@watcher).instance_eval{emit deleted(file)}
      end
      
    end
    
    context 'and the file doesn\'t belong to the project' do
    
      it 'does nothing' do
        file = File.join @dir, 'test.xyz'
        mk = flexmock{|m| m.should_receive(:file_removed).never}
        @scanner.connect(SIGNAL('file_removed(QString)')){|f| mk.file_removed f}
        @scanner.instance_variable_get(:@watcher).instance_eval{emit deleted(file)}
      end
      
    end
    
  end
  
end