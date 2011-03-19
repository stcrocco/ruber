require 'spec/framework'
require 'spec/common'

require 'ruber/world/environment'

require 'tmpdir'

describe Ruber::World::Environment do
  
  before(:all) do
    #the following line is only needed until world is added to the list of
    #components loaded by the application
    Ruber[:components].load_component 'world' unless Ruber[:world]
  end
  
  before do
    @env = Ruber::World::Environment.new nil
    #without this, the tab widgets become visible, slowing down tests noticeably
    flexmock(@env.tab_widget).should_receive(:show).by_default
    @env.activate
  end
  
  it 'inherits from Qt::Object' do
    Ruber::World::Environment.ancestors.should include(Qt::Object)
  end
  
  it 'includes the Activable module' do
    Ruber::World::Environment.ancestors.should include(Ruber::Activable)
  end
  
  describe '.new' do
    
    context 'when the first argument is a Project' do
      
      before do
        @file = File.join Dir.tmpdir, 'environment_new_test'
        @project = Ruber::Project.new @file, "Environment New Test"
      end
      
      it 'makes the new environment child of the second argument' do
        obj = Qt::Object.new
        env = Ruber::World::Environment.new @project, obj
        env.parent.should == obj
      end

      it 'adds the project to the environment' do
        env = Ruber::World::Environment.new @project
        env.project.should == @project
      end
      
      it 'makes the project child of the new enviroment' do
        env = Ruber::World::Environment.new @project
        @project.parent.should == env
      end
      
    end
    
    context 'when the first argument is nil' do
      
      it 'makes the new enviroment child of the second argument' do
        obj = Qt::Object.new
        env = Ruber::World::Environment.new nil, obj
        env.parent.should == obj
      end
      
      it 'creates an environment having no project associated with it' do
        env = Ruber::World::Environment.new nil
        env.project.should be_nil
      end
      
    end
    
    it 'associates a parentless tab widget with the environment' do
      env = Ruber::World::Environment.new nil
      env.tab_widget.should be_a(KDE::TabWidget)
      env.tab_widget.parent.should be_nil
    end
    
    it 'creates an hint solver' do
      env = Ruber::World::Environment.new nil
      hint_solver = env.instance_variable_get(:@hint_solver)
      hint_solver.should be_a(Ruber::World::HintSolver)
    end
    
    it 'deactivates the environment' do
      env = Ruber::World::Environment.new nil
      env.should_not be_active
    end
    
    it 'hides the tab widget' do
      env = Ruber::World::Environment.new nil
      env.tab_widget.should be_hidden
    end
    
  end
  
  describe '#editor_for!' do
    
    before do
      @solver = @env.instance_variable_get :@hint_solver
    end
    
    it 'uses the Ruber::World::Environment::DEFAULT_HINTS as default hints argument' do
      doc = Ruber::Document.new
      view = doc.create_view
      flexmock(@solver).should_receive(:find_editor).with(doc, Ruber::World::Environment::DEFAULT_HINTS).once.and_return(view)
      @env.editor_for!(doc)
    end
    
    it 'merges the given hints with the default ones' do
      doc = Ruber::Document.new
      view = doc.create_view
      exp_hints = Ruber::World::Environment::DEFAULT_HINTS.merge(:create_if_needed => false)
      flexmock(@solver).should_receive(:find_editor).with(doc, exp_hints).once.and_return(view)
      @env.editor_for!(doc, :create_if_needed => false)
    end
    
    context 'when the first argument is a document' do
      
      before do
        @doc = Ruber::Document.new
      end
            
      context 'when the tab widget contains an editor for the given document matching the given hints' do
      
        it 'returns that editor' do
          view = @doc.create_view
          flexmock(@solver).should_receive(:find_editor).with(@doc, Hash).once.and_return(view)
          @env.editor_for!(@doc, {}).should == view
        end
        
      end
      
      context 'when the tab widget does not contain an editor for the given document matching the given hints' do
        
        context 'if the create_if_needed hint is false' do
        
          it 'returns nil' do
            flexmock(@solver).should_receive(:find_editor).with(@doc, Hash).and_return nil
            @env.editor_for!(@doc, {:create_if_needed => false}).should be_nil
          end
          
        end
        
        context 'if the create_if_needed hint is true' do
          
          it 'creates and returns a new editor' do
            @env.editor_for!(@doc, :create_if_needed => true).should be_a(Ruber::EditorView)
          end
          
          it 'places the new editor in the position returned by the hint solver #place_editor method if it is not nil' do
            old_editor = @doc.create_view
            pane = Ruber::Pane.new old_editor
            tabs = @env.tab_widget
            tabs.add_tab pane, 'Tab'
            tabs.current_index = 0
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :current_tab}
            pane.splitter.widget(1).view.should == editor
          end
          
          it 'respects the :split hint' do
            old_editor = @doc.create_view
            pane = Ruber::Pane.new old_editor
            tabs = @env.tab_widget
            tabs.add_tab pane, 'Tab'
            tabs.current_index = 0
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :current_tab, :split => :vertical}
            pane.splitter.orientation.should == Qt::Vertical
          end
          
          it 'places the new editor in a new tab if the hint solver\'s #place_editor method returns nil' do
            old_editor = @doc.create_view
            pane = Ruber::Pane.new old_editor
            tabs = @env.tab_widget
            tabs.add_tab pane, 'Tab'
            tabs.current_index = 0
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :newt_tab}
            new_pane = tabs.widget(1)
            new_pane.view.should == editor
          end
          
          it 'uses the document name as tab\'s caption when placing the editor in a new tab' do
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :newt_tab}
            @env.tab_widget.tab_text(0).should == @doc.document_name
          end
          
          it 'uses the document icon as tab\'s icon when placing the editor in a new tab' do
            doc = Ruber::Document.new __FILE__
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :newt_tab}
            exp_image = @doc.icon.pixmap(Qt::Size.new(16,16)).to_image
            @env.tab_widget.tab_icon(0).pixmap(Qt::Size.new(16,16)).to_image.should == exp_image
          end
          
          it 'uses the document\'s name as label for the view if the document is not associated with a file' do
            view = @env.editor_for!(@doc, :create_if_needed => true)
            view.parent.label.should == @doc.document_name
          end
          
          it 'uses the file name of the document as label for the view if the document is associated with a local file' do
            doc = Ruber::Document.new __FILE__
            view = @env.editor_for!(doc, :create_if_needed => true)
            view.parent.label.should == doc.path
          end
          
          it 'uses the URL of the document as label for the view if the document is associated with a remote file' do
            doc = Ruber::Document.new
            url = KDE::Url.new 'http://xyz.org/abc'
            flexmock(doc).should_receive(:url).and_return url
            view = @env.editor_for!(doc, :create_if_needed => true)
            view.parent.label.should == doc.url.pretty_url
          end
          
          it 'adds the new document to the tooltip of the tab' do
            docs = 3.times.map{Ruber::Document.new}
            docs.each{|d| @env.editor_for! d, :new=>:current_tab}
            exp = [docs[0], docs[2], docs[1]].map{|d| d.document_name}.join "\n"
            @env.tab_widget.tab_tool_tip(0).should == exp
          end
          
          it 'doesn\'t repeat a document multiple times in the tool tip of the tab' do
            docs = 3.times.map{Ruber::Document.new}
            docs.each{|d| @env.editor_for! d, :new=>:current_tab}
            exp = [docs[0], docs[2], docs[1]].map{|d| d.document_name}.join "\n"
            @env.editor_for! docs[0], :existing => :never, :new => :current_tab
            @env.tab_widget.tab_tool_tip(0).should == exp
          end
          
          it 'doesn\'t insert the new editor in a pane if the :show hint is false' do
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :show => false}
            editor.parent.should be_nil
          end
          
        end
        
      end
      
    end
    
    context 'when the first argument is a string' do
      
      after do
        @doc.close if @doc
      end
      
      context 'and the world contains a document associated with the given file' do
                
        it 'returns an editor for the document' do
          @doc = Ruber[:world].document __FILE__
          editor = @env.editor_for! __FILE__
          editor.document.path.should == __FILE__
        end
        
        it 'doesn\'t create a new document' do
          @doc = Ruber[:world].document __FILE__
          editor = @env.editor_for! __FILE__
          editor.document.should == @doc
        end
        
      end
      
      context 'and the world doesn\'t contain a document associated with the given file' do
        
        it 'returns an editor for the document' do
          editor = @env.editor_for! __FILE__
          editor.document.path.should == __FILE__
          @doc = editor.document
        end
        
      end
      
    end
    
    context 'when the first argument is an URL' do
      
      after do
        @doc.close if @doc
      end
      
      context 'and the world contains a document associated with the given file' do
        
        it 'returns an editor for the document' do
          @doc = Ruber[:world].document __FILE__
          editor = @env.editor_for! KDE::Url.new(__FILE__)
          editor.document.path.should == __FILE__
        end
        
        it 'doesn\'t create a new document' do
          @doc = Ruber[:world].document __FILE__
          editor = @env.editor_for! KDE::Url.new(__FILE__)
          editor.document.should == @doc
        end
        
      end
      
      context 'and the world doesn\'t contain a document associated with the given file' do
        
        it 'returns an editor for the document' do
          editor = @env.editor_for! KDE::Url.new(__FILE__)
          editor.document.path.should == __FILE__
          @doc = editor.document
        end
        
      end
      
    end
    
  end
  
  describe '#tab' do
    
    before do
      @views = [
        @env.editor_for!(__FILE__),
        @env.editor_for!(__FILE__, :existing => :never, :new => :current_tab),
        @env.editor_for!(__FILE__, :existing => :never, :new => :new_tab)
      ]
    end
    
    context 'when the argument is a Pane' do
      
      it 'returns the toplevel pane containing the argument' do
        view = @env.editor_for! __FILE__, :existing => :never, :new => @views[1],
            :split => :vertical
        pane = view.parent
        @env.tab(pane).should == @env.tab_widget.widget(0)
      end
      
      it 'returns the pane itself if it is a toplevel pane' do
        toplevel = @views[2].parent
        @env.tab(toplevel).should == toplevel
      end
      
      it 'returns nil if the toplevel pane doesn\'t belong to the tab widget associated with the environment' do
        doc = Ruber[:world].document __FILE__
        view = doc.create_view
        pane = Ruber::Pane.new view
        @env.tab(pane).should be_nil
      end
      
    end
    
    context 'when the argument is a view' do
      
      it 'returns the toplevel view containing the argument' do
        view = @env.editor_for! __FILE__, :existing => :never, :new => @views[1],
            :split => :vertical
        @env.tab(view).should == @env.tab_widget.widget(0)
      end
      
      it 'returns the parent of the view if it is a toplevel pane' do
        toplevel = @views[2].parent
        @env.tab(@views[2]).should == toplevel
      end
      
      it 'returns nil if the toplevel pane doesn\'t belong to the tab widget associated with the environment' do
        doc = Ruber[:world].document __FILE__
        view = doc.create_view
        pane = Ruber::Pane.new view
        @env.tab(view).should be_nil
      end
      
      it 'returns nil if the view isn\'t in a pane' do
        doc = Ruber[:world].document __FILE__
        view = doc.create_view
        @env.tab(view).should be_nil
      end
      
    end
    
  end
  
  describe 'the value returned by #documents' do
    
    it 'is DocumentList' do
      @env.documents.should be_a(Ruber::World::DocumentList)
    end
    
    it 'contains all the documents associated with a view in the environment' do
      doc1 = Ruber[:world].new_document
      doc2 = @env.editor_for!( __FILE__).document
      @env.editor_for! doc1
      @env.documents.should == [doc2, doc1]
    end
    
    it 'doesn\'t contain documents which have been closed'
    
  end
  
  describe 'the list returned by #views' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new}
      @editors = []
      @editors << @env.editor_for!(@docs[0])
      @editors << @env.editor_for!(@docs[1], :new => :current_tab)
      @editors << @env.editor_for!(@docs[2], :new => :current_tab)
      @editors << @env.editor_for!(@docs[0], :existing => :never, :new => :new_tab)
      @editors << @env.editor_for!(@docs[2], :existing => :never, :new => :new_tab)
    end
    
    context 'when #views is called without arguments' do
      
      it 'contains all the views in the environment' do
        @env.views.sort_by{|v| v.object_id}.should == @editors.sort_by{|v| v.object_id}
      end
      
      it 'contains the views in activation order, from most recently activated to
      least recently activated' do
        @env.activate_editor @editors[1]
        @env.activate_editor @editors[4]
        @env.activate_editor @editors[2]
        exp = [@editors[2], @editors[4], @editors[1], @editors[0], @editors[3]]
        @env.views.should == exp
      end
      
    end
    
    context 'when #views is called with a document as argument' do
      
      it 'ctonains all the views in the environment which are associated with the given document' do
        exp = @editors.select{|v| v.document == @docs[0]}.sort_by{|v| v.object_id}
        @env.views(@docs[0]).sort_by{|v| v.object_id}.should == exp
      end
      
      it 'contains the views in activation order, from most recently activated to
      least recently activated' do
        @env.activate_editor @editors[3]
        @env.views(@docs[0]).should == [@editors[3], @editors[0]]
      end
      
    end
    
  end
  
  describe '#activate_editor' do
    
    before do
      clients = Ruber[:main_window].gui_factory.clients
      clients.each{|c| Ruber[:main_window].gui_factory.remove_client c unless c.is_a? Ruber::MainWindow}
      @env.activate
      @docs = 3.times.map{Ruber::Document.new}
      @editors = []
      @editors << @env.editor_for!(@docs[0])
      @editors << @env.editor_for!(@docs[1], :new => :current_tab)
      @editors << @env.editor_for!(@docs[2], :new => :current_tab)
      @editors << @env.editor_for!(@docs[0], :existing => :never, :new => :new_tab)
      @editors << @env.editor_for!(@docs[2], :existing => :never, :new => :new_tab)
    end
    
    it 'raises RuntimeError if the environment is not active' do
      @env.deactivate
      lambda{@env.activate_editor @editors[0]}.should raise_error(RuntimeError, "Not the active environment")
    end
    
    it 'doesn\'t raise RuntimeError if the environment is not active if the argument is nil' do
      @env.deactivate
      lambda{@env.activate_editor nil}.should_not raise_error(RuntimeError, "Not the active environment")
    end
    
    context 'when there\'s no active editor' do
      
      it 'merges the editor\'s GUI with the main window\'s' do
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(factory).should_receive(:add_client).with(@editors[2].send(:internal)).once
        @env.activate_editor @editors[2]
      end
      
      it 'marks the view as last activated' do
        @env.activate_editor @editors[4]
        @env.views[0].should == @editors[4]
        @env.activate_editor @editors[2]
        @env.views[0].should == @editors[2]
      end
      
      it 'changes the label and icon of the tab to match those of the document corresponding to the activated editor' do
        @env.activate_editor @editors[2]
        @env.tab_widget.tab_text(0).should == @editors[2].document.document_name
        exp_image = @editors[2].document.icon.pixmap(Qt::Size.new(16,16)).to_image
        @env.tab_widget.tab_icon(0).pixmap(Qt::Size.new(16,16)).to_image.should      
      end
      
      it 'activates the document associated with the activate editor' do
        flexmock(@editors[2].document).should_receive(:activate).once
        @env.activate_editor @editors[2]
      end
      
      it 'emits the active_editor_changed signal passing the new active view as argument' do
        test = flexmock{|m| m.should_receive(:active_editor_changed).with(@editors[2]).once}
        @env.connect(SIGNAL('active_editor_changed(QWidget*)')){|w| test.active_editor_changed w}
        @env.activate_editor @editors[2]
      end
      
      it 'makes the tab containing the ativated editor current' do
        @env.activate_editor @editors[2]
        @env.tab_widget.current_index.should == 0
        @env.activate_editor @editors[4]
        @env.tab_widget.current_index.should == 2
      end
      
      it 'returns the new active editor' do
        @env.activate_editor(@editors[2]).should == @editors[2]
      end
        
      it 'does nothing if the argument is nil' do
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(factory).should_receive(:add_client).never
        flexmock(@editors[2].document).should_receive(:activate).never
        flexmock(@env).should_receive(:emit).never
        @env.activate_editor nil
      end
      
    end
    
    context 'when there\'s an active editor' do

      before do
        @env.activate_editor @editors[3]
      end
      
      it 'deactivates the currently active editor' do
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(factory).should_receive(:remove_client).with(@editors[3].send(:internal)).once
        @env.activate_editor @editors[2]
      end
      
      it 'deactivates the document corresponding to the previously active editor' do
        flexmock(@editors[3].document).should_receive(:deactivate).once
        @env.activate_editor @editors[2]
      end
      
      it 'merges the editor\'s GUI with the main window\'s' do
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(factory).should_receive(:add_client).with(@editors[2].send(:internal)).once
        @env.activate_editor @editors[2]
      end
      
      it 'marks the view as last activated' do
        @env.activate_editor @editors[4]
        @env.views[0].should == @editors[4]
        @env.activate_editor @editors[2]
        @env.views[0].should == @editors[2]
      end
      
      it 'changes the label and icon of the tab to match those of the document corresponding to the activated editor' do
        @env.activate_editor @editors[2]
        @env.tab_widget.tab_text(0).should == @editors[2].document.document_name
        exp_image = @editors[2].document.icon.pixmap(Qt::Size.new(16,16)).to_image
        @env.tab_widget.tab_icon(0).pixmap(Qt::Size.new(16,16)).to_image.should      
      end
      
      it 'activates the document associated with the activate editor' do
        flexmock(@editors[2].document).should_receive(:activate).once
        @env.activate_editor @editors[2]
      end
      
      it 'makes the tab containing the ativated editor current' do
        @env.activate_editor @editors[2]
        @env.tab_widget.current_index.should == 0
        @env.activate_editor @editors[4]
        @env.tab_widget.current_index.should == 2
      end
      
      it 'emits the active_editor_changed signal passing the new active view as argument' do
        test = flexmock{|m| m.should_receive(:active_editor_changed).with(@editors[2]).once}
        @env.connect(SIGNAL('active_editor_changed(QWidget*)')){|w| test.active_editor_changed w}
        @env.activate_editor @editors[2]
      end
      
      it 'returns the new active editor' do
        @env.activate_editor(@editors[2]).should == @editors[2]
      end
      
      it 'does nothing if the given editor was already active' do
        @env.activate_editor @editors[2]
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(@env).should_receive(:deactivate_editor).never
        flexmock(factory).should_receive(:add_client).never
        flexmock(@editors[3].document).should_receive(:deactivate).never
        flexmock(@editors[2].document).should_receive(:activate).never
        flexmock(@env).should_receive(:emit).never
        @env.activate_editor @editors[2]
      end
      
      it 'doesn\'t attempt to merge the argument\'s GUI if the argument is nil' do
        @env.activate_editor @editors[2]
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(factory).should_receive(:remove_client).with(@editors[2].send(:internal)).once
        flexmock(factory).should_receive(:add_client).never
        flexmock(@editors[2].document).should_receive(:deactivate).once
        mk = flexmock{|m| m.should_receive(:active_editor_changed).once.with(nil)}
        @env.connect(SIGNAL('active_editor_changed(QWidget*)')){|v| mk.active_editor_changed v}
        @env.activate_editor nil
      end
      
    end
    
  end
  
  describe '#deactivate' do
    
    before do
      @doc = Ruber::Document.new
      @editor = @env.editor_for! @doc
      @env.activate
    end
    
    it 'hides the tab widget' do
      flexmock(@env.tab_widget).should_receive(:hide).once
      @env.deactivate
    end
    
    it 'deactivates the active editor if it exists' do
      @env.activate_editor @editor
      flexmock(@env).should_receive(:deactivate_editor).with(@editor).once
      @env.deactivate
    end
    
    it 'behaves like Activable#deactivate' do
      mk = flexmock{|m| m.should_receive(:deactivated).once}
      @env.connect(SIGNAL(:deactivated)){mk.deactivated}
      @env.deactivate
      @env.should_not be_active
    end
    
  end
  
  describe '#activate' do

    before do
      @doc = Ruber::Document.new
      @env.activate
      @env.deactivate
    end
    
    it 'shows the tab widget' do
      flexmock(@env.tab_widget).should_receive(:show).once
      @env.activate
    end
    
    it 'activates the last activated editor' do
      editors = 3.times.map{@env.editor_for! @doc, :existing => :never}
      @env.activate
      @env.activate_editor editors[1]
      @env.deactivate
      flexmock(@env).should_receive(:activate_editor).with(editors[1]).once
      @env.activate
    end
    
    it 'makes all documents inactive if there is no editor in the environment' do
      flexmock(@env).should_receive(:activate_editor).with(nil).once
      @env.activate
    end
    
    it 'behaves like Activable#activate' do
      mk = flexmock{|m| m.should_receive(:activated).once}
      @env.connect(SIGNAL(:activated)){mk.activated}
      @env.activate
      @env.should be_active
    end
    
  end
  
  describe '#active_editor' do
    
    context 'if the environment is active' do
      
      before do
        @env.activate
      end
      
      it 'returns nil if there\'s no active editor' do
        @env.active_editor.should be_nil
      end
      
      it 'returns the active editor if it exists' do
        doc = Ruber::Document.new
        editors = 3.times.map{@env.editor_for! doc, :existing => :never}
        @env.activate_editor editors[1]
        @env.active_editor.should == editors[1]
      end
      
    end
    
    context 'if the environment is not active' do
      
      it 'always returns nil' do
        @env.deactivate
        @env.active_editor.should be_nil
        @env.activate
        doc = Ruber::Document.new
        editors = 3.times.map{@env.editor_for! doc, :existing => :never}
        @env.activate_editor editors[1]
        @env.deactivate
        @env.active_editor.should be_nil
      end
      
    end
    
  end
  
  describe 'when an editor is closed' do
    
    before do
      @doc = Ruber::Document.new
    end

    context 'if the view is the active one' do
      
      before do
        @views = @views = 4.times.map{|i| @env.editor_for! @doc, :existing => :never}
      end
      
      it 'deactivates it' do
        @env.activate_editor @views[2]
        @env.activate_editor @views[3]
        @env.activate_editor @views[0]
        @env.activate_editor @views[1]
        gui_factory = Ruber[:main_window].gui_factory
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return gui_factory
        flexmock(gui_factory).should_receive(:remove_client).with(@views[1].send(:internal)).once
        @views[1].close
      end
      
    end
    
    context 'if there are other editors in the same tab' do
      
      before do
        @views = 4.times.map{|i| @env.editor_for! @doc, :existing => :never, :new =>  (i == 3 ? :new_tab : :current_tab) }
      end
      
      it 'removes the view from the tab' do
        pane = @env.tab_widget.widget 0
        @views[1].close
        pane.should_not include(@views[1])
      end
      
      it 'gives focus to view which previously had focus in the same tab, if the view ha d focus' do
        pending "Implement later"
        @views[2].set_focus
        @views[1].set_focus
        flexmock(@views[1]).should_receive(:is_active_window).and_return true
        flexmock(@views[2]).should_receive(:set_focus).once
      end
            
    end
    
  end
  
  describe '#close_editor' do
    
    before do
      @doc = Ruber::Document.new
    end
    
    context 'if the given editor is the last editor associated with the document' do
      
      it 'closes the document, passing the second argument to Document#close' do
        editor = @env.editor_for! @doc
        flexmock(@doc).should_receive(:close).once.with(false)
        @env.close_editor editor, false
      end

    end
    
    context 'if the given editor is not the only one associated with the document' do
      
      it 'only closes the editor' do
        editor = @env.editor_for! @doc
        other_editor = @doc.create_view
        flexmock(@doc).should_receive(:close).never
        flexmock(editor).should_receive(:close).once
        @env.close_editor editor, false
      end
      
    end
    
  end
  
  describe '#close' do
    
    before do
      @docs = 4.times.map{Ruber::Document.new}
      @env_views = []
      @env_views += 2.times.map{@env.editor_for! @docs[0], :existing => :never}
      @env_views += 3.times.map{@env.editor_for! @docs[1], :existing => :never}
      @env_views << @env.editor_for!(@docs[2])
      @other_views = [@docs[2].create_view, @docs[3].create_view]
    end
    
    it 'emits the closing signal passing itself as argument' do
      mk = flexmock{|m| m.should_receive(:env_closing).once.with(@env)}
      @env.connect(SIGNAL('closing(QObject*)')){|e| mk.env_closing e}
      @env.close
    end
    
    it 'deactivates itself' do
      flexmock(@env).should_receive(:deactivate).once
      @env.close
    end
    
    it 'calls MainWindow#save_documents passing the list of documents all of whose views are in the environment' do
      flexmock(Ruber[:main_window]).should_receive(:save_documents).with( [@docs[0], @docs[1]]).once
      @env.close
    end
    
    context 'when MainWindow#save_documents returns true' do
      
      before do
        flexmock(Ruber[:main_window]).should_receive(:save_documents).and_return true
      end
      
      it 'closes all the documents whose views are all contained in the environment without asking' do
        2.times{|i| flexmock(@docs[i]).should_receive(:close).with(false).once}
        2.upto(3){|i| flexmock(@docs[i]).should_receive(:close).never}
        @env.close
      end
      
      it 'closes all the views in the environment whose documents have views not associated with the enviroment' do
        @env_views[3..-1].each{|v| flexmock(v).should_receive(:close).once}
        @env.close
      end
      
      it 'returns true' do
        @env.close.should be_true
      end
      
    end
    
    context 'when MainWindow#save_documents returns false' do
      
      before do
        flexmock(Ruber[:main_window]).should_receive(:save_documents).and_return false
        flexmock(@docs[1]).should_receive(:modified?).and_return true
      end
      
      it 'only closes those document not having views outside the environment which aren\'t modified' do
        flexmock(@docs[0]).should_receive(:close).once.with(false)
        flexmock(@docs[1]).should_receive(:close).never
        @env.close
      end
      
      it 'closes all the views in the environment whose documents have views not associated with the enviroment or whose documents are modified' do
        @env_views[1..-1].each{|v| flexmock(v).should_receive(:close).once}
        @env.close
      end
      
      it 'returns false' do
        @env.close.should be_false
      end
      
    end
    
  end
  
  context 'when the associated project is closed' do
    
    it 'calls the close method' do
      file = File.join Dir.tmpdir, 'environment_new_test'
      project = Ruber::Project.new file, "Environment New Test"
      env = Ruber::World::Environment.new project
      flexmock(env).should_receive(:close).once
      project.close false
    end
    
  end
  
end