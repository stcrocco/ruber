require 'spec/framework'
require './spec/common'

require 'tempfile'
require 'fileutils'
require 'flexmock/argument_types'
require 'facets/string/camelcase'

require 'ruber/editor/document'

describe Ruber::Document do
  
  include FlexMock::ArgumentTypes
  
  before do
    @world = Ruber[:world]
    @projects = Array.new 3 do |i|
      Ruber::Project.new File.join(Dir.tmpdir, "project-#{i}.ruprj"), "Project #{i}"
    end
    @doc = Ruber::Document.new @world, nil
  end
  
  describe '.new' do
    
    it 'can take the world as only argument' do
      lambda{Ruber::Document.new @world}.should_not raise_error
    end
    
    it 'can take an environment and a string as arguments' do
      lambda{Ruber::Document.new @world, __FILE__}.should_not raise_error
    end
    
    it 'can take an environment and a KDE::Url as arguments' do
      url = KDE::Url.new __FILE__
      lambda{Ruber::Document.new @world, url}.should_not raise_error
    end
    
    it 'can take an environment and nil as arguments' do
      lambda{Ruber::Document.new @world, nil}.should_not raise_error
    end
    
    it 'can take a Qt::Object as third argument' do
      parent = Qt::Object.new
      url = KDE::Url.new __FILE__
      lambda{Ruber::Document.new @world, nil, parent}.should_not raise_error
      lambda{Ruber::Document.new @world, __FILE__, parent}.should_not raise_error
      lambda{Ruber::Document.new @world, url, parent}.should_not raise_error
    end
    
    it 'creates a KTextEditor::Document' do
      @doc.instance_variable_get(:@doc).should be_a(KTextEditor::Document)
    end
    
    it 'points the KTextEditor::Document to the file or URL passed as second argument' do
      doc = Ruber::Document.new @world, __FILE__
      kdoc = doc.instance_variable_get(:@doc)
      kdoc.url.path.should == __FILE__
      url = KDE::Url.new __FILE__
      doc = Ruber::Document.new @world, url
      kdoc = doc.instance_variable_get(:@doc)
      kdoc.url.should == url
    end

    it 'creates an annotation model for the document' do
      @doc.interface('annotation_interface').annotation_model.should_not be_nil
    end
    
    it 'doesn\'t create views' do
      @doc.views.should be_empty
    end

    it 'doesn\'t create document projects' do
      doc = Ruber::Document.new @world, nil
      doc.instance_variable_get(:@projects).should be_empty
    end
    
    it 'makes the document not active' do
      doc = Ruber::Document.new @world, __FILE__
      doc.should_not be_active
    end
    
  end
  
  describe "#has_file?" do
    
    context 'when called with :local' do
      
      it 'returns true if the document is associated with a local file' do
        doc = Ruber::Document.new @world, __FILE__
        doc.should have_file(:local)
      end
      
      it 'returns false if the document is associated with a remote file' do
        remote_file = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
        url = KDE::Url.new(remote_file)
        doc = Ruber::Document.new @world, url
        
        doc.should_not have_file(:local)
      end
      
      it 'returns false if the document isn\'t associated with any file' do
        doc = Ruber::Document.new @world
        doc.should_not have_file(:local)
      end
      
    end
    
    context 'when called with :remote' do
      
      it 'returns false if the document is associated with a local file' do
        doc = Ruber::Document.new @world, __FILE__
        doc.should_not have_file(:remote)
      end
      
      it 'returns true if the document is associated with a remote file' do
        remote_file = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
        url = KDE::Url.new remote_file
        doc = Ruber::Document.new  @world, url
        doc.should have_file(:remote)
      end
      
      it 'returns false if the document isn\'t associated with any file' do
        doc = Ruber::Document.new @world
        doc.should_not have_file(:remote)
      end
      
    end
    
    context 'when called with :any or no arguments' do
      
      it 'returns true if the document is associated with a local file' do
        doc = Ruber::Document.new @world, __FILE__
        doc.should have_file(:any)
        doc.should have_file
      end
      
      it 'returns true if the document is associated with a remote file' do
        remote_file = 'http://github.com/stcrocco/ruber/raw/master/ruber.gemspec'
        doc = Ruber::Document.new @world, KDE::Url.new(remote_file)
        doc.should have_file(:any)
        doc.should have_file
      end
      
      it 'returns false if the document isn\'t associated with any file' do
        doc = Ruber::Document.new @world
        doc.should_not have_file(:any)
        doc.should_not have_file
      end
      
    end
    
  end
  
  describe '#own_project' do
    
    context 'when called with an environment as argument' do

      context 'when the document has a document project corresponding to the given environment' do
        
        before do
          @other_env = @projects[1].environment
          @doc.own_project @other_env
        end
        
        it 'returns that document project' do
          @doc.instance_variable_get(:@projects)[@other_env].should_not be_nil
          own_prj = @doc.own_project(@other_env)
          own_prj.should == @doc.instance_variable_get(:@projects)[@other_env]
        end
        
      end
      
      context 'and the document doesn\'t have a document project associated to that environment' do
        
        before do
          @other_env = @projects[1].environment
        end
        
        it 'creates a new document project for that environment and returns it' do
          own_prj = @doc.own_project(@other_env)
          own_prj.environment.should == @other_env
        end
        
      end
      
    end
    
    context 'when called without arguments' do
      
      context 'and the document has a document project corresponding to the active environment' do
        
        before do
          @other_env = @projects[1].environment
          @view = @doc.create_view @other_env
          flexmock(Ruber[:world]).should_receive(:active_environment).and_return @other_env
        end
        
        it 'returns the document project associated with the active environment' do
          own_prj = @doc.own_project
          own_prj.should == @doc.instance_variable_get(:@projects)[@other_env]
        end
        
      end
      
      context 'and the document doesn\'t have a document project associated to the active environment' do
        
        before do
          @other_env = @projects[1].environment
          flexmock(Ruber[:world]).should_receive(:active_environment).and_return @other_env
        end
        
        it 'creates a new document project for the active environment and returns it' do
          own_prj = @doc.own_project
          own_prj.environment.should == Ruber[:world].active_environment
        end
        
      end

    end
    
  end
  
  describe '#project' do
    
    before do
      @doc = Ruber::Document.new @world, __FILE__
    end
    
    context 'when called with an environment as argument' do
      
      context 'and the environment is associated with a project' do
        
        before do
          @other_env = @projects[0].environment
        end
        
        context 'and the document belongs to that project' do
          
          before do
            flexmock(@projects[0]).should_receive(:file_in_project?).with("file://#{__FILE__}").and_return true
          end
        
          it 'returns the project associated with the environment if the document belongs to it' do
            @doc.project(@other_env).should == @projects[0]
          end
          
        end
        
        context 'and the document doesn\'t belong to that project' do
          
          before do
            flexmock(@projects[0]).should_receive(:file_in_project?).with("file://#{__FILE__}").and_return false
          end
          
          it 'returns the document project associated with the environment, if it exists' do
            view = @doc.create_view(@other_env)
            prj = @doc.project(@other_env)
            prj.should == @doc.instance_variable_get(:@projects)[@other_env]
          end
          
          it 'creates and returns a new document project associated with that environment if it doesn\'t already exist' do
            prj = @doc.project(@other_env)
            prj.environment.should == @other_env
          end
          
        end
        
      end
      
      context 'and the environment is not associated with a project' do
        
        it 'returns the document project associated with the environment' do
          other_env = Ruber::World::Environment.new nil
          prj = @doc.project(other_env)
          prj.should be_a(Ruber::DocumentProject)
          prj.environment.should == other_env
        end
        
      end
      
    end
    
    context 'when called without arguments' do
      
      context 'and the active environment is associated with a project' do
        
        before do
          @other_env = @projects[0].environment
          flexmock(Ruber[:world]).should_receive(:active_environment).and_return @other_env
        end
        
        context 'and the document belongs to the active project' do
          
          before do
            flexmock(@projects[0]).should_receive(:file_in_project?).with("file://#{__FILE__}").and_return true
          end
        
          it 'returns the project associated with the active environment if the document belongs to it' do
            @doc.project.should == @projects[0]
          end
          
        end
        
        context 'and the document doesn\'t belong to the active project' do
          
          before do
            flexmock(@projects[0]).should_receive(:file_in_project?).with("file://#{__FILE__}").and_return false
          flexmock(Ruber[:world]).should_receive(:active_environment).and_return @other_env
          end
          
          it 'returns the document project associated with the active environment, if it exists' do
            view = @doc.create_view(@other_env)
            prj = @doc.project
            prj.should == @doc.instance_variable_get(:@projects)[@other_env]
          end
          
          it 'creates and returns a new document project associated with the active environment if it doesn\'t already exist' do
            prj = @doc.project
            prj.should == @doc.instance_variable_get(:@projects)[@other_env]
          end
          
        end
        
      end
      
      context 'and the active environment is not associated with a project' do
        
        before do
          @other_env = Ruber::World::Environment.new nil
          flexmock(Ruber[:world]).should_receive(:active_environment).and_return @other_env
        end
        
        it 'creates and returns a new document project associated with that environment if it doesn\'t already exist' do
          prj = @doc.project
          prj.should == @doc.instance_variable_get(:@projects)[@other_env]
        end
        
      end
      
    end
    
  end
  
  describe '#save' do
    
    it 'calls document_save_as if the document has no filename' do
      flexmock(@doc).should_receive(:document_save_as).once.and_return(true)
      flexmock(@doc).should_receive(:document_save_as).once.and_return(false)
      @doc.save.should be_true
      @doc.save.should be_false
    end
    
    describe ', when the document is associated with a file' do
      
      it 'calls the document_save_as method if the document is read only' do
        Tempfile.open('ruber_document_test') do |f|
          f.write 'test'
          f.flush
          doc = Ruber::Document.new @world, f.path
          flexmock(doc.send :internal).should_receive(:is_read_write).once.and_return false
          flexmock(doc).should_receive(:document_save_as).once
          doc.text += ' added'
          doc.save
        end
      end
      
      it 'calls the #save method of its own projects' do
        Tempfile.open('ruber_document_test') do |f|
          f.write 'test'
          f.flush
          doc = Ruber::Document.new @world, f.path
          doc.create_view @projects[1].environment
          doc_prjs = [
            doc.own_project(@world.default_environment),
            doc.own_project(@projects[1].environment)
          ]
          doc_prjs.each{|pr| flexmock(pr).should_receive(:save).once }
          doc.text += ' added'
          doc.save
        end
      end
      
      it 'saves the document if the document is associated with a file' do
        Tempfile.open('ruber_document_test') do |f|
          f.write 'test'
          f.flush
          doc = Ruber::Document.new @world, f.path
          doc.text += ' added'
          doc.save.should be_true
          File.read( f.path ).should == 'test added'
        end
      end
      
    end

  end
  
  describe '#create_view' do
    
    before do
      @prj = Ruber::Project.new File.join(Dir.tmpdir, 'xyz.ruprj'), 'Test'
      @env = Ruber::World::Environment.new nil
      @other_env = Ruber::World::Environment.new @prj
    end
    
    it 'can take nil as argument' do
      lambda{@doc.create_view nil}.should_not raise_error
    end
    
    it 'can take an environment as argument' do
      lambda{@doc.create_view @other_env}.should_not raise_error
    end
    
    it 'can take an optional Qt::Widget as argument' do
      parent = Qt::Widget.new
      lambda{@doc.create_view @other_env, parent}.should_not raise_error
    end
    
    it 'creates a new view associated with the document' do
      @doc.create_view @other_env
      @doc.views[0].document.should == @doc
      @doc.create_view @other_env
      @doc.views[1].document.should == @doc
      @doc.views[1].should_not == @doc.views[0]
    end
    
    it 'makes the view child of the parent, if the parent argument was given' do
      parent = Qt::Widget.new
      @doc.create_view @other_env, parent
      @doc.views[0].parent.should == parent
    end
    
    it 'returns the new view' do
      view = @doc.create_view @other_env
      view.should be_a Ruber::EditorView
      @doc.views[0].should == view
    end
    
    context 'if an environment was given as argument' do
    
      it 'associates the view with the environment passed as argument' do
        views = []
        views[0] = @doc.create_view @other_env
        views[1] = @doc.create_view @env
        views[0].environment.should == @other_env
        views[1].environment.should == @env
      end
      
    end
    
    context 'if no environment was given as argument' do
      
      it 'associates the view with the world\'s active environment' do
        flexmock(@world).should_receive(:active_environment).and_return @other_env
        view = @doc.create_view
        view.environment.should == @other_env
      end
      
    end
    
  end

  it 'allows to get and change the text' do
    txt="test text"
    lambda{@doc.text="test text"}.should_not raise_error
    @doc.text.should == txt
  end

  it 'returns the mimetype of the document' do
    @doc.mime_type.should == 'text/plain'
    @doc.open_url KDE::Url.from_path(__FILE__)
    @doc.mime_type.should == 'application/x-ruby'
  end

  it 'emits the "modified_changed(QObject*, bool)" signal when the modified status changes' do
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

  it 'emits the "document_name_changed(QString, QObject*)" signal when the document name changes' do
    m = flexmock
    m.should_receive(:document_name_changed).once
    @doc.connect(SIGNAL('document_name_changed(QString, QObject*)')) do |str, obj|
      obj.should == @doc
      str.should == @doc.document_name
      m.document_name_changed
    end
    @doc.open_url KDE::Url.from_path( __FILE__)
  end

  it 'returns the path of the file usgin the "path" method or an empty string if the document is not associated with a file' do
    @doc.path.should == ''
    @doc.open_url KDE::Url.from_path( __FILE__ )
    @doc.path.should == __FILE__
  end

  it 'returns an empty string if the document is empty' do
    @doc.text.should_not be_nil
  end

  it 'tells whether it\'s a pristine document' do
    @doc.should be_pristine
    @doc.text = "a"
    @doc.should_not be_pristine
    flexmock(Ruber[:config]).should_receive(:[]).with(:general, :default_script_directory).and_return ENV['HOME']
    Tempfile.open('ruber_document_test') do |f|
      res = OpenStruct.new(:file_names => [f.path], :encoding => @doc.encoding)
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).and_return(res)
      flexmock(KDE::MessageBox).should_receive(:warning_continue_cancel).and_return KDE::MessageBox::Continue
      @doc.save
      @doc.should_not be_pristine
    end
    Ruber::Document.new(@world, __FILE__).should_not be_pristine
  end

  ["text_changed(QObject*)", "about_to_close(QObject*)", 'about_to_close(QObject*)', 
'about_to_reload(QObject*)', 'document_url_changed(QObject*)'].each do |sig|
    sig_name = sig[0...sig.index('(')]
    o_sig_name = sig_name.camelcase(false)
    o_sig = sig.camelcase(false).sub('(QObject*','(KTextEditor::Document*')
    it "emits the \"#{sig}\" signal in response to the underlying KTextEditor::Document \"#{o_sig}\" signal" do
      m = flexmock
      m.should_receive( sig_name.to_sym).once.with(@doc.object_id)
      @doc.connect(SIGNAL(sig)){|o| m.send(sig_name.to_sym, o.object_id)}
      d = @doc.instance_variable_get(:@doc)
      d.instance_eval "emit #{o_sig_name}( self)"
    end
  end

  it 'emits the "mode_changed(QObject*)" signal in response to the underlying KTextEditor::Document "modeChanged(KTextEditor::Document)" signal' do
    m = flexmock
    m.should_receive( :mode_changed).once.with(@doc.object_id)
    @doc.connect(SIGNAL('mode_changed(QObject*)')){|o| m.mode_changed o.object_id}
    @doc.mode = "Ruby"
  end

  it 'emits the "highlighting_mode_changed(QObject*)" signal in response to the underlying KTextEditor::Document "highlightingModeChanged(KTextEditor::Document)" signal' do
    m = flexmock
    m.should_receive( :h_mode_changed).once.with(@doc.object_id)
    @doc.connect(SIGNAL('highlighting_mode_changed(QObject*)')){|o| m.h_mode_changed o.object_id}
    @doc.highlighting_mode = "Ruby"
  end

  it 'emits the "text_modified(KTextEditor::Range, KTextEditor::Range, QObject*)" signal in response to the underlying KTextEditor::Document "textChanged(KTextEditor::Document*, KTextEditor::Range, KTextEditor::Range)" signal' do
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

  it 'emits the "text_removed(KTextEditor::Range, QObject*)" signal in response to the underlying KTextEditor::Document "textRemoved(KTextEditor::Document*, KTextEditor::Range)" signal' do
    m = flexmock
    m.should_receive( :text_removed).once.with(@doc.object_id)
    @doc.connect(SIGNAL('text_removed(KTextEditor::Range, QObject*)')){|_, o| m.text_removed o.object_id}
    d = @doc.instance_variable_get(:@doc)
    d.instance_eval{emit textRemoved(self, KTextEditor::Range.new(0,0,0,5))}
  end

  it 'emits the "view_created(QObject*, QObject*)" signal after creating a view' do
    m = flexmock
    m.should_receive(:view_created).once.with(@doc.object_id)
    @doc.connect(SIGNAL('view_created(QObject*, QObject*)'))do |_, o| 
      m.view_created o.object_id
      @doc.views[0].should be_a(Ruber::EditorView)
    end
    @doc.create_view nil
  end

  it 'returns true when close_url succeeds' do
    doc = Ruber::Document.new @world, __FILE__
    doc.close_url(false).should be_true
  end
  
  context 'when the url of the document changes' do
    
    it 'calls the update_project method of each component for each document project before emitting the document_url_changed signal' do
      prjs = Array.new 3 do |i|
        Ruber::Project.new File.join(Dir.tmpdir, "xyz#{i}"), "Project #{i}"
      end
      @doc.create_view prjs[1].environment
      doc_prjs = [
        @doc.own_project(@world.default_environment),
        @doc.own_project(prjs[1].environment)
      ]
      comps = Ruber[:components]
      test_comps = Array.new(3) do
        flexmock do |m|
          doc_prjs.each do |p|
            m.should_receive(:update_project).once.with(p)
          end
        end
      end
      comps.instance_variable_get(:@features)[:components]= test_comps
      class << test_comps
        alias_method :each_component, :each
      end
      url_changed_rec = flexmock{|m| m.should_receive(:url_changed).once}
      internal = @doc.send :internal
      @doc.connect(SIGNAL('document_url_changed(QObject*)')){url_changed_rec.url_changed}
      internal.instance_eval{emit documentUrlChanged(self)}
      comps.instance_variable_get(:@features)[:components]= comps
    end
    
  end
  
  it 'calls the update_project method of each component, passing it its project, when the url of the document changes, but before emitting the document_url_changed signal' do
    @doc.own_project @world.default_environment
    comps = Ruber[:components]
    test_comps = Array.new(3) do
      flexmock do |m|
        m.should_receive(:update_project).once.with(Ruber::DocumentProject).globally.ordered
      end
    end
    comps.instance_variable_get(:@features)[:components]= test_comps
    class << test_comps
      alias_method :each_component, :each
    end
    url_changed_rec = flexmock{|m| m.should_receive(:url_changed).once.globally.ordered}
    internal = @doc.send :internal
    @doc.connect(SIGNAL('document_url_changed(QObject*)')){url_changed_rec.url_changed}
    internal.instance_eval{emit documentUrlChanged(self)}
    comps.instance_variable_get(:@features)[:components]= comps
  end

  describe '#close' do
  
    before do
      doc = Ruber::Document.new @world, __FILE__
      flexmock(@doc.own_project).should_receive(:save).by_default
    end
    
    context 'if the argument is true' do
      
      context 'and #query_close returns false' do
        
        before do
          flexmock(@doc).should_receive(:query_close).and_return false
        end
        
        it 'returns immediately' do
          mk = flexmock{|m| m.should_receive(:test).never}
          @doc.connect(SIGNAL('closing(QObject*)')){|d| mk.test d}
          flexmock(@doc).should_receive(:query_close).and_return false
          @doc.close
        end
        
        it 'returns false' do
          @doc.close.should == false
        end
        
      end
      
      context 'and one of the document projects\' #query_close method returns false' do
        
        before do
          flexmock(@doc).should_receive(:query_close).and_return true
          @projects.each_with_index do |prj, i|
            res = (i != 1)
            flexmock(@doc.own_project prj.environment).should_receive(:query_close).and_return res
          end
        end
        
        it 'returns immediately' do
          mk = flexmock{|m| m.should_receive(:test).never}
          @doc.connect(SIGNAL('closing(QObject*)')){|d| mk.test d}
          @doc.close
        end
        
        it 'returns false' do
          @doc.close.should == false
        end
        
        
      end
      
      context 'and both the document\'s and the document project\'s #query_close methods return true' do
        
        before do
          @doc = Ruber::Document.new @world, __FILE__
        end
        
        it 'emits the #closing signal passing the document as argument' do
          arg = nil
          @doc.connect(SIGNAL('closing(QObject*)')){|doc| arg = doc}
          @doc.close
          arg.should == @doc
        end
        
        it 'calls the #save method of each of the document\'s own projects after emitting the #closing signal' do
          mk = flexmock{|m| m.should_receive(:test).once.globally.ordered}
          @doc.connect(SIGNAL('closing(QObject*)')){mk.test}
          @doc.create_view @projects[1].environment
          doc_prjs = [
            @doc.own_project(@world.default_environment),
            @doc.own_project(@projects[1].environment)
          ]
          doc_prjs.each_with_index do |pr, i|
            flexmock(i.to_s, pr).should_receive(:save).once.globally.ordered(:projects)
          end
          @doc.close
        end

        it 'calls the #close_url method of the KTextEditor::Document passing false as argument' do
          flexmock(@doc).should_receive(:close_url).once.with(false)
          @doc.close
        end
        
        it 'closes the views associated with the document' do
          views = Array.new(3){@doc.create_view}
          views.each do |v|
            flexmock(v).should_receive(:close).once
          end
          @doc.close
        end
        
        it 'closes each document project associated with the document passing false as argument' do
          envs = Array.new(3){Ruber::World::Environment.new nil}
          doc_prjs = envs.map{|e| @doc.own_project e}
          doc_prjs.each{|pr| flexmock(pr).should_receive(:close).with(false).once}
          @doc.close
        end
        
        it 'disconnects any slot/block connected to it after emitting the closing signal' do
          def @doc.disconnect *args
          end
          flexmock(@doc).should_receive(:disconnect).with_no_args.once
          @doc.close
        end
        
        it 'empties the list of document projects' do
          envs = Array.new(3){Ruber::World::Environment.new nil}
          envs.each{|e| @doc.own_project(e)}
          @doc.close
          @doc.instance_variable_get(:@projects).should be_empty
        end
        
        it 'returns true' do
          @doc.close.should == true
        end
      end
      
    end
      
    context 'if the argument is false' do
      
      before do
        @doc = Ruber::Document.new @world, __FILE__
      end
      
      it 'doesn\'t call #query_close' do
        flexmock(@doc).should_receive(:query_close).never
        @doc.close false
      end
      
      it 'emits the #closing signal passing the document as argument' do
        arg = nil
        @doc.connect(SIGNAL('closing(QObject*)')){|doc| arg = doc}
        @doc.close false
        arg.should == @doc
      end
      
      it 'calls document\'s own project #save method after emitting the #closing signal' do
        mk = flexmock{|m| m.should_receive(:test).once.globally.ordered}
        @doc.connect(SIGNAL('closing(QObject*)')){mk.test}
        flexmock(@doc.own_project).should_receive(:save).once.globally.ordered
        @doc.close false
      end

      it 'calls the #close_url method of the KTextEditor::Document passing false as argument' do
        flexmock(@doc).should_receive(:close_url).once.with(false)
        @doc.close false
      end
      
      it 'closes the views associated with the document' do
        views = Array.new(3){@doc.create_view}
        views.each do |v|
          flexmock(v).should_receive(:close).once
        end
        @doc.close false
      end
      
      it 'disconnects any slot/block connected to it after emitting the closing signal' do
        def @doc.disconnect *args;end
        flexmock(@doc).should_receive(:disconnect).with_no_args.once
        @doc.close false
      end
      
      it 'returns true' do
        @doc.close(false).should == true
      end
      
    end
    
  end
  
  describe '#extension' do
    
    context 'when called with an environment as second argument' do
      
      context 'and there\'s a document project associated with that environment' do
        
        before do
          @view = @doc.create_view @projects[1].environment
        end
        
        it 'calls the extension method of the document project associated with that environment' do
          ext = Qt::Object.new
          env = @projects[1].environment
          prj = @doc.own_project env
          flexmock(prj).should_receive(:extension).once.with(:xyz).and_return ext
          @doc.extension(:xyz, env).should equal(ext)
        end
        
      end
      
      context 'and there isn\'t a document project associated with that environment' do
        
        it 'creates a document project living in that environment and returns the extension associated with it' do
          ext = Qt::Object.new
          env = @projects[1].environment
          prj = @doc.own_project env
          flexmock(prj).should_receive(:extension).once.with(:xyz).and_return ext
          @doc.extension(:xyz, env).should equal(ext)
        end
        
      end
      
    end
    
    context 'when called with a single argument' do
      
      context 'and there\'s a document project associated with the active environment' do
        
        before do
          flexmock(@world).should_receive(:active_environment).and_return @projects[1].environment
          @view = @doc.create_view @projects[1].environment
        end
        
        it 'calls the extension method of the document project associated with that environment' do
          ext = Qt::Object.new
          env = @projects[1].environment
          prj = @doc.own_project env
          flexmock(prj).should_receive(:extension).once.with(:xyz).and_return ext
          @doc.extension(:xyz).should equal(ext)
        end
        
      end
      
      context 'and there isn\'t a document project associated with the active environment' do
        
        before do
          flexmock(@world).should_receive(:active_environment).and_return @projects[1].environment
        end
        
        it 'creates a document project living in the active environment and returns the extension associated with it' do
          ext = Qt::Object.new
          env = @projects[1].environment
          prj = @doc.own_project env
          flexmock(prj).should_receive(:extension).once.with(:xyz).and_return ext
          @doc.extension(:xyz, env).should equal(ext)
        end
        
      end
      
    end
    
    it 'calls the extension method of its project' do
      ext = Qt::Object.new
      flexmock(@doc.own_project).should_receive(:extension).once.with(:xyz).and_return ext
      @doc.extension(:xyz).should equal(ext)
    end
    
  end

  describe '#file_type_match?' do
    
    before do
      @doc = Ruber::Document.new @world, __FILE__
    end
    
    context 'if both arguments are empty' do
    
      it 'returns true' do
        @doc.file_type_match?( [], []).should be_true
      end
      
      it 'returns true even if the document is not associated with a file' do
        @doc = Ruber::Document.new @world
        @doc.file_type_match?( [], []).should be_true
      end
      
    end
    
    context 'if only the first argument is not empty' do
      
      it 'returns true if one of the mimetypes match the document\'s mimetype, according to KDE::MimeType#=~' do
        @doc.file_type_match?( %w[image/png application/x-ruby], []).should be_true
        @doc.file_type_match?( %w[image/png =application/x-ruby], []).should be_true
      end
      
      it 'returns false if none of the mimetypes match the document\'s, according to KDE::MimeType#=~' do
        @doc.file_type_match?( %w[image/png !application/x-ruby], []).should be_false
        @doc.file_type_match?( %w[image/png =text/plain], []).should be_false
      end
      
    end
    
    context 'if only the second argument is not empty' do
      
      context 'and the document is associated with a file' do
        
        it 'returns true if one of the patterns match the path of the file' do
          @doc.file_type_match?([], %w[*.txt *.rb]).should be_true
          base = File.basename(__FILE__, '.rb')
          @doc.file_type_match?([], %W[*.txt #{base}*]).should be_true
        end
        
        it 'returns false if none of the patterns matche the path of the file'do
          @doc.file_type_match?([], %w[*.txt *.py]).should be_false
        end
        
        it 'does pattern matching even if the file starts with a dot' do
          flexmock(@doc).should_receive(:path).and_return('.xyz.rb')
          @doc.file_type_match?([], %w[*.txt *.rb]).should be_true
          @doc.file_type_match?([], %w[*.txt .xyz*]).should be_true
        end
        
        it 'ignores the directory part of the file path' do
          flexmock(@doc).should_receive(:path).and_return('/home/xyz.abc')
          @doc.file_type_match?([], ['xyz.*']).should be_true
          flexmock(File).should_receive(:fnmatch?).once.with('xyz.*', 'xyz.abc', Integer).and_return(true)
          @doc.file_type_match?([], ['xyz.*']).should == true
        end
        
      end
      
      context 'and the document is not associated with a file' do
        
        it 'always returns false' do
          @doc = Ruber::Document.new @world, nil
          @doc.file_type_match?([], %w[*.txt *.rb]).should be_false
        end
        
      end
      
    end
    
    context 'if neither argument is empty' do
      
      it 'returns true if there\'s a matching mimetype and no matching pattern' do
        @doc.file_type_match?(%w[image/png application/x-ruby], %w[*.txt *.py]).should == true
      end
      
      it 'returns true if there\'s a matching pattern and no matching mimetype' do
        @doc.file_type_match?(%w[image/png text/x-python], %w[*.txt *.rb]).should be_true
      end
      
      it 'returns false if there\'s neither a matching mimetype nor a matching pattern' do
        @doc.file_type_match?(%w[image/png =text/plain], %w[*.txt *.py]).should be_false
      end
      
    end
    
    context 'if any of the arguments is an empty string' do
      
      it 'considers it as if it were an empty array' do
        @doc.file_type_match?( '', '').should be_true
        @doc.file_type_match?( '',['*.rb']).should be_true
        @doc.file_type_match?( '',['*.py']).should be_false
        @doc.file_type_match?(['application/x-ruby'], '').should be_true
        @doc.file_type_match?(['text/x-python'], '').should be_false
      end
      
    end
    
    context 'if any of the argument is a non-empty string' do
      
      it 'considers it as if it were an array containing only that string' do
        @doc.file_type_match?('application/x-ruby', []).should be_true
        @doc.file_type_match?('text/x-python', []).should be_false
        @doc.file_type_match?('application/x-ruby', '*.py').should be_true
        @doc.file_type_match?('text/x-python', '*.rb').should be_true
        @doc.file_type_match?('text/x-python', '*.png').should be_false
      end
      
    end
    
  end
  
  describe '#document_save_as' do
    
    before do
      #to avoid actually writing the file
      flexmock(@doc.send :internal).should_receive(:saveAs).by_default
    end
    
    it 'calls KDE::EncodingFileDialog#get_save_file_name_and_encoding and saves the document with the url and encoding it returns' do
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
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with(String, '/test/xyz', String, Ruber::MainWindow, String).and_return(res)
      @doc.send :document_save_as
    end
    
    it 'uses the current project\'s project directory as default directory if there is a current project' do
      prj = flexmock(:project_directory => File.dirname(__FILE__))
      flexmock(Ruber[:world]).should_receive(:active_project).once.and_return prj
      res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with(String, File.dirname(__FILE__), String, Ruber::MainWindow, String).and_return(res)
      @doc.send :document_save_as
    end
    
    it 'uses UTF-8 as default encoding if running under ruby 1.9 and ISO-8859-1 if running under ruby 1.8' do
      res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
      if RUBY_VERSION.include? '9'
        flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with('UTF-8', String, String, Ruber::MainWindow, String).and_return(res)
      else
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.with('ISO-8859-1', String, String, Ruber::MainWindow, String).and_return(res)
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
    
    it 'saves the document projects' do
      res = OpenStruct.new(:file_names => ['/test.rb'], :encoding => 'UTF-16')
      flexmock(KDE::EncodingFileDialog).should_receive(:get_save_file_name_and_encoding).once.and_return(res)
      @doc.create_view @projects[1].environment
      doc_prjs = [
        @doc.own_project(@world.default_environment),
        @doc.own_project(@projects[1].environment)
      ]
      doc_prjs.each{|pr| flexmock(pr).should_receive(:save).once}
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
        flexmock(@doc.own_project).should_receive(:save).never
        flexmock(File).should_receive(:exist?).once.with('/test.rb').and_return true
        flexmock(KDE::MessageBox).should_receive(:warning_continue_cancel).once.and_return KDE::MessageBox::Cancel
        flexmock(@doc.send :internal).should_receive(:saveAs).never
        flexmock(@doc.send :internal).should_receive(:encoding=).never
        
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
  
  describe '#save_settings' do
        
    it 'calls the #save method of the document\'s own projects' do
      doc = Ruber::Document.new @world, __FILE__
      @projects.each do |prj| 
        env = prj.environment
        doc.create_view env
        own_prj = doc.own_project env
        flexmock(own_prj).should_receive(:save).once
      end
      own_prj = doc.own_project @world.default_environment
      flexmock(own_prj).should_receive(:save).once
      doc.save_settings
    end
    
  end
  
  describe 'when a view is closed' do
    
    it 'removes the view from the list' do
      doc = Ruber::Document.new @world, nil
      views = 3.times.map{doc.create_view}
      views[1].close
      new_views = doc.views
      new_views.size.should == 2
      new_views.should == [views[0], views[2]]
    end
    
    it 'emits the closing_view(QWidget*, QObject*) signal before removing the view from the list' do
      doc = Ruber::Document.new @world, nil
      views = 3.times.map{doc.create_view}
      test = flexmock{|m| m.should_receive(:closing_view).once.with(doc, views[1])}
      doc.connect(SIGNAL('closing_view(QWidget*, QObject*)')) do |v, d| 
        test.closing_view d, v
        doc.views.should include(views[1])
      end
      views[1].close
    end
        
  end
  
  describe '#has_view?' do
    
    it 'returns true if there\'s at least one view associated with the document' do
      doc = Ruber::Document.new @world, nil
      doc.create_view
      doc.should have_view
      doc.create_view
      doc.should have_view
    end
    
    it 'returns false if there are no views associated with the document' do
      doc = Ruber::Document.new @world, nil
      doc.should_not have_view
    end
    
  end
  
  describe '#active_view' do
    
    it 'returns the active view if any' do
      doc = Ruber::Document.new @world
      views = 3.times.map{doc.create_view}
      flexmock(doc.send(:internal)).should_receive(:active_view).once.and_return(views[2].send(:internal))
      doc.active_view.should == views[2]
    end
    
    it 'returns nil if there isn\'t an active view associated with the document' do
      doc = Ruber::Document.new @world
      doc.active_view.should be_nil
      views = 3.times.map{doc.create_view}
      flexmock(doc.send(:internal)).should_receive(:active_view).once.and_return(nil)
      doc.active_view.should be_nil
    end
    
  end
  
  describe '#text' do
    
    before do
      @doc = Ruber::Document.new @world
    end
    
    context 'when called with no arguments' do
    
      it 'returns an empty string if the document is empty' do
        @doc.text.should == ''
      end
      
      it 'returns the text of the document if the document is not empty' do
        @doc.text = 'xyz'
        @doc.text.should == 'xyz'
      end
      
    end
    
    context 'when called with a KTextEditor::Range argument' do
      
      it 'returns an empty string if the document is empty' do
        @doc.text(KTextEditor::Range.new(2,3, 4, 5)).should == ''
      end
      
      it 'returns the text contained in the given range if the document is not empty' do
        @doc.text = "abc\ndef\nghi"
        @doc.text(KTextEditor::Range.new(0,1,1,2)).should == "bc\nde"
      end
      
      it 'returns an empty string if the range is invalid' do
        @doc.text = "abc\ndef\nghi"
        @doc.text(KTextEditor::Range.new(-5,0,0,2)).should == ''
      end
      
    end
    
    context 'when the second argument is true' do

      it 'returns an empty string if the document is empty' do
        @doc.text(KTextEditor::Range.new(2,3, 4, 5), true).should == ''
      end
      
      it 'returns the text contained in the given range, considered as a block selection, if the document is not empty' do
        @doc.text = "abc\ndef\nghi"
        @doc.text(KTextEditor::Range.new(0,1,1,2), true).should == "b\ne"
      end
      
      it 'returns an empty string if the range is invalid' do
        @doc.text = "abc\ndef\nghi"
        @doc.text(KTextEditor::Range.new(-5,0,0,2), true).should == ''
      end

    end
    
  end
  
  describe '#line' do
    
    before do
      @doc = Ruber::Document.new @world
    end
    
    it 'returns the text in the line given as argument' do
      @doc.text = "abc\ndef\nghi"
      lines = %w[abc def ghi]
      lines.each_with_index do |str, i|
        @doc.line(i).should == str
      end
    end
    
    it 'returns an empty string if the line is empty' do
      @doc.text = "abc\n\nxyz"
      @doc.line(1).should == ''
    end
    
    it 'returns an empty string if the line number corresponds to a nonexisting line' do
      @doc.text = "abc\ndef\nghi"
      @doc.line(10).should == ''
    end
    
  end
  
  describe '#views' do
    
    before do
      @doc = Ruber::Document.new @world
    end
    
    it 'returns a list of all the views associated with the document' do
      views = 3.times.map{@doc.create_view}
      @doc.views.should == views
    end
    
    it 'returns an empty list if there\'s no view associated with the document' do
      @doc.views.should == []
    end
    
  end
  
  describe '#project_on' do

    it 'returns a ProjectedDocument associated with the document and the environment given as argument' do
      prj_doc = @doc.project_on @projects[1].environment
      prj_doc.should be_a(Ruber::ProjectedDocument)
      prj_doc.environment.should == @projects[1].environment
      prj_doc.document.should == @doc
    end
    
  end
  
  describe '#can_close?' do
    
    context 'when the argument is true' do
      
      it 'calls #query_close and returns false if it returns false' do
        flexmock(@doc).should_receive(:query_close).once.and_return false
        @doc.can_close?(true).should == false
      end

      context 'if #query_close returns true' do
        
        before do
          flexmock(@doc).should_receive(:query_close).once.and_return true
          @doc_prjs = [@doc.own_project(@world.default_environment)]
          @projects.each do |pr|
            @doc.create_view pr.environment
            @doc_prjs << @doc.own_project(pr.environment)
          end
        end
        
        it 'returns true if the #query_close method of each of the document\'s own projects return true' do
          @doc_prjs.each do |pr| 
            flexmock(pr).should_receive(:query_close).once.and_return true
          end
          @doc.can_close?(true).should == true
        end
        
        it 'returns false as soon as one of the project\'s #query_close method returns false' do
          flexmock(@doc_prjs[0]).should_receive(:query_close).once.and_return true
          flexmock(@doc_prjs[1]).should_receive(:query_close).once.and_return false
          flexmock(@doc_prjs[2]).should_receive(:query_close).never
          @doc.can_close?(true).should == false
        end
        
      end
      
    end
    
    context 'when the argument is false' do
      
      before do
        @doc_prjs = [@doc.own_project(@world.default_environment)]
        @projects.each do |pr|
          @doc.create_view pr.environment
          @doc_prjs << @doc.own_project(pr.environment)
        end
      end
      
      it 'doesn\'t call the document\'s #query_close method' do
        flexmock(@doc).should_receive(:query_close).never
        @doc.can_close?(false)
      end
      
      it 'returns true if the #query_close method of each of the document\'s own projects return true' do
        @doc_prjs.each do |pr| 
          flexmock(pr).should_receive(:query_close).once.and_return true
        end
        @doc.can_close?(false).should == true
      end
      
      it 'returns false as soon as one of the project\'s #query_close method returns false' do
        flexmock(@doc_prjs[0]).should_receive(:query_close).once.and_return true
        flexmock(@doc_prjs[1]).should_receive(:query_close).once.and_return false
        flexmock(@doc_prjs[2]).should_receive(:query_close).never
        @doc.can_close?(false).should == false
      end
      
    end
    
  end
  
  context 'when an environment is closed' do
    
    before do
      @other_env = Ruber::World::Environment.new nil
    end
    
    context 'if there\'s a document project living in that environment' do
      
      before do
        @doc.own_project @other_env
      end
      
      it 'calls the #close method of the document project living in the environment passing true as argument' do
        flexmock(@doc.own_project(@other_env)).should_receive(:close).once.with(true)
        @other_env.close
      end
      
      it 'removes the environment from the list' do
        @other_env.close
        @doc.instance_variable_get(:@projects).should_not include(@other_env)
      end
      
    end
    
    context 'if there isn\'t a document project living in that environment' do
      
      it 'does nothing' do
        lambda{@other_env.close}.should_not raise_error
      end
      
    end
    
  end
  
end
