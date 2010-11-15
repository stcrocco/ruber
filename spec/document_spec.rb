require 'spec/common'

require 'tempfile'
require 'fileutils'
require 'flexmock/argument_types'
require 'facets/string/camelcase'

require 'ruber/editor/document'

class DocumentSpecComponentManager < Qt::Object
  extend Forwardable
  signals 'component_loaded(QObject*)', 'unloading_component(QObject*)'
  def_delegators :@data, :[], :<<
  def_delegator :@data, :each, :each_component
  
  def initialize parent = nil
    super
    @data = []
  end
  
end

describe Ruber::Document do
  
  include FlexMock::ArgumentTypes
  
  before do
    @app = KDE::Application.instance
    @w = Qt::Widget.new
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp)
    @doc = Ruber::Document.new @app
  end
  
  describe ', when created' do

    it 'loads a KTextEditor::Document' do
      @doc.instance_variable_get(:@doc).should be_instance_of(KTextEditor::Document)
    end

    it 'has an annotation model' do
      @doc.interface('annotation_interface').annotation_model.should_not be_nil
    end
    
    it 'doesn\'t have a view' do
      @doc.view.should be_nil
    end

    it 'opens a given file if new is called with a string or KDE::Url second argument' do
      doc = Ruber::Document.new @app, __FILE__
      doc.text.should == File.read(__FILE__)
      doc.url.path.should == __FILE__
      doc = Ruber::Document.new @app, KDE::Url.from_path(__FILE__)
      doc.text.should == File.read(__FILE__)
      doc.url.path.should == __FILE__
    end
    
    it 'creates a document project for itself, after opening the file (if given)' do
      doc = Ruber::Document.new @app
      prj = doc.instance_variable_get(:@project)
      prj.should be_a(Ruber::DocumentProject)
      prj.project_name.should be_empty
      doc = Ruber::Document.new @app, __FILE__
      prj = doc.instance_variable_get(:@project)
      prj.should be_a(Ruber::DocumentProject)
      prj.project_name.should == KDE::Url.new(__FILE__).to_encoded.to_s
    end
    
    it 'isn\'t active' do
      doc = Ruber::Document.new @app, __FILE__
      doc.should_not be_active
    end
    
  end
  
  describe "#has_file?" do
    
    context 'when called with :local' do
      
      it 'returns true if the document is associated with a local file' do
        doc = Ruber::Document.new nil, __FILE__
        doc.should have_file(:local)
      end
      
      it 'returns false if the document is associated with a remote file' do
        doc = Ruber::Document.new nil, KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/ruber.gemspec')
        doc.should_not have_file(:local)
      end
      
      it 'returns false if the document isn\'t associated with any file' do
        doc = Ruber::Document.new
        doc.should_not have_file(:local)
      end
      
    end
    
    context 'when called with :remote' do
      
      it 'returns false if the document is associated with a local file' do
        doc = Ruber::Document.new nil, __FILE__
        doc.should_not have_file(:remote)
      end
      
      it 'returns true if the document is associated with a remote file' do
        doc = Ruber::Document.new nil, KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/ruber.gemspec')
        doc.should have_file(:remote)
      end
      
      it 'returns false if the document isn\'t associated with any file' do
        doc = Ruber::Document.new
        doc.should_not have_file(:remote)
      end
      
    end
    
    context 'when called with :any or no arguments' do
      
      it 'returns true if the document is associated with a local file' do
        doc = Ruber::Document.new nil, __FILE__
        doc.should have_file(:any)
        doc.should have_file
      end
      
      it 'returns true if the document is associated with a remote file' do
        doc = Ruber::Document.new nil, KDE::Url.new('http://github.com/stcrocco/ruber/raw/master/ruber.gemspec')
        doc.should have_file(:any)
        doc.should have_file
      end
      
      it 'returns false if the document isn\'t associated with any file' do
        doc = Ruber::Document.new
        doc.should_not have_file(:any)
        doc.should_not have_file
      end
      
    end
    
  end
  
  describe '#own_project' do
  
    it 'returns the DocumentProject associated with the document' do
      doc = Ruber::Document.new @app, __FILE__
      doc.own_project.project_name.should == __FILE__
    end

  end
  
  describe '#project' do
    
    before do
      @list = flexmock
      @prj = flexmock(:project_files => @list)
      @projects = flexmock{|m| m.should_receive(:current).and_return(@prj).by_default}
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects)
      @doc = Ruber::Document.new @app, __FILE__
    end
    
    it 'returns the current project if one exists and the document belongs to it' do
      flexmock(@list).should_receive(:file_in_project?).with("file://#{__FILE__}").and_return true
      @doc.project.should == @prj
    end
    
    it 'returns the document project if the file associated with the document doesn\'t belong to the current project' do
      flexmock(@list).should_receive(:file_in_project?).with("file://#{__FILE__}").and_return false
      @doc.project.should be_a(Ruber::DocumentProject)
    end
    
    it 'returns the document project if the document isn\'t associated with a file' do
      @doc = Ruber::Document.new @app
      @doc.project.should be_a(Ruber::DocumentProject)
    end
    
    it 'returns the document project if there isn\'t a project open' do
      @projects.should_receive(:current).and_return nil
      @doc.project.should be_a(Ruber::DocumentProject)
    end
    
  end
  
  describe '#save' do
    
    it 'calls document_save_as if the document has no filename' do
      flexmock(@doc).should_receive(:document_save_as).once.and_return(true)
      flexmock(@doc).should_receive(:document_save_as).once.and_return(false)
      @doc.save.should be_true
      @doc.save.should be_false
      #     tmp_file = File.join Dir.tmpdir, "ruber_document_test" + 3.times.map{rand(10)}.join.to_s
      #     flexmock(KDE::FileDialog).should_receive(:get_save_file_name).times(2).and_return(nil, tmp_file)
      #     @doc.text = 'test'
      #     @doc.save.should be_false
      #     @doc.save.should be_true
      #     File.exists?(tmp_file).should be_true
      #     File.read(tmp_file).should == 'test'
      #     FileUtils.rm tmp_file
    end
    
    describe ', when the document is associated with a file' do
      
      it 'calls the document_save_as method if the document is read only' do
        Tempfile.open('ruber_document_test') do |f|
          f.write 'test'
          f.flush
          doc = Ruber::Document.new nil, f.path
          flexmock(doc.send :internal).should_receive(:is_read_write).once.and_return false
          flexmock(doc).should_receive(:document_save_as).once
          doc.text += ' added'
          doc.save
        end
      end
      
      it 'calls its own project\'s save method' do
        Tempfile.open('ruber_document_test') do |f|
          f.write 'test'
          f.flush
          doc = Ruber::Document.new nil, f.path
          flexmock(doc.own_project).should_receive(:save).once
          doc.text += ' added'
          doc.save
        end
      end
      
      it 'saves the document if the document is associated with a file' do
        Tempfile.open('ruber_document_test') do |f|
          f.write 'test'
          f.flush
          doc = Ruber::Document.new nil, f.path
          doc.text += ' added'
          doc.save.should be_true
          File.read( f.path ).should == 'test added'
        end
      end
      
    end

  end
  
  it 'should allow to create a view if none exists' do
    @doc.create_view(Qt::Widget.new).should_not be_nil
  end

  it 'should not allow to create a view if one already exists' do
    @doc.create_view(Qt::Widget.new)
    lambda{@doc.create_view(Qt::Widget.new)}.should raise_error(RuntimeError)
  end

  it 'should allow to get and change the text' do
    txt="test text"
    lambda{@doc.text="test text"}.should_not raise_error
    @doc.text.should == txt
  end

  it 'should return the mimetype of the document' do
    @doc.mime_type.should == 'text/plain'
    @doc.open_url KDE::Url.from_path(__FILE__)
    @doc.mime_type.should == 'application/x-ruby'
  end

  it 'should return the view attached to it (or nil) with the view method' do
    @doc.view.should be_nil
    @doc.create_view nil
    @doc.view.should be_instance_of Ruber::EditorView
    @doc.view.close
  end

  it 'should emit the "modified_changed(QObject*, bool)" signal when the modified status changes' do
    m = flexmock
    m.should_receive(:test).ordered.with(true, @doc)
    m.should_receive(:test).ordered.with(false, @doc)
    @doc.connect(SIGNAL('modified_changed(bool, QObject*)')){|mod, o| m.test mod, o}
    d = @doc.instance_variable_get(:@doc)
    d.instance_eval do
      self.modified = true
      emit modifiedChanged(self)
      self.modified = false
      emit modifiedChanged(self)
    end

  end

  it 'should emit the "document_name_changed(QString, QObject*)" signal when the document name changes' do
    m = flexmock
    m.should_receive(:document_name_changed).twice
    @doc.connect(SIGNAL('document_name_changed(QString, QObject*)')) do |str, obj|
      obj.should == @doc
      str.should == @doc.document_name
      m.document_name_changed
    end
    @doc.open_url KDE::Url.from_path( __FILE__)
  end

  it 'should return the path of the file usgin the "path" method or an empty string if the document is not associated with a file' do
    @doc.path.should == ''
    @doc.open_url KDE::Url.from_path( __FILE__ )
    @doc.path.should == __FILE__
  end

  it 'should return an empty string if the document is empty' do
    @doc.text.should_not be_nil
  end

  it 'should tell whether it\'s a pristine document' do
    @doc.should be_pristine
    @doc.text = "a"
    @doc.should_not be_pristine
    projects = flexmock(:current => nil)
    config = flexmock{|m| m.should_receive(:[]).with(:general, :default_script_directory).and_return ENV['HOME']}
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(projects)
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(config)
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(Qt::Widget.new)
    Tempfile.open('ruber_document_test') do |f|
      res = OpenStruct.new(:file_names => [f.path], :encoding => @doc.encoding)
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).and_return(res)
      flexmock(KDE::MessageBox).should_receive(:warning_continue_cancel).and_return KDE::MessageBox::Continue
      @doc.save
      @doc.should_not be_pristine
    end
    Ruber::Document.new(nil, __FILE__).should_not be_pristine
  end

  ["text_changed(QObject*)", "about_to_close(QObject*)", 'about_to_close(QObject*)', 
'about_to_reload(QObject*)', 'document_url_changed(QObject*)'].each do |sig|
    sig_name = sig[0...sig.index('(')]
    o_sig_name = sig_name.camelcase(false)
    o_sig = sig.camelcase(false).sub('(QObject*','(KTextEditor::Document*')
    it "should emit the \"#{sig}\" signal in response to the underlying KTextEditor::Document \"#{o_sig}\" signal" do
    m = flexmock
    m.should_receive( sig_name.to_sym).once.with(@doc.object_id)
    @doc.connect(SIGNAL(sig)){|o| m.send(sig_name.to_sym, o.object_id)}
    d = @doc.instance_variable_get(:@doc)
    d.instance_eval "emit #{o_sig_name}( self)"
    end
  end

  it 'should emit the "mode_changed(QObject*)" signal in response to the underlying KTextEditor::Document "modeChanged(KTextEditor::Document)" signal' do
    m = flexmock
    m.should_receive( :mode_changed).once.with(@doc.object_id)
    @doc.connect(SIGNAL('mode_changed(QObject*)')){|o| m.mode_changed o.object_id}
    @doc.mode = "Ruby"
  end

  it 'should emit the "highlighting_mode_changed(QObject*)" signal in response to the underlying KTextEditor::Document "highlightingModeChanged(KTextEditor::Document)" signal' do
    m = flexmock
    m.should_receive( :h_mode_changed).once.with(@doc.object_id)
    @doc.connect(SIGNAL('highlighting_mode_changed(QObject*)')){|o| m.h_mode_changed o.object_id}
    @doc.highlighting_mode = "Ruby"
  end

  it 'should emit the "text_modified(KTextEditor::Range, KTextEditor::Range, QObject*)" signal in response to the underlying KTextEditor::Document "textChanged(KTextEditor::Document*, KTextEditor::Range, KTextEditor::Range)" signal' do
    m = flexmock
    m.should_receive( :text_modified).once.with(@doc.object_id)
    @doc.connect(SIGNAL('text_modified(KTextEditor::Range, KTextEditor::Range, QObject*)')){|_r1, _r2, o| m.text_modified o.object_id}
    d = @doc.instance_variable_get(:@doc)
    d.instance_eval{emit textChanged(self, KTextEditor::Range.new(0,0,0,5), KTextEditor::Range.new(0,0,1,1))}
  end

  it 'should emit the "text_inserted(KTextEditor::Range, QObject*)" signal in response to the underlying KTextEditor::Document "textInserted(KTextEditor::Document*, KTextEditor::Range)" signal' do
    m = flexmock
    m.should_receive( :text_inserted).once.with(@doc.object_id)
    @doc.connect(SIGNAL('text_inserted(KTextEditor::Range, QObject*)')){|_, o| m.text_inserted o.object_id}
    d = @doc.instance_variable_get(:@doc)
    d.instance_eval{emit textInserted(self, KTextEditor::Range.new(0,0,0,5))}
  end

  it 'should emit the "text_removed(KTextEditor::Range, QObject*)" signal in response to the underlying KTextEditor::Document "textRemoved(KTextEditor::Document*, KTextEditor::Range)" signal' do
    m = flexmock
    m.should_receive( :text_removed).once.with(@doc.object_id)
    @doc.connect(SIGNAL('text_removed(KTextEditor::Range, QObject*)')){|_, o| m.text_removed o.object_id}
    d = @doc.instance_variable_get(:@doc)
    d.instance_eval{emit textRemoved(self, KTextEditor::Range.new(0,0,0,5))}
  end

  it 'emits the "view_created(QObject*, QObject*)" signal after creating a view' do
    m = flexmock
    m.should_receive( :view_created).once.with(@doc.object_id)
    @doc.connect(SIGNAL('view_created(QObject*, QObject*)'))do |_, o| 
      m.view_created o.object_id
      @doc.view.should be_a(Ruber::EditorView)
    end
    @doc.create_view nil
    @doc.view.close
  end

  it 'should return nil with the view method when a view has been closed' do
    view = @doc.create_view
    view.close
    @doc.view.should be_nil
  end

  it 'should return true when close_url succeeds' do
    doc = Ruber::Document.new nil, __FILE__
    doc.close_url(false).should be_true
  end
  
  it 'should call the update_project method of each component, passing it its project, when the url of the document changes, but before emitting the document_url_changed signal' do
    3.times{@comp << flexmock{|m| m.should_receive(:update_project).once.with(Ruber::DocumentProject).globally.ordered} }
    url_changed_rec = flexmock{|m| m.should_receive(:url_changed).once.globally.ordered}
    internal = @doc.send :internal
    @doc.connect(SIGNAL('document_url_changed(QObject*)')){url_changed_rec.url_changed}
    internal.instance_eval{emit documentUrlChanged(self)}
  end

  after do
    @doc.view.close if @doc.view
    @doc.instance_variable_get(:@doc).closeUrl false
    @doc.dispose
  end

end

describe 'Ruber::Document#close' do
  
  before do
    @app = KDE::Application.instance
    @w = Qt::Widget.new
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp)
    @doc = Ruber::Document.new @app
    flexmock(@doc.instance_variable_get(:@project)).should_receive(:save).by_default
  end
  
  it 'should return immediately if ask is true and query_close returns false' do
    doc = Ruber::Document.new nil, __FILE__
    exp = doc.object_id
    m = flexmock('test'){|mk| mk.should_receive(:document_closing).never}
    doc.connect(SIGNAL('closing(QObject*)')){|d| m.document_closing d.object_id}
    flexmock(doc).should_receive(:query_close).and_return false
    doc.close
  end
  
  it 'calls the save method of the project after emitting the "closing" signal' do
    @doc = Ruber::Document.new @app, __FILE__
    m = flexmock{|mk| mk.should_receive(:document_closing).once.globally.ordered}
    @doc.connect(SIGNAL('closing(QObject*)')){m.document_closing}
    flexmock(@doc.instance_variable_get(:@project)).should_receive(:save).once.globally.ordered
    @doc.close
  end
  
  it 'doesn\'t call the save method of the project if the document isn\'t associated with a file' do
    flexmock(@doc.instance_variable_get(:@project)).should_receive(:save).never
    @doc.close
  end
  
  it 'should call the "close_url", if closing is confirmed' do
    doc = Ruber::Document.new nil, __FILE__
    flexmock(doc).should_receive(:close_url).once.with(false)
    doc.close
    doc = Ruber::Document.new nil, __FILE__
    flexmock(doc).should_receive(:close_url).once.with(false)
    doc.close false
  end
  
  it 'should emit the "closing(QObject*)" signal if closing is confirmed' do
    doc = Ruber::Document.new nil, __FILE__
    exp = doc.object_id
    m = flexmock('test'){|mk| mk.should_receive(:document_closing).once.with(exp)}
    flexmock(doc).should_receive(:close_url).and_return true
    doc.connect(SIGNAL('closing(QObject*)')){|d| m.document_closing d.object_id}
    flexmock(doc).should_receive(:query_close).and_return true
    doc.close
    doc = Ruber::Document.new nil, __FILE__
    exp1 = doc.object_id
    m.should_receive(:document_closing).with(exp1).once
    flexmock(doc).should_receive(:query_close)
    doc.connect(SIGNAL('closing(QObject*)')){|d| m.document_closing d.object_id}
    doc.close false
  end
  
  it 'should close the view, if there\'s one, after emitting the closing signal, if closing is confirmed' do
    doc = Ruber::Document.new nil, __FILE__
    v = doc.create_view
    exp = doc.object_id
    m = flexmock('test'){|mk| mk.should_receive(:document_closing).once.with(exp).globally.ordered}
    flexmock(v).should_receive(:close).once.globally.ordered
    flexmock(doc).should_receive(:close_url).and_return true
    doc.connect(SIGNAL('closing(QObject*)')){|d| m.document_closing d.object_id}
    flexmock(doc).should_receive(:query_close).and_return true
    doc.close false
  end
  
  it 'calls the #save method of the project if the document path is not empty' do
    doc = Ruber::Document.new nil, __FILE__
    exp = doc.object_id
    flexmock(doc).should_receive(:close_url).and_return true
    flexmock(doc.instance_variable_get(:@project)).should_receive(:save).once
    doc.close false
  end
  
  it 'doesn\'t call the #save method of the project if the document path is empty' do
    doc = Ruber::Document.new nil
    exp = doc.object_id
    flexmock(doc).should_receive(:close_url).and_return true
    flexmock(doc.instance_variable_get(:@project)).should_receive(:save).never
    doc.close false
  end
  
  it 'calls the #close method of the project passing false' do
  doc = Ruber::Document.new nil
  exp = doc.object_id
  flexmock(doc).should_receive(:close_url).and_return true
  flexmock(doc.instance_variable_get(:@project)).should_receive(:close).with(false).once
  doc.close false
end

  
  it 'should disconnect any slot/block connected to it after emitting the closing signal if closing is confirmed' do
    doc = Ruber::Document.new nil, __FILE__
    exp = doc.object_id
    flexmock(doc).should_receive(:close_url).and_return true
    def doc.disconnect *args;end
    m = flexmock{|mk| mk.should_receive(:document_closing).with(exp).once.globally.ordered}
    doc.connect(SIGNAL('closing(QObject*)')){|d| m.document_closing d.object_id}
    flexmock(doc).should_receive(:disconnect).with_no_args.once.globally.ordered
    doc.close false
  end
    
  it 'should dispose of itself after emitting the closing signal, if closing is confirmed' do
    doc = Ruber::Document.new nil, __FILE__
    doc.close false
    doc.should be_disposed
  end
  
  it 'should return true, if closing is confirmed and successful and false otherwise' do
    doc = Ruber::Document.new nil, __FILE__
    flexmock(doc).should_receive(:close_url).once.and_return true
    doc.close( false).should be_true
    doc = Ruber::Document.new nil, __FILE__
    flexmock(doc).should_receive(:close_url).once.and_return false
    doc.close( false).should be_false
    flexmock(doc).should_receive(:query_close).once.and_return false
    doc.close(true).should be_false
  end
  
end

describe 'Ruber::Document#close_view' do
  
  before do
    @app = KDE::Application.instance
    @w = Qt::Widget.new
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp)
    @doc = Ruber::Document.new @app
    @view = @doc.create_view
  end
  
  it 'should call the "close" method' do
    flexmock(@doc).should_receive(:close).once.with(true)
    flexmock(@doc).should_receive(:close).once.with(false)
    @doc.close_view @view, true
    @doc.close_view @view, false
  end
  
end


describe 'Ruber::Document#extension' do
  
  before do
    @app = KDE::Application.instance
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return @comp
    @doc = Ruber::Document.new @app
  end

  it 'calls the extension method of its project' do
    ext = Qt::Object.new
    flexmock(@doc.own_project).should_receive(:extension).once.with(:xyz).and_return ext
    @doc.extension(:xyz).should equal(ext)
  end
  
end

describe 'Ruber::Document#file_type_match?' do
  
  before do
    @app = KDE::Application.instance
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return( @comp).by_default
    @doc = Ruber::Document.new @app, __FILE__
  end
  
  it 'should return true if both arguments are empty' do
    @doc.file_type_match?( [], []).should be_true
  end
  
  it 'should return true if one of the mimetypes match the document\'s mimetype, according to KDE::MimeType#=~' do
    @doc.file_type_match?( %w[image/png application/x-ruby], []).should be_true
    @doc.file_type_match?( %w[image/png =application/x-ruby], []).should be_true
    @doc.file_type_match?( %w[image/png !application/x-ruby], []).should be_false
    @doc.file_type_match?( %w[image/png =text/plain], []).should be_false
    @doc.file_type_match?( %w[image/png !=text/plain], []).should be_true
  end
  
  it 'should return true if one of the file patterns specified in the second argument matches the path of the file and false otherwise if the first argument is empty' do
    flexmock(@doc).should_receive(:path).and_return('xyz.rb')
    @doc.file_type_match?([], %w[*.txt *.rb]).should be_true
    @doc.file_type_match?([], %w[*.txt *.py]).should be_false
    @doc.file_type_match?([], %w[*.txt xyz*]).should be_true
  end
  
  it 'should do pattern matching even if the file starts with a dot' do
    flexmock(@doc).should_receive(:path).and_return('.xyz.rb')
    @doc.file_type_match?([], %w[*.txt *.rb]).should be_true
    @doc.file_type_match?([], %w[*.txt *.py]).should be_false
    @doc.file_type_match?([], %w[*.txt .xyz*]).should be_true
  end
  
  it 'only considers the basename of the file for pattern matching, not the directory name' do
    flexmock(@doc).should_receive(:path).and_return('/home/xyz.abc')
    @doc.file_type_match?([], ['xyz.*']).should be_true
    flexmock(File).should_receive(:fnmatch?).once.with('xyz.*', 'xyz.abc', Integer).and_return(true)
    @doc.file_type_match?([], ['xyz.*'])
  end
  
  it 'should always return false when doing pattern matching if the document is not associated with a file' do
    @doc = Ruber::Document.new @app
    @doc.file_type_match?([], %w[*.txt *.rb]).should be_false
  end
  
  it 'should return true if at least the mime type or the file name matches and false if both don\'t match, if neither arguments is empty' do
    @doc.file_type_match?(%w[image/png text/plain], %w[*.txt *.py]).should be_true
    @doc.file_type_match?(%w[image/png text/x-python], %w[*.txt *.rb]).should be_true
    @doc.file_type_match?(%w[image/png application/x-ruby], %w[*.txt *.rb]).should be_true
    @doc.file_type_match?(%w[image/png =text/plain], %w[*.txt *.py]).should be_false
  end
  
  it 'should accept a single string for any of the arguments, treating empty strings as empty arrays' do
    @doc.file_type_match?( '', '').should be_true
    @doc.file_type_match?( '','*.rb').should be_true
    @doc.file_type_match?( '','*.py').should be_false
    @doc.file_type_match?('application/x-ruby', '').should be_true
    @doc.file_type_match?('text/x-python', '').should be_false
    @doc.file_type_match?('application/x-ruby', '*.py').should be_true
    @doc.file_type_match?('text/x-python', '*.rb').should be_true
    @doc.file_type_match?('text/x-python', '*.png').should be_false
  end 
    
end

describe 'Ruber::Document#document_save_as' do
  
  before do
    @app = KDE::Application.instance
    @w = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@w).by_default
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp).by_default
    @projects = flexmock{|m| m.should_receive(:current).and_return(nil).by_default}
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    @config = flexmock('config')
    @config.should_receive(:[]).with(:general, :default_script_directory).and_return('/').by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @doc = Ruber::Document.new
    #to avoid actually writing the file
    flexmock(@doc.send :internal).should_receive(:saveAs).by_default
  end
  
  it 'calls KDE::EncodingFileDialog#get_save_file_name_and_encoding and saves the document with the url and encoding returned by it' do
    # I can't use KDE::EncodingFileDialog::Result for testing because, in ruby,
    # it doesn't allow to set its fields (in C++ it should work, but I didn't try)
    res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
    url = KDE::Url.new '/test.rb'
    flexmock(@doc.send :internal).should_receive(:saveAs).once.with url
    @doc.send :document_save_as
    @doc.encoding.should == 'UTF-16'
  end
  
  it 'uses the document\'s URL as default directory if the document is associated with a file' do
    flexmock(@doc).should_receive(:path).and_return '/test/xyz'
    res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with(String, '/test/xyz', String, Qt::Widget, String).and_return(res)
    @doc.send :document_save_as
  end
  
  it 'uses the current project\'s project directory as default directory if there is a current project' do
    prj = flexmock(:project_directory => File.dirname(__FILE__))
    @projects.should_receive(:current).once.and_return prj
    res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with(String, File.dirname(__FILE__), String, Qt::Widget, String).and_return(res)
    @doc.send :document_save_as
  end
  
  it 'uses UTF-8 as default encoding if running under ruby 1.9 and ISO-8859-1 if running under ruby 1.8' do
    res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
    if RUBY_VERSION.include? '9'
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with('UTF-8', String, String, Qt::Widget, String).and_return(res)
    else
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with('ISO-8859-1', String, String, Qt::Widget, String).and_return(res)
    end
    @doc.send :document_save_as
  end
  
  it 'does nothing if the user dismisses the dialog' do
    res = OpenStruct.new(:file_names => [], :encoding => '')
    flexmock(@doc.send :internal).should_receive(:encoding=).never
    flexmock(@doc.send :internal).should_receive(:saveAs).never
    flexmock(@doc.own_project).should_receive(:save).never
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
    @doc.send :document_save_as
    res = OpenStruct.new(:file_names => [''], :encoding => '')
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
    @doc.send :document_save_as
  end
  
  it 'saves the document project' do
    res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
    flexmock(@doc.own_project).should_receive(:save).once
    @doc.send :document_save_as
  end
  
  it 'returns the value returned by the internal KTextEditor::Document saveAs method' do
    res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
    flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).twice.and_return(res)
    flexmock(@doc.send :internal).should_receive(:saveAs).once.and_return true
    @doc.send(:document_save_as).should == true
    flexmock(@doc.send :internal).should_receive(:saveAs).once.and_return false
    @doc.send(:document_save_as).should == false
  end

  describe 'if the file already exists' do
    
    it 'asks the user and does nothing and returns false if he chooses not to save the document' do
      res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
      flexmock(File).should_receive(:exist?).once.with('/test.rb').and_return true
      flexmock(KDE::MessageBox).should_receive(:warning_continue_cancel).once.and_return KDE::MessageBox::Cancel
      flexmock(@doc.send :internal).should_receive(:saveAs).never
      flexmock(@doc.send :internal).should_receive(:encoding=).never
      flexmock(@doc.own_project).should_receive(:save).never
      @doc.send(:document_save_as).should == false
    end
    
    it 'asks the user and saves the file if he chooses not to overwrite the existin file' do
      res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
      flexmock(File).should_receive(:exist?).once.with('/test.rb').and_return true
      flexmock(KDE::MessageBox).should_receive(:warning_continue_cancel).once.and_return KDE::MessageBox::Continue
      flexmock(@doc.send :internal).should_receive(:saveAs).once.with KDE::Url.new('/test.rb')
      flexmock(@doc.send :internal).should_receive(:encoding=).with('UTF-16').once
      @doc.send :document_save_as
    end
    
  end
  
end

describe Ruber::Document do
  
  before do
    @app = KDE::Application.instance
    @w = Qt::Widget.new
    @comp = DocumentSpecComponentManager.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@comp)
  end
  
  describe '#save_settings' do
        
    it 'calls the #save method of the project if the document path is not empty' do
      doc = Ruber::Document.new nil, __FILE__
      exp = doc.object_id
      flexmock(doc.own_project).should_receive(:save).once
      doc.save_settings
    end
    
    it 'doesn\'t call the #save method of the project if the document path is empty' do
      doc = Ruber::Document.new nil
      flexmock(doc.own_project).should_receive(:save).never
      doc.save_settings
    end
    
  end
  
  describe "#has_editor?" do
    
    it 'returns false if the document has no view' do
      doc = Ruber::Document.new nil
      doc.should_not have_editor
    end
    
    it 'returns false if the document has a view but it\'s not visible' do
      doc = Ruber::Document.new nil
      doc.create_view
      doc.view.hide
      doc.should_not have_editor
    end
    
    it 'returns true if the document has a view and it\'s visible' do
      doc = Ruber::Document.new nil
      doc.create_view
      doc.view.show
      doc.should have_editor
    end
    
  end
  
end