require 'spec/common'

require 'tempfile'
require 'fileutils'
require 'flexmock'
require 'forwardable'

require 'ruber/projects/project_files_list'
require 'ruber/project'


class SimpleProject < Qt::Object
  signals 'option_changed(QString, QString)'
end

describe 'Ruber::ProjectFilesList' do
  
  before do
    @app = Qt::Object.new
    @comp = Qt::Object.new do
      class << self
        extend Forwardable
        def_delegators :@data, :[], :<<
        def_delegator :@data, :each, :each_component
      end
      @data = []
    end
    @projects = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@app).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp).by_default
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    dir = File.dirname __FILE__
    @prj = Ruber::Project.new File.join(dir, 'test.ruprj'), 'Test'
    @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => [], :exclude => [], :extensions => []} }))
    @l = Ruber::ProjectFilesList.new @prj
    @prj.add_extension :file_lister, @l
  end
  
  it 'should be an Enumerable' do
    Ruber::ProjectFilesList.ancestors.should include(Enumerable)
  end
  
  it 'should not be up to date when created' do
    @l.should_not be_up_to_date
  end
  
  it 'should not attempt to scan the project when created' do
    flexmock(Find).should_receive(:find).never
    l = Ruber::ProjectFilesList.new @prj
  end
  
  it 'should mark the list as not up to date when the project_files option changes' do
    @prj.add_option(OS.new({:group => :general, :name => :xyz, :default => 3}))
    @prj[:general, :project_files][:extensions] = ['*.rb']
    @l.instance_variable_set :@up_to_date, true
    @prj.instance_eval{emit option_changed('general', 'xyz')}
    @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => %w[*.rb *.ui]}
    @l.should_not  be_up_to_date
  end
  
  describe ', when a file or directory changes' do
    
    before do
      @files = YAML.load('[f1.rb, f1.yaml, README, COPYING, [d2, f21.rb, f22.rb, f21.yaml, f22.yaml, CHANGELOG], [d3, f31.rb, f32.rb]]')
      @dir = make_dir_tree @files
      @prj = Ruber::Project.new File.join(@dir, 'test.ruprj'), 'Test'
      @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => [], :exclude => [], :extensions => []} }))
      @list = Ruber::ProjectFilesList.new @prj
      @prj.add_extension :file_lister, @list
    end
    
    it 'should mark itself as not up to date' do
      @list.instance_variable_set :@up_to_date, true
      w = @list.instance_variable_get :@watcher
      dir = @prj.project_directory
      w.instance_eval{emit dirty(dir)}
      @list.instance_variable_get(:@up_to_date).should be_false
    end
    
    it 'should stop the watcher' do
      w = @list.instance_variable_get :@watcher
      flexmock(w).should_receive(:stop_scan).once
      dir = @prj.project_directory
      w.instance_eval{emit dirty(dir)}
    end
    
  end
  
  describe Ruber::ProjectFilesList, '#refresh' do
    
    before do
      dir = File.dirname __FILE__
      @prj = Ruber::Project.new File.join(dir, 'test.ruprj'), 'Test'
      @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => [], :exclude => [], :extensions => []} }))
      @list = Ruber::ProjectFilesList.new @prj
      @prj.add_extension :file_lister, @list
    end
    
    it 'should call the scan_project method' do
      flexmock(@list).should_receive(:scan_project).once
      @list.refresh
    end
    
    it 'should set the file list as up to date' do
      flexmock(@list).should_receive(:scan_project)
      @list.refresh
      @list.should be_up_to_date
    end
    
    it 'should restart the watcher' do
      flexmock(@list).should_receive(:scan_project)
      w = @list.instance_variable_get(:@watcher)
      flexmock(w).should_receive(:start_scan).once
      @list.refresh
    end
    
  end
  
  describe 'Ruber::ProjectFilesList#project_files' do
    
    before do
      @files = YAML.load('[f1.rb, f1.yaml, README, COPYING, [d2, f21.rb, f22.rb, f21.yaml, f22.yaml, CHANGELOG], [d3, f31.rb, f32.rb]]')
      @dir = make_dir_tree @files
      @prj = Ruber::Project.new File.join(@dir, 'test.ruprj'), 'Test'
      @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => [], :exclude => [], :extensions => []} }))
      @list = Ruber::ProjectFilesList.new @prj
      @prj.add_extension :file_lister, @list
    end
    
    after do
      FileUtils.rm_f @dir
    end
    
    it 'updates the cache if it\'s not up to date' do
      @list.instance_variable_set :@up_to_date, false
      flexmock(@list).should_receive(:refresh).once
      @list.project_files
    end
    
    it 'doesn\'t update the cache if it\'s already up to date' do
      @list.instance_variable_set :@up_to_date, true
      flexmock(@list).should_receive(:refresh).never
      @list.project_files
    end
    
    it 'returns an array containing all the files corresponding to include rules of type path unless they also correspond to an exclude rule of type path' do
      @prj[:general, :project_files] = {:include => ['README', 'COPYING', 'f1.rb', 'd2/CHANGELOG', 'd2/f21.rb'], :exclude => ['COPYING', 'd2/f21.rb'], :extensions => []}
      @list.project_files(false).should =~ %w[README f1.rb d2/CHANGELOG]
    end
    
    it 'doesn\'t include in the returned array files which don\'t exist' do
      @prj[:general, :project_files] = {:include => ['README1', 'COPYING', 'f1.rb', 'd2/CHANGELOG', 'd2/f211.rb'], :exclude => ['COPYING'], :extensions => []}
      @list.project_files(false).should =~ %w[f1.rb d2/CHANGELOG]
    end
    
    it 'skips include rules of type path corresponding to directories' do
      @prj[:general, :project_files] = {:include => ['README', 'COPYING', 'f1.rb', 'd2/CHANGELOG', 'd2/f21.rb', 'd3'], :exclude => ['COPYING', 'd2/f21.rb'], :extensions => []}
      @list.project_files(false).should =~ %w[README f1.rb d2/CHANGELOG]
    end
    
    it 'includes all the files in the project directory which correspond to one of the extensions in the returned array, unless they match one of the exclude rule' do
      @prj[:general, :project_files] = {:include => [], :exclude => ['COPYING', 'd2/f21.rb'], :extensions => %w[*.rb]}
      @list.project_files(false).should =~ %w[f1.rb d2/f22.rb d3/f31.rb d3/f32.rb]
    end
    
    it 'includes all the files in the project directory which match one of the include rules of type regexp and don\'t match any exclude rule' do
      @prj[:general, :project_files] = {:include => [%r{d3/.*}, %r{.*\.yaml}], :exclude => [%r{d3/.*2.*}, %r{.*1.*\.rb}], :extensions => []}
      @list.project_files(false).should =~ %w[d2/f22.yaml f1.yaml d2/f21.yaml]
    end
    
    it 'doesn\'t include duplicate elements' do
      @prj[:general, :project_files] = {:include => [%r{d2/.*}, 'f1.rb'], :exclude => [], :extensions => ['*.rb']}
      @list.project_files(false).should =~ %w[f1.rb d2/f21.rb d2/f22.rb d2/f21.yaml d2/f22.yaml d2/CHANGELOG d3/f31.rb d3/f32.rb]
    end
    
    it 'returns a deep copy of the cache object' do
      @prj[:general, :project_files] = {:include => [%r{d2/.*}, 'f1.rb'], :exclude => [], :extensions => ['*.rb']}
      old_cache = @list.instance_variable_get(:@project_files).deep_copy
      res = @list.project_files(false)
      res.should == old_cache
      res << 'x'
      @list.instance_variable_get(:@project_files).should == old_cache
    end
    
    it 'returns full paths if the argument is true' do
      @prj[:general, :project_files] = {:include => [%r{d2/.*}, 'f1.rb'], :exclude => [], :extensions => ['*.rb']}
      @list.project_files(true).should =~ %w[f1.rb d2/f21.rb d2/f22.rb d2/f21.yaml d2/f22.yaml d2/CHANGELOG d3/f31.rb d3/f32.rb].map{|i| File.join @dir, i}
    end
    
    it 'returns the correct list if a file or directory is added or deleted after the file watcher has been created' do
      @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb']}
      # Experiments show that KDE::DirWatch needs an event loop to work. Since we don't have one running, we'll have to make it emit the 'dirty' signal manually
      watcher = @list.instance_variable_get(:@watcher)
      `touch #@dir/f2.rb`
      watcher.instance_eval{emit dirty( @dir)}
      `touch #@dir/d2/f23.rb`
      watcher.instance_eval{emit dirty( @dir)}
      @list.project_files(false).should include('f2.rb')
      @list.project_files(false).should include('d2/f23.rb')
      FileUtils.mkdir("#@dir/d4")
      watcher.instance_eval{emit dirty( @dir)}
      `touch #@dir/d4/f41.rb`
      watcher.instance_eval{emit dirty( @dir)}
      `touch #@dir/d4/f42.rb`
      watcher.instance_eval{emit dirty( @dir)}
      @list.project_files(false).should include('d4/f41.rb')
      @list.project_files(false).should include('d4/f42.rb')
      FileUtils.rm_rf "#@dir/d2"
      watcher.instance_eval{emit dirty( @dir)}
      @list.project_files(false).should_not include("#@dir/d2/f21.rb")
      @list.project_files(false).should_not include("#@dir/d2/f22.rb")
      FileUtils.rm "#@dir/f1.rb"
      watcher.instance_eval{emit dirty( @dir)}
      @list.project_files(false).should_not include("f1.rb")
    end
   
  end
  
  describe 'Ruber::ProjectFilesList#each' do
    
    before do
      @files = YAML.load('[f1.rb, f1.yaml, README, COPYING, [d2, f21.rb, f22.rb, f21.yaml, f22.yaml, CHANGELOG], [d3, f31.rb, f32.rb]]')
      @dir = make_dir_tree @files
      @prj = Ruber::Project.new File.join(@dir, 'test.ruprj'), 'Test'
      @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => %w[README f1.yaml], :exclude => %w[d2/f22.rb], :extensions => %w[*.rb]} }))
      @list = Ruber::ProjectFilesList.new @prj
      @prj.add_extension :file_lister, @list
    end
    
    it 'should update the cache if it\'s not up to date and a block is given' do
      @list.instance_variable_set :@up_to_date, false
      flexmock(@list).should_receive(:refresh).once
      @list.each{}
    end
    
    it 'should not update the cache if it\'s already up to date and a block is given' do
      @list.instance_variable_set :@up_to_date, true
      flexmock(@list).should_receive(:refresh).never
      @list.each{}
    end
    
    it 'should call the associated block passing the full file name of each project file if called with a block and the argument is true' do
      exp = %w[f1.rb f1.yaml README d2/f21.rb d3/f31.rb d3/f32.rb].map{|f| File.join @dir, f}
      m = flexmock do |mk| 
        exp.each{|f| mk.should_receive(:test).once.with(f)}
      end
      @list.each(true){|f| m.test f}
    end
    
    it 'should call the associated block passing the file name of each project file relative to the project directory if called with a block and the argument is false' do
      exp = %w[f1.rb f1.yaml README d2/f21.rb d3/f31.rb d3/f32.rb]
      m = flexmock do |mk| 
        exp.each{|f| mk.should_receive(:test).once.with(f)}
      end
      @list.each(false){|f| m.test f}
    end
    
    it 'should return an enumerator which yields the full file name of each project file if called without a block and the argument is true' do
      enum = @list.each(true)
      enum.should be_a(Enumerable)
      exp = %w[f1.rb f1.yaml README d2/f21.rb d3/f31.rb d3/f32.rb].map{|f| File.join @dir, f}
      m = flexmock do |mk| 
        exp.each{|f| mk.should_receive(:test).once.with(f)}
      end
      enum.each{|f| m.test f}
    end
    
    it 'should return an enumerator which yields the file name of each project file relative to the project directory if called without a block and the argument is false' do
      enum = @list.each(false)
      enum.should be_a(Enumerable)
      exp = %w[f1.rb f1.yaml README d2/f21.rb d3/f31.rb d3/f32.rb]
      m = flexmock do |mk| 
        exp.each{|f| mk.should_receive(:test).once.with(f)}
      end
      enum.each{|f| m.test f}
    end
    
    it 'should never update the cache if no block is given' do
      @list.instance_variable_set :@up_to_date, false
      flexmock(@list).should_receive(:refresh).never
      @list.each
      @list.instance_variable_set :@up_to_date, true
      @list.each
    end
    
  end
  
  describe 'Ruber::ProjectFilesList#rel' do
    
    before do
      @files = YAML.load('[f1.rb, f1.yaml, README, COPYING, [d2, f21.rb, f22.rb, f21.yaml, f22.yaml, CHANGELOG], [d3, f31.rb, f32.rb]]')
      @dir = make_dir_tree @files
      @prj = Ruber::Project.new File.join(@dir, 'test.ruprj'), 'Test'
      @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => %w[README f1.yaml], :exclude => %w[d2/f22.rb], :extensions => %w[*.rb]} }))
      @list = Ruber::ProjectFilesList.new @prj
      @prj.add_extension :file_lister, @list
    end
    
    it 'should work as the each method with no block and a false argument' do
      enum = @list.rel
      enum.should be_a(Enumerable)
      exp = %w[f1.rb f1.yaml README d2/f21.rb d3/f31.rb d3/f32.rb]
      m = flexmock do |mk| 
        exp.each{|f| mk.should_receive(:test).once.with(f)}
      end
      enum.each{|f| m.test f}
    end
    
  end
  
  describe 'Ruber::ProjectFilesList#abs' do
    
    before do
      @files = YAML.load('[f1.rb, f1.yaml, README, COPYING, [d2, f21.rb, f22.rb, f21.yaml, f22.yaml, CHANGELOG], [d3, f31.rb, f32.rb]]')
      @dir = make_dir_tree @files
      @prj = Ruber::Project.new File.join(@dir, 'test.ruprj'), 'Test'
      @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => %w[README f1.yaml], :exclude => %w[d2/f22.rb], :extensions => %w[*.rb]} }))
      @list = Ruber::ProjectFilesList.new @prj
      @prj.add_extension :file_lister, @list
    end
    
    it 'should work as the each method with no block and a true argument' do
      enum = @list.abs
      enum.should be_a(Enumerable)
      exp = %w[f1.rb f1.yaml README d2/f21.rb d3/f31.rb d3/f32.rb].map{|f| File.join @dir, f}
      m = flexmock do |mk| 
        exp.each{|f| mk.should_receive(:test).once.with(f)}
      end
      enum.each{|f| m.test f}
    end
    
    
  end
  
  describe Ruber::ProjectFilesList do
    
    describe '#file_in_project?' do
      
      before do
        @dir = File.dirname __FILE__
        @prj = Ruber::Project.new File.join(@dir, 'test.ruprj'), 'Test'
        @prj.add_option(OS.new({:group => :general, :name => :project_files, :default => {:include => %w[], :exclude => %w[], :extensions => []} }))
        @list = Ruber::ProjectFilesList.new @prj
        @prj.add_extension :file_lister, @list
      end
      
      it 'returns true if the argument matches one of the exact include rules' do
        @prj[:general, :project_files] = {:include => %w[./xyz ./abc ./123], :exclude => [], :extensions => ['*.rb']}
        @list.file_in_project?(File.join(@prj.project_dir, 'abc')).should be_true
      end
      
      it 'returns true if the argument matches one of the regexp include rules' do
        @prj[:general, :project_files] = {:include => [/a/, /x/], :exclude => [], :extensions => ['*.rb']}
        @list.file_in_project?(File.join(@prj.project_dir, 'xyz')).should be_true
      end
      
      it 'returns true if the argument matches one of the include extensions' do
        @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb', '*.yaml']}
        @list.file_in_project?(File.join(@prj.project_dir, 'abc.rb')).should be_true
      end
      
      it 'returns false if the file isn\'t in the project directory' do
        @prj[:general, :project_files] = {:include => %w[xyz abc 123], :exclude => [], :extensions => ['*.rb']}
        @list.file_in_project?('/usr/abc').should be_false
      end
      
      it 'treats the argument as a path relative to the project directory if it isn\'t an absolute path' do
        @prj[:general, :project_files] = {:include => %w[xyz abc 123], :exclude => [], :extensions => ['*.rb']}
        @list.file_in_project?('abc').should be_true
      end
      
      it 'returns false if the file doesn\'t match any include rule' do
        @list.file_in_project?(File.join(@prj.project_dir, 'abc.rb')).should be_false
      end
      
      it 'returns false if the file matches one of the file exclude rules' do
        @prj[:general, :project_files] = {:include => %w[xyz abc 123], :exclude => ['abc'], :extensions => ['*.rb']}
        @list.file_in_project?(File.join(@prj.project_dir, 'abc')).should be_false
      end
      
      it 'returns false if the file matches one of the exclude regexps' do
        @prj[:general, :project_files] = {:include => [/a/], :exclude => [/a/], :extensions => []}
        @list.file_in_project?(File.join(@prj.project_dir, 'abc')).should be_false
      end
      
      it 'it considers the whole path of the file, not just the filename' do
        @prj[:general, :project_files] = {:include => [%r{a/.*}], :exclude => [%r{b/.*}], :extensions => ['*.rb']}
        @list.file_in_project?(File.join(@prj.project_dir, 'a', 'xyz')).should be_true
        @list.file_in_project?(File.join(@prj.project_dir, 'b', 'xyz.rb')).should be_false
      end
      
      it 'returns nil if the file name ends with a slash' do
        @prj[:general, :project_files] = {:include => [%r{a/.*}], :exclude => [%r{b/.*}], :extensions => ['*.rb']}
        @list.file_in_project?('xyz/').should be_nil
      end
      
      it 'returns false if the path represents a remote URL' do
        @prj[:general, :project_files] = {:include => [], :exclude => [], :extensions => ['*.rb']}
        @list.file_in_project?('http://abc.xyz.rb').should be_false
      end
      
    end
    
  end
  
end