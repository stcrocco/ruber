require 'spec/common'

require 'tempfile'

require 'ruber/editor/document'
require 'ruber/document_project'


class DocumentProjectSpecComponentManager < Qt::Object
  extend Forwardable
  signals 'component_loaded(QObject*)', 'unloading_component(QObject*)'
  def_delegators :@data, :[], :<<
  def_delegator :@data, :each, :each_component
  
  def initialize parent = nil
    super
    @data = []
  end
  
end


describe Ruber::DocumentProject::Backend do
  
  it 'inherits Ruber::YamlSettingsBackend' do
    Ruber::DocumentProject::Backend.ancestors.should include(Ruber::YamlSettingsBackend)
  end
  
  describe ', when created' do
    
    it 'accepts a path as argument' do
      lambda{Ruber::DocumentProject::Backend.new __FILE__}.should_not raise_error
    end
    
    it 'uses an empty string as file name if the path is empty' do
      Ruber::DocumentProject::Backend.new('').file.should be_empty
    end
    
    it 'creates an hexdigest of the document name and uses it as the file name' do
      path = "#{ENV['HOME']}/test.rb"
      exp = '0e589e6c62cec2f5c41117ada4a28c52'
      bk = Ruber::DocumentProject::Backend.new path
      File.basename(bk.file).should == exp
    end

    it 'sets the directory of the associated file to $appdir/documents' do
      path = "#{ENV['HOME']}/test.rb"
      exp = File.join(ENV['HOME'], '.kde4/share/apps/test/documents')
      bk = Ruber::DocumentProject::Backend.new path
      File.dirname(bk.file).should == exp
    end
    
    context 'if the associated file is not a valid project file' do
      
      it 'deletes it' do
        path = "#{ENV['HOME']}/test.rb"
        # we create a backend only to retrieve the project file
        backend_file = Ruber::DocumentProject::Backend.new(path).file
        flexmock(File).should_receive(:exist?).once.and_return true
        flexmock(File).should_receive(:read).once.with(backend_file).and_return '{'
        flexmock(FileUtils).should_receive(:rm).once.with(backend_file)
        Ruber::DocumentProject::Backend.new(path)
      end
      
      it 'works as if the file didn\'t exist' do
        path = "#{ENV['HOME']}/test.rb"
        # we create a backend only to retrieve the project file
        backend_file = Ruber::DocumentProject::Backend.new(path).file
        flexmock(File).should_receive(:exist?).once.and_return true
        flexmock(File).should_receive(:read).once.with(backend_file).once.and_return '{'
        flexmock(FileUtils).should_receive(:rm).with(backend_file)
        back = Ruber::DocumentProject::Backend.new(path)
        back.instance_variable_get(:@data).should == {}
      end
      
    end
    
    it 'has no old files' do
      Ruber::DocumentProject::Backend.new( __FILE__).instance_variable_get(:@old_files).should be_empty
    end
    
  end
  
  describe "#write" do
    
    before do
      @dir = File.join Dir.tmpdir, 'ruber_project_document_option_backend'
      FileUtils.mkdir @dir
      @filename = File.join @dir, 'ruber_project_document_option_backend.yaml'
      @doc = File.join(ENV['HOME'],'test.rb')
      @back = Ruber::DocumentProject::Backend.new @doc
      @back.instance_variable_set :@filename, @filename
    end
    
    after do
      FileUtils.rm_rf @dir
    end
    
    it 'raises Errno::ENOENT if the backend isn\'t associated with a file' do
      @back.instance_variable_set :@filename, ''
      lambda do
        @back.write({OS.new(:name => :o1, :group => :G1, :default => 3) => 5})
      end.should raise_error(Errno::ENOENT)
    end
    
    it 'behaves as YamlSettingsBackend#write if there are options to be written' do
      @back.instance_variable_set :@data, {:G1 => {:o1 => 1}}
      @back.write({OS.new(:name => :o1, :group => :G1, :default => 3) => 5})
      (YAML.load File.read(@filename)).should == {:G1 => {:o1 => 5}}
      @back.instance_variable_get(:@data).should == {:G1 => {:o1 => 5}}
    end
    
    it 'doesn\'t write anything to file if the only option is the project name' do
      @back.write( {OS.new(:name => :project_name, :group => :general, :default => nil) => @doc})
      File.exist?(@filename).should be_false
    end
    
    it 'deletes the file when it exists and the only option to write would be the project name' do
      `touch #{@filename}`
      @back.write( {OS.new(:name => :project_name, :group => :general, :default => nil) => @doc})
      File.exist?(@filename).should be_false
    end
    
    it 'deletes all the old files' do
      files = %w[x y].map{|f| File.join @dir, f}
      files.each do |f|
        @back.instance_variable_get(:@old_files) << f
        `touch #{f}`
      end
      @back.write({OS.new(:name => :o1, :group => :G1, :default => 3) => 5})
      files.each{|f| File.exist?(f).should be_false}
    end
    
    it 'clears the list of old files' do
      files = %w[x y].map{|f| File.join @dir, f}
      @back.instance_variable_set(:@old_files, files)
      @back.write({OS.new(:name => :o1, :group => :G1, :default => 3) => 5})
      @back.instance_variable_get(:@old_files).should be_empty
    end
      
  end
  
  describe "#document_path=" do
    
    before do
      @doc = File.join(ENV['HOME'],'test.rb')
      @back = Ruber::DocumentProject::Backend.new @doc
    end
    
    
    it 'sets the project name to the argument' do
      file = File.join(ENV['HOME'],'test1.rb')
      @back.document_path = file
      @back.instance_variable_get(:@data)[:general][:project_name].should == file
    end
    
    it 'changes the file name according to the argument' do
      file = File.join(ENV['HOME'],'test1.rb')
      exp = (Digest::MD5.new << file).hexdigest
      @back.document_path = file
      @back.file.should == File.join(KDE::Global.dirs.locate_local('appdata', 'documents/'), exp)
    end
    
    it 'adds the old file name to the list of old files, unless it was empty' do
      file = File.join(ENV['HOME'],'test1.rb')
      old = @back.file
      @back.document_path = file
      @back.instance_variable_get(:@old_files).should include(old)
      @back = Ruber::DocumentProject::Backend.new ''
      @back.document_path = file
      @back.instance_variable_get(:@old_files).should be_empty
    end
    
  end

end

describe Ruber::DocumentProject do
  
  include FlexMock::ArgumentTypes
  
  before(:all) do
    
    class Ruber::DocumentProject
      
      def connect *args
        super
      end
      
      alias_method :old_connect, :connect
      
      def connect *args, &blk
        @_connections ||= []
        args << blk if blk
        @_connections << args
      end
      
    end
    
  end
  
  after(:all) do
    class Ruber::DocumentProject 
    alias_method :connect, :old_connect
    end
  end
  
  it 'derives from AbstractProject' do
    Ruber::DocumentProject.ancestors.should include(Ruber::AbstractProject)
  end
  
  def create_doc url, path = nil
    doc = Qt::Object.new
    class << doc
      attr_accessor :path, :environment
      attr_reader :url
      
      def has_file?
        !path.empty?
      end
      
      def url= url
        @url = KDE::Url.new url
        @path = @url.empty? ? '' : @url.path
      end
      
    end
    doc.url = url
    doc.path = path if path
    doc
  end
  
  before do
    @app = KDE::Application.instance
    @comp = DocumentProjectSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp).by_default
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(@comp).by_default
    @prj = flexmock(:project_file => '/xyz/abc.ruprj')
    @env = flexmock(:project => @prj)
  end
  
  describe ', when created' do
    
    it 'takes a document and an environment as parameters' do
      doc = create_doc __FILE__
      lambda{Ruber::DocumentProject.new doc, @env}.should_not raise_error
    end
    
    it 'uses the document as parent' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      prj.parent.should equal(doc)
    end
    
    it 'uses Ruber::DocumentProject::Backend as backend' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      prj.instance_variable_get(:@backend).should be_a(Ruber::DocumentProject::Backend)
    end
        
    context 'if the document is associated with a file' do
      
      before do
        @dir = File.dirname(__FILE__)
        @file = File.join @dir, 'x y ^ z'
        @encoded_url = "file://#{@dir}/x%20y%20%5E%20z"
      end
      
      context 'and the environment is associated with a project' do
        
        it 'uses an encoded form of the document\'s URL followed by a colon and the project file as project name' do
          doc = create_doc @file
          prj = Ruber::DocumentProject.new doc, @env
          prj.project_name.should == @encoded_url+':'+@env.project.project_file
        end
        
        it 'passes the project name as argument to the backend' do
          name = "#@encoded_url:#{@env.project.project_file}"
          back = Ruber::DocumentProject::Backend.new name
          doc = create_doc @file
          #twice because korundum executes the code before the initialize body twice,
          #until the call to super
          flexmock(Ruber::DocumentProject::Backend).should_receive(:new).twice.with(name).and_return back
          prj = Ruber::DocumentProject.new doc, @env
        end
      
      end
      
      context 'and the project file is nil' do
        
        before do
          @env = flexmock(:project => nil)
        end
        
        it 'uses an encoded form of the document\'s URL followed by a colon as project name' do
          doc = create_doc @file
          prj = Ruber::DocumentProject.new doc, @env
          prj.project_name.should == @encoded_url+':'
        end
        
        it 'passes the project name as argument to the backend' do
          name = "#@encoded_url:"
          back = Ruber::DocumentProject::Backend.new name
          doc = create_doc @file
          #twice because korundum executes the code before the initialize body twice,
          #until the call to super
          flexmock(Ruber::DocumentProject::Backend).should_receive(:new).twice.with(name).and_return back
          prj = Ruber::DocumentProject.new doc, @env
        end        
        
      end

    end
    
    context 'if the document is not associated with a file' do
      
      it 'uses an empty string as project name' do
        doc = create_doc ''
        prj = Ruber::DocumentProject.new doc, @env
        prj.project_name.should == ''
      end
      
      it 'passes an empty string as argument to the backend' do
        back = Ruber::DocumentProject::Backend.new ''
        doc = create_doc ''
        #twice because korundum executes the code before the initialize body twice,
        #until the call to super
        flexmock(Ruber::DocumentProject::Backend).should_receive(:new).twice.with('').and_return back
        prj = Ruber::DocumentProject.new doc, @env
      end
      
      it 'doesn\'t raise an error if the document isn\'t associated with a file' do
        doc = create_doc ''
        lambda{Ruber::DocumentProject.new doc, @env}.should_not raise_error
      end
      
    end
        
    it 'connects the document\s "document_url_changed(QObject*)" signal with its "change_file()" slot' do
      doc = create_doc File.join(ENV['HOME'], 'test.rb')
      prj = Ruber::DocumentProject.new doc, @env
      prj.instance_variable_get(:@_connections).should include([doc, SIGNAL('document_url_changed(QObject*)'), prj, SLOT(:change_file)])
    end
    
  end
  
  describe "#scope" do
    
    it 'returns :document' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      prj.scope.should == :document
    end
    
  end
  
  describe '#match_rule?' do
    
    it 'returns false if the rule\'s scope doesn\'t include :document' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      o1 = OS.new(:file_extension => [], :scope => [:global], :mimetype => [], :place => [:local])
      flexmock(doc).should_receive(:file_type_match?).with([], []).and_return true
      prj.match_rule?(o1).should be_false
    end
    
    it 'returns false if the document\'s file_type_match? method returns false' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      o1 = OS.new(:file_extension => ['*.rb'], :scope => [:document], :mimetype => [], :place => [:local])
      flexmock(doc).should_receive(:file_type_match?).once.with([], ['*.rb']).and_return false
      prj.match_rule?(o1).should be_false
    end
    
    it 'returns false if the document is associated with a remote file and the rule\'s place entry doesn\'t include :remote' do
      doc = create_doc 'http:///xyz/abc.rb'
      prj = Ruber::DocumentProject.new doc, @env
      o1 = OS.new(:file_extension => [], :scope => [:document], :mimetype => [], :place => [:local])
      flexmock(doc).should_receive(:file_type_match?).with([], []).and_return true
      prj.match_rule?(o1).should be_false
    end
    
    it 'returns false if the document is associated with a local file and the rule\'s place entry doesn\'t include :local' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      o1 = OS.new(:file_extension => [], :scope => [:document], :mimetype => [], :place => [:remote])
      flexmock(doc).should_receive(:file_type_match?).with([], []).and_return true
      prj.match_rule?(o1).should be_false
    end
    
    it 'considers documents not associated with a file as local files' do
      doc = create_doc KDE::Url.new
      prj = Ruber::DocumentProject.new doc, @env
      o1 = OS.new(:file_extension => [], :scope => [:document], :mimetype => [], :place => [:local])
      flexmock(doc).should_receive(:file_type_match?).with([], []).and_return true
      prj.match_rule?(o1).should be_true
    end
    
    it 'returns true if both the mimetype and the file extension of the rule match those of the document and the rule\'s scope include :document' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      o1 = OS.new(:file_extension => ['*.rb'], :scope => [:document], :mimetype => [], :place => [:local])
      flexmock(doc).should_receive(:file_type_match?).once.with([], ['*.rb']).and_return true
      prj.match_rule?(o1).should be_true
      doc = create_doc 'http:///xyz/abc.rb'
      prj = Ruber::DocumentProject.new doc, @env
      o2 = OS.new(:file_extension => ['*.rb'], :scope => [:document], :mimetype => [], :place => [:remote])
      flexmock(doc).should_receive(:file_type_match?).once.with([], ['*.rb']).and_return true
      prj.match_rule?(o2).should be_true
    end
    
  end
  
  describe '#change_file' do
    
    it 'changes the filename associated with the backend' do
      dir = File.join '/', 'home', 'user'
      file = File.join dir, 'test.rb'
      new_file = File.join dir, 'nuovo test.rb'
      enc_url = 'file://' + File.join(dir, 'nuovo%20test.rb')
      doc = create_doc file
      global_project_file = '/abc.ruprj'
      project_file = enc_url + ':' + global_project_file
      @prj = flexmock(:project_file => global_project_file)
      @env = flexmock(:project => @prj)
      prj = Ruber::DocumentProject.new doc, @env
      flexmock(prj.instance_variable_get(:@backend)).should_receive(:document_path=).once.with project_file
      doc.url = new_file
      prj.send :change_file
    end
    
  end
  
  describe "#project_directory" do
    
    before do
      @app = KDE::Application.instance
      @comp = DocumentProjectSpecComponentManager.new
      flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp).by_default
      flexmock(Ruber).should_receive(:[]).with(:app).and_return(@comp).by_default
    end
    
    it 'returns the directory where the document is if the document is associated with a file' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      prj.project_directory.should == File.dirname(__FILE__)
    end
    
    it 'returns the current directory if the document is not associated with a file' do
      doc = create_doc ''
      prj = Ruber::DocumentProject.new doc, @env
      prj.project_directory.should == Dir.pwd
    end
    
  end
  
  describe '#write' do
    
    it 'calls the backend\'s write method' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      flexmock(prj.instance_variable_get(:@backend)).should_receive(:write).once
      prj.write
    end
    
    it 'doesn\'t raise an exception if the document isn\'t associated with a file' do
      doc = create_doc ''
      prj = Ruber::DocumentProject.new doc, @env
      flexmock(prj.instance_variable_get(:@backend)).should_receive(:write).once.and_raise(Errno::ENOENT)
      prj.write
    end
    
    it 'raises an exception if the backend raises Errno::ENOENT but the document is associated with a file' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      flexmock(prj.instance_variable_get(:@backend)).should_receive(:write).once.and_raise(Errno::ENOENT)
      lambda{prj.write}.should raise_error(Errno::ENOENT)
    end
    
  end
  
  describe '#files' do
    
    it 'returns an array containing the path of the file if the document is associated with a file' do
      doc = create_doc __FILE__
      prj = Ruber::DocumentProject.new doc, @env
      prj.files.should == [__FILE__]
    end
    
    it 'returns the encoded URL if the document is associated with a remote file' do
      doc = create_doc 'http://xyz/a bc.rb'
      prj = Ruber::DocumentProject.new doc, @env
      prj.files.should == ['http://xyz/a%20bc.rb']
    end
    
    it 'returns an empty array if the document isn\'t associated with a path' do
      doc = create_doc ''
      prj = Ruber::DocumentProject.new doc, @env
      prj.files.should == []
    end
    
  end
  
  describe '#save' do
    
    context 'if the document is not associated with a file' do
      
      before do
        @doc = create_doc ''
        @prj = Ruber::DocumentProject.new @doc, nil 
      end
      
      it 'does nothing' do
        flexmock(@prj).should_receive(:write).never
        @prj.save
      end
      
      it 'returns true' do
        @prj.save.should == true
      end
      
    end
    
    context 'if the document is associated with a file' do
      
      it 'works as AbstractProject#save' do
        doc = create_doc __FILE__
        prj = Ruber::DocumentProject.new doc, @env
        flexmock(prj).should_receive(:write).once
        prj.save
      end
      
    end
    
  end
  
end