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
    Ruber[:world].close_all(:documents, :discard)
    @env = Ruber::World::Environment.new nil
    #without this, the tab widgets become visible, slowing down tests noticeably
    flexmock(@env.tab_widget).should_receive(:show).by_default
    @env.activate
  end
  
  after do
    @env.dispose
  end
  
  it 'inherits from Qt::Object' do
    Ruber::World::Environment.ancestors.should include(Qt::Object)
  end
  
  it 'includes the Activable module' do
    Ruber::World::Environment.ancestors.should include(Ruber::Activable)
  end
  
  shared_examples_for 'when adding a view' do
    
    before do
      @doc = Ruber[:world].new_document
      @view = @doc.create_view
    end
    
    it 'inserts the view in the list of views contained in the environment' do
      @add_view_proc.call @view
      @env.views.should include(@view)
    end
    
    it 'adds the document to the list of documents associated with the environment' do
      @add_view_proc.call @view
      @env.documents.should include(@view.document)
    end
    
    it 'doesn\'t add the document to the list if the list already includes it' do
      @env.editor_for! @doc
      @add_view_proc.call @view
      @env.documents.select{|doc| doc == @doc}.count.should == 1
    end
    
    it 'sets the text of the label associated with the view to the path of the document, if the document is associated with a file' do
      @doc = Ruber[:world].document __FILE__
      @view = @doc.create_view
      @add_view_proc.call @view
      @view.parent.label.should == @doc.path
    end
    
    it 'sets the text of the label associated with the view to the documen name of the document, if the document is associated with a file' do
      @add_view_proc.call @view
      @view.parent.label.should == @doc.document_name
    end
    
    it 'uses the URL of the document as label for the view if the document is associated with a remote file' do
      url = KDE::Url.new 'http://xyz.org/abc'
      flexmock(@doc).should_receive(:url).and_return url
      @add_view_proc.call @view
      @view.parent.label.should == @doc.url.pretty_url
    end
    
    it 'updates the tool tip of the tab containing the view' do
      doc = Ruber[:world].new_document
      @add_view_proc.call @view
      @env.editor_for! doc, :new => @view
      exp = @doc.document_name + "\n" + doc.document_name
      @env.tab_widget.tab_tool_tip(0).should == exp
    end
    
    it 'doesn\'t repeat a document multiple times in the tool tip of the tab' do
      doc = Ruber[:world].new_document
      view = @env.editor_for! doc, :new => :current_tab
      @add_view_proc.call @view
      @env.editor_for! @doc, :existing => :never, :new => :current_tab
      exp = [doc, @doc].map{|d| d.document_name}.join "\n"
      @env.tab_widget.tab_tool_tip(0).should == exp
    end

    it 'reacts to the view getting focus' do
      @add_view_proc.call @view
      @view.instance_eval{emit focus_in(self)}
      @env.active_editor.should == @view
    end
    
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
      
      it 'doesn\'t create empty documents' do
        env = Ruber::World::Environment.new @project
        env.views.should be_empty
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
    
    it 'swtiches the document mode of the tab widget on' do
      env = Ruber::World::Environment.new nil
      env.tab_widget.document_mode.should be_true
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
    
    it 'creates a view for a new, empty document with object name default_document' do
      env = Ruber::World::Environment.new nil
      env.views.count.should == 1
      env.views[0].document.text.should == ''
      env.views[0].document.object_name.should == 'default_document'
    end
        
  end
  
  describe '#editor_for!' do
    
    before do
      @solver = @env.instance_variable_get :@hint_solver
    end
    
    it 'uses the Ruber::World::Environment::DEFAULT_HINTS as default hints argument' do
      doc = Ruber[:world].new_document
      view = doc.create_view
      flexmock(@solver).should_receive(:find_editor).with(doc, Ruber::World::Environment::DEFAULT_HINTS).once.and_return(view)
      @env.editor_for!(doc)
    end
    
    it 'merges the given hints with the default ones' do
      doc = Ruber[:world].new_document
      view = doc.create_view
      exp_hints = Ruber::World::Environment::DEFAULT_HINTS.merge(:create_if_needed => false)
      flexmock(@solver).should_receive(:find_editor).with(doc, exp_hints).once.and_return(view)
      @env.editor_for!(doc, :create_if_needed => false)
    end
    
    it 'closes the default document if it\'s pristine' do
      @env.editor_for! __FILE__
      Ruber[:world].documents.find{|d| d.object_name == 'default_document'}.should be_nil
    end
    
    it 'doesn\'t close the default environment if the first argument is the default document itself' do
      @env.editor_for! Ruber[:world].documents.find{|d| d.object_name == "default_document"}
      Ruber[:world].documents.find{|d| d.object_name == "default_document"}.should_not be_nil
    end
    
    it 'doesn\'t close the default document if it is not pristine' do
      flexmock(@env.documents[0]).should_receive(:pristine?).and_return false
      @env.editor_for! __FILE__
      Ruber[:world].documents.find{|d| d.object_name == 'default_document'}.should_not be_nil
    end
    
    it 'doesn\'t close the default document if it has no view associated with it' do
      default_doc = Ruber[:world].documents.find{|d| d.object_name == 'default_document'}
      default_doc.views[0].close
      @env.editor_for! __FILE__
      Ruber[:world].documents.should include(default_doc)
    end
    
    it 'doesn\'t close the default document if it has more than one view associated with it' do
      default_doc = Ruber[:world].documents.find{|d| d.object_name == 'default_document'}
      default_doc.create_view
      @env.editor_for! __FILE__
      Ruber[:world].documents.should include(default_doc)
    end
    
    context 'when the first argument is a document' do
      
      before do
        @doc = Ruber[:world].new_document
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
          
          before do
            @add_view_proc = lambda do |view|
              flexmock(view.document).should_receive(:create_view).and_return view
              @env.editor_for! view.document, :existing => :never, :new => :new_tab
            end
          end
          
          it 'creates and returns a new editor' do
            @env.editor_for!(@doc, :create_if_needed => true).should be_a(Ruber::EditorView)
          end
          
          it 'places the new editor in the position returned by the hint solver #place_editor method if it is not nil' do
            old_editor = @doc.create_view
            pane = @env.send :create_tab, old_editor
            @env.send :add_editor, old_editor, pane
#             pane = Ruber::Pane.new old_editor
            tabs = @env.tab_widget
            tabs.add_tab pane, 'Tab'
            tabs.current_index = 0
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :current_tab}
            pane.splitter.widget(1).view.should == editor
          end
          
          it 'respects the :split hint' do
            old_editor = @doc.create_view
            pane = @env.send :create_tab, old_editor
            @env.send :add_editor, old_editor, pane
            tabs = @env.tab_widget
            tabs.add_tab pane, 'Tab'
            tabs.current_index = 0
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :current_tab, :split => :vertical}
            pane.splitter.orientation.should == Qt::Vertical
          end
          
          it 'places the new editor in a new tab if the hint solver\'s #place_editor method returns nil' do
            old_editor = @doc.create_view
            pane = @env.send :create_tab, old_editor
            @env.send :add_editor, old_editor, pane
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
            doc = Ruber[:world].document __FILE__
            editor = @env.editor_for! @doc, {:existing => :never, :create_if_needed => true, :new => :newt_tab}
            exp_image = @doc.icon.pixmap(Qt::Size.new(16,16)).to_image
            @env.tab_widget.tab_icon(0).pixmap(Qt::Size.new(16,16)).to_image.should == exp_image
          end
          
          it_behaves_like 'when adding a view'

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
      
      it 'returns the toplevel pane containing the argument' do
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
  
  describe '#tabs' do
    
    it 'returns an array containing all the toplevel tabs contained in the environment in order' do
      doc = Ruber[:world].new_document
      3.times{@env.editor_for! doc, :existing => :never}
      tab_widget = @env.tab_widget
      @env.tabs.should == 3.times.map{|i| tab_widget.widget i}
    end
    
    it 'returns an empty array if there is no tab in the tab widget' do
      @env.documents[0].close false
      @env.tabs.should be_empty
    end
    
  end
  
  describe '#documents' do
    
    before do
      @docs = [Ruber::Document.new, Ruber[:world].document(__FILE__)] 
      @env.editor_for! @docs[0]
      @env.editor_for! @docs[1], :existing => :never
    end
    
    it 'returns DocumentList' do
      @env.documents.should be_a(Ruber::World::DocumentList)
    end
    
    it 'returns a list containing all the documents associated with a view in the environment' do
      @env.documents.should == [@docs[0], @docs[1]]
    end
    
    it 'returns a list which doesn\'t contain documents which have been closed' do
      @docs[1].close
      @env.documents.should == [@docs[0]]
    end
    
  end
  
  describe '#views' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new}
      @editors = []
      @editors << @env.editor_for!(@docs[0])
      @editors << @env.editor_for!(@docs[1], :new => :current_tab)
      @editors << @env.editor_for!(@docs[2], :new => :current_tab)
      @editors << @env.editor_for!(@docs[0], :existing => :never, :new => :new_tab)
      @editors << @env.editor_for!(@docs[2], :existing => :never, :new => :new_tab)
    end
    
    context 'when called without arguments' do
      
      it 'returns a list containing all the views in the environment' do
        @env.views.sort_by{|v| v.object_id}.should == @editors.sort_by{|v| v.object_id}
      end
      
      it 'returns a list containing the views in activation order, from most recently activated to
      least recently activated' do
        @env.activate_editor @editors[1]
        @env.activate_editor @editors[4]
        @env.activate_editor @editors[2]
        exp = [@editors[2], @editors[4], @editors[1], @editors[0], @editors[3]]
        @env.views.should == exp
      end
      
      it 'returns a list which doesn\'t contain duplicate arguments if a view is created by splitting another one' do
        @env.views.select{|v| v == @editors[1]}.count.should == 1
      end
      
    end
    
    context 'when called with a document as argument' do
      
      it 'returns a list containing all the views in the environment which are associated with the given document' do
        exp = @editors.select{|v| v.document == @docs[0]}.sort_by{|v| v.object_id}
        @env.views(@docs[0]).sort_by{|v| v.object_id}.should == exp
      end
      
      it 'returns a list containing the views in activation order, from most recently activated to
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
    
    context 'if the environment is not active' do
      
      before do
        @env.deactivate
      end
      
      it 'doesn\'t attempt to merge the view\'s GUI with the main window\'s' do
        factory = Ruber[:main_window].gui_factory
        #MainWindow#gui_factory returns a different ruby object each time, so
        #we can't set a mock on it.
        flexmock(Ruber[:main_window]).should_receive(:gui_factory).and_return factory
        flexmock(factory).should_receive(:add_client).never
        @env.activate_editor @editors[1]
      end
      
      it 'doesn\'t change the active editor' do
        @env.activate_editor @editors[1]
        @env.active_editor.should be_nil
      end
      
      it 'marks the view as last activated' do
        @env.activate_editor @editors[2]
        @env.views[0].should == @editors[2]
      end
      
      it 'changes the current tab index' do
        @env.tab_widget.current_index = 0
        @env.activate_editor @editors[3]
        @env.tab_widget.current_index.should == 1
      end
      
      it 'changes the text and icon of the tab to match those of the editor' do
        @env.tab_widget.set_tab_icon 0, Qt::Icon.new
        @env.tab_widget.set_tab_text 0, "Test"
        @env.activate_editor @editors[1]
        @env.tab_widget.tab_text(0).should == @editors[1].document.document_name
        exp_icon = @editors[1].document.icon.pixmap(Qt::Size.new(16,16)).to_image
        icon = @env.tab_widget.tab_icon(0).pixmap(Qt::Size.new(16,16)).to_image
        exp_icon.should == icon
      end
      
      it 'doesn\'t emit the active_editor_changed signal' do
        mk = flexmock{|m| m.should_receive(:active_editor_changed).never}
        @env.connect(SIGNAL('active_editor_changed(QWidget*)')){mk.active_editor_changed}
        @env.activate_editor @editors[3]
      end
      
      it 'doesn\'t activate the document associated with the editor' do
        flexmock(@editors[2].document).should_receive(:activate).never
        @env.activate_editor @editors[2]
      end
      
    end
    
    it 'gives focus to the editor if #focus_on_editors? returns true' do
      flexmock(@env).should_receive(:focus_on_editors?).and_return(true)
      flexmock(@editors[2]).should_receive(:set_focus).once
      @env.activate_editor @editors[2]
    end
    
    it 'doesn\'t give focus to the editor if #focus_on_editors? returns false' do
      flexmock(@env).should_receive(:focus_on_editors?).and_return(false)
      flexmock(@editors[2]).should_receive(:set_focus).never
      @env.activate_editor @editors[2]
    end
    
  end
  
  describe '#deactivate' do
    
    before do
      @doc = Ruber[:world].new_document
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
      @doc = Ruber[:world].new_document
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
        doc = Ruber[:world].new_document
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
        doc = Ruber[:world].new_document
        editors = 3.times.map{@env.editor_for! doc, :existing => :never}
        @env.activate_editor editors[1]
        @env.deactivate
        @env.active_editor.should be_nil
      end
      
    end
    
  end
  
  describe '#active_document' do
    
    context 'if the environment is active' do
      
      before do
        @env.activate
      end
      
      it 'returns nil if there\'s no active editor' do
        @env.active_document.should be_nil
      end
      
      it 'returns the document associated with the active editor if it exists' do
        doc = Ruber[:world].new_document
        editors = 3.times.map{@env.editor_for! doc, :existing => :never}
        @env.activate_editor editors[1]
        @env.active_document.should == editors[1].document
      end
      
    end
    
    context 'if the environment is not active' do
      
      it 'always returns nil' do
        @env.deactivate
        @env.active_document.should be_nil
        @env.activate
        doc = Ruber[:world].new_document
        editors = 3.times.map{@env.editor_for! doc, :existing => :never}
        @env.activate_editor editors[1]
        @env.deactivate
        @env.active_document.should be_nil
      end
      
    end
    
  end
  
  describe 'when the current tab changes' do
    
    it 'activates the last active editor in the new tab' do
      doc = Ruber[:world].new_document
      views1 = 2.times.map{@env.editor_for! doc, :existing => :never, :new => :current_tab}
      views2 = 2.times.map{@env.editor_for! doc, :existing => :never, :new => :new_tab}
      @env.activate_editor views2[1]
      @env.activate_editor views1[1]
      @env.activate_editor views2[1]
      @env.tab_widget.current_index = 0
      @env.active_editor.should == views1[1]
    end
    
  end
  
  describe 'when an editor is closed' do
    
    before do
      @doc = Ruber[:world].new_document
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
        @views[1].close
        @env.active_editor.should_not == @views[1]
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
      
      it 'activates the previously activated view in the same tab if the view was active' do
        @env.activate_editor @views[2]
        @env.activate_editor @views[1]
        @views[1].close
        @env.active_editor.should == @views[2]
      end
      
      it 'gives focus to view which previously had focus in the same tab, if the closed view was active and focus_on_editors? returns true' do
        flexmock(@env).should_receive(:focus_on_editor?).and_return true
        @env.activate_editor @views[2]
        @env.activate_editor @views[1]
        @views[2].instance_eval{emit focus_in(self)}
        @views[1].instance_eval{emit focus_in(self)}
        flexmock(@views[2]).should_receive(:set_focus).once
        @views[1].close
      end
      
      it 'doesn\'t give focus to view which previously had focus in the same tab, if focus_on_editors? returns false' do
        flexmock(@env).should_receive(:focus_on_editors?).and_return false
        @env.activate_editor @views[2]
        @env.activate_editor @views[1]
        @views[2].instance_eval{emit focus_in(self)}
        @views[1].instance_eval{emit focus_in(self)}
        flexmock(@views[2]).should_receive(:set_focus).never
        @views[1].close
      end
      
    end
    
    context 'if there\'s no other editor in the same tab' do
      
      before do
        @views = 2.times.map{@env.editor_for! @doc, :existing => :never, :new => :new_tab}
      end
      
      it 'removes the tab' do
        @views[1].close
        @env.tab_widget.count.should == 1
      end
      
    end
    
    it 'removes the view from the list of views' do
      views = 3.times.map{@env.editor_for! @doc, :existing => :never}
      views[1].close
      @env.views.should == [views[0], views[2]]
    end
    
  end
  
  describe '#close_editor' do
    
    before do
      @doc = Ruber[:world].new_document
    end
    
    context 'if the given editor is the last editor associated with the document' do
      
      it 'closes the document, passing the second argument to Document#close' do
        editor = @env.editor_for! @doc
        class << @doc
          alias_method :close!, :close
        end
        flexmock(@doc).should_receive(:close).once.with(false)
        @env.close_editor editor, false
        @doc.close!
      end

    end
    
    context 'if the given editor is not the only one associated with the document' do
      
      it 'only closes the editor' do
        class << @doc
          alias_method :close!, :close
        end
        editor = @env.editor_for! @doc
        class << editor
          alias_method :close!, :close
        end
        other_editor = @doc.create_view
        flexmock(@doc).should_receive(:close).never
        flexmock(editor).should_receive(:close).once
        @env.close_editor editor, false
        editor.close!
        @doc.close!
      end
      
    end
    
  end
  
  describe '#close' do
    
    before do
      @docs = 4.times.map{Ruber[:world].new_document}
      @env_views = []
      @env_views += 2.times.map{@env.editor_for! @docs[0], :existing => :never}
      @env_views += 3.times.map{@env.editor_for! @docs[1], :existing => :never}
      @env_views << @env.editor_for!(@docs[2])
      @other_views = [@docs[2].create_view, @docs[3].create_view]
    end
    
    it 'emits the closing signal passing itself as argument' do
      mk = flexmock{|m| m.should_receive(:env_closing).once.with(@env.object_id)}
      @env.connect(SIGNAL('closing(QObject*)')){|e| mk.env_closing e.object_id}
      @env.close
    end
    
    it 'deactivates itself' do
      @env.activate
      @env.close
      @env.should_not be_active
    end
    
    it 'disposes of itself' do
      flexmock(@env).should_receive(:delete_later).once
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
  
  describe '#close_editors' do
    
    before do
      @docs = 3.times.map{Ruber::Document.new}
      @views = []
      @docs.each_with_index do |doc, i|
        views = 3.times.map{@env.editor_for! doc, :existing => :never}
        @views[i] = views
      end
    end
    
    context 'if the second argument is false' do
      
      it 'closes without asking all documents whose views are all to be closed' do
        flexmock(@docs[0]).should_receive(:close).once.with(false)
        flexmock(@docs[2]).should_receive(:close).once.with(false)
        flexmock(@docs[1]).should_receive(:close).never
        @env.close_editors @views[0] + @views[2] + [@views[1][0]], false
      end
      
      it 'closes the editors associated with documents having some views not to be closed' do
        flexmock(@docs[0]).should_receive(:close).once.with(false)
        flexmock(@docs[2]).should_receive(:close).never
        flexmock(@docs[1]).should_receive(:close).never
        other_view = @docs[2].create_view
        (@views[2] + [@views[1][0]]).each do |v| 
          flexmock(v).should_receive(:close).once
        end
        @env.close_editors @views[0] + @views[2] + [@views[1][0]], false
      end
      
    end
    
    context 'if the second argument is true' do
      
      it 'calls MainWindow#save_documents passing all the documents whose views are all to be closed' do
        flexmock(Ruber[:main_window]).should_receive(:save_documents).with([@docs[0], @docs[2]]).once
        @env.close_editors @views[0] + @views[2] + [@views[1][0]], true
      end
      
      context 'if MainWindow#save_documents returns false' do
        
        it 'does nothing' do
          flexmock(Ruber[:main_window]).should_receive(:save_documents).and_return false
          @views.flatten.each{|v| flexmock(v).should_receive(:close).never}
          @docs.each{|d| flexmock(d).should_receive(:close).never}
          @env.close_editors @views[0] + @views[2] + [@views[1][0]], true
        end
        
      end
      
      context 'if MainWindow#save_documents returns true' do
        
        before do
          flexmock(Ruber[:main_window]).should_receive(:save_documents).and_return true
        end
        
        it 'closes without asking all documents whose views are all to be closed' do
          flexmock(@docs[0]).should_receive(:close).once.with(false)
          flexmock(@docs[2]).should_receive(:close).once.with(false)
          flexmock(@docs[1]).should_receive(:close).never
          @env.close_editors @views[0] + @views[2] + [@views[1][0]], true
        end
        
        it 'closes the editors associated with documents having some views not to be closed' do
          flexmock(@docs[0]).should_receive(:close).once.with(false)
          flexmock(@docs[2]).should_receive(:close).never
          flexmock(@docs[1]).should_receive(:close).never
          other_view = @docs[2].create_view
          (@views[2] + [@views[1][0]]).each do |v| 
            flexmock(v).should_receive(:close).once
          end
          @env.close_editors @views[0] + @views[2] + [@views[1][0]], true
        end
        
      end
      
    end
    
  end
  
  describe '#display_document' do
    
    before do
      @doc = Ruber[:world].new_document
    end
    
    it 'retrieves an editor for the given document according to the hints' do
      ed = @env.editor_for! @doc
      hints = {:existing => :always, :strategy => :last}
      flexmock(@env).should_receive(:editor_for!).with(@doc, hints).once.and_return ed
      @env.display_document @doc, hints
    end
    
    it 'activates the editor' do
      ed = @env.editor_for! @doc
      hints = {:existing => :always, :strategy => :last}
      @env.display_document @doc, hints
      @env.active_editor.should == ed
    end
    
    it 'moves the cursor to the line and column corresponding to the :line and :column hints' do
      ed = @env.editor_for! @doc
      flexmock(ed).should_receive(:go_to).with(10, 6).once
      hints = {:existing => :always, :strategy => :last, :line => 10, :column => 6}
      @env.display_document @doc, hints
    end
    
    it 'uses 0 as column hint if the line hint is given and the column hint is not' do
      ed = @env.editor_for! @doc
      flexmock(ed).should_receive(:go_to).with(10, 0).once
      hints = {:existing => :always, :strategy => :last, :line => 10}
      @env.display_document @doc, hints
    end
    
    it 'doesn\'t move the cursor if the line hint is not given' do
      ed = @env.editor_for! @doc
      flexmock(ed).should_receive(:go_to).never
      hints = {:existing => :always, :strategy => :last}
      @env.display_document @doc, hints
      hints[:column] = 4
      @env.display_document @doc, hints
    end
    
  end
  
  context 'when a view receives focus' do
    
    it 'is made active' do
      doc = Ruber[:world].new_document
      @views = 2.times.map{@env.editor_for! doc, :existing => :never}
      @env.activate_editor @views[0]
      @views[1].instance_eval{emit focus_in(self)}
      @env.active_editor.should == @views[1]
    end
    
  end
  
  context 'when the close button on a tab is pressed' do
    
    before do
      @doc = Ruber[:world].new_document
      @views = 3.times.map{@env.editor_for! @doc, :existing => :never, :new => :current_tab}
      @other_view = @env.editor_for! @doc, :existing => :never, :new => :new_tab
    end
    
    it 'closes all the editors in the tab' do
      flexmock(@env).should_receive(:close_editors).once.with(FlexMock.on{|a| a.sort_by(&:object_id) == @views.sort_by(&:object_id)})
      @env.tab_widget.instance_eval{emit tabCloseRequested(0)}
    end
    
    it 'does nothing if the user chooses to abort the operation' do
      flexmock(Ruber::MainWindow).should_receive(:save_documents).and_return false
      @views.each{|v| flexmock(v).should_receive(:close).never}
    end
    
  end
  
  context 'when a view is split' do
    
    before do
      @doc = Ruber[:world].new_document
      @view = @env.editor_for! @doc
    end
    
    it 'adds the new view to the list' do
      new_view = @doc.create_view
      @env.tab(@view).split @view, new_view, Qt::Vertical
      @env.views.should include(new_view)
    end
    
    it 'adds the document associated with the view to the list of documents, if needed' do
      doc = Ruber[:world].new_document
      new_view = doc.create_view
      @env.tab(@view).split @view, new_view, Qt::Vertical
      @env.documents.should include(doc)
    end
    
    it 'updates the tool tip of the tab' do
      doc = Ruber[:world].new_document
      new_view = doc.create_view
      @env.tab(@view).split @view, new_view, Qt::Vertical
      exp = @doc.document_name + "\n" + doc.document_name
      @env.tab_widget.tab_tool_tip(0).should == exp
    end
    
    it 'reacts to the view getting focus' do
      new_view = @doc.create_view
      @env.tab(@view).split @view, new_view, Qt::Vertical
      new_view.instance_eval{emit focus_in(self)}
      @env.active_editor.should == new_view
    end
    
    it 'reacts to the view being closed' do
      new_view = @doc.create_view
      @env.tab(@view).split @view, new_view, Qt::Vertical
      new_view.close
      @env.views.should_not include(new_view)
    end
      
  end
  
  context 'when a view is replaced by another' do
   
    before do
      @doc = Ruber[:world].new_document
      @view = @env.editor_for! @doc
    end
    
    it 'adds the new view to the list' do
      new_view = @doc.create_view
      @env.tab(@view).replace_view @view, new_view
      @env.views.should include(new_view)
    end
    
    it 'removes the replaced view from the list' do
      new_view = @doc.create_view
      @env.tab(@view).replace_view @view, new_view
      @env.views.should_not include(@view)
    end
    
    it 'adds the document associated with the view to the list of documents, if needed' do
      doc = Ruber[:world].new_document
      new_view = doc.create_view
      @env.tab(@view).replace_view @view, new_view
      @env.documents.should include(doc)
    end
    
    it 'removes the document associated with the replaced view if it was the only view associated with it in the environment' do
      doc = Ruber[:world].new_document
      new_view = doc.create_view
      @env.tab(@view).replace_view @view, new_view
      @env.documents.should_not include(@doc)
    end
    
    it 'doesn\'t remove the document associated with the replaced view if it wasn\'t the only view associated with it in the environment' do
      doc = Ruber[:world].new_document
      new_view = doc.create_view
      @env.editor_for! @doc, :existing => :never, :new => :new_tab
      @env.tab(@view).replace_view @view, new_view
      @env.documents.should include(@doc)
    end
    
    it 'updates the tool tip of the tab' do
      doc = Ruber[:world].new_document
      new_view = doc.create_view
      @env.tab(@view).replace_view @view, new_view
      exp = doc.document_name
      @env.tab_widget.tab_tool_tip(0).should == exp
    end
    
    it 'reacts to the new view getting focus' do
      new_view = @doc.create_view
      @env.tab(@view).replace_view @view, new_view
      new_view.instance_eval{emit focus_in(self)}
      @env.active_editor.should == new_view
    end
    
    it 'doesn\'t react to the replaced view getting focus' do
      new_view = @doc.create_view
      @env.tab(@view).replace_view @view, new_view
      @env.activate_editor nil
      @view.instance_eval{emit focus_in(self)}
      @env.active_editor.should be_nil
    end
    
    it 'reacts to the view being closed' do
      new_view = @doc.create_view
      @env.tab(@view).replace_view @view, new_view
      new_view.close
      @env.views.should_not include(new_view)
    end
    
    it 'doesn\'t react to the replaced view being closed anymore' do
      new_view = @doc.create_view
      @env.tab(@view).replace_view @view, new_view
      flexmock(@env).should_receive(:editor_closing).never
      @view.close
    end
    
  end
  
  context 'when the URL of a document changes' do
    
    before do
      @doc = Ruber[:world].new_document
    end
    
    context 'if the document is associated with a view in the environment' do
      
      before do
        @views = 2.times.map{@env.editor_for! @doc, :existing => :never}
        @url = KDE::Url.new __FILE__
        flexmock(@doc).should_receive(:url).and_return @url
        flexmock(@doc).should_receive(:document_name).and_return File.basename(__FILE__)
        flexmock(@doc).should_receive(:path).and_return(__FILE__)
      end
      
      it 'updates the tool tip of the tabs containing views associated with the document' do
        @doc.instance_eval{emit document_url_changed(self)}
        @env.tab_widget.to_a.each_index{|i|@env.tab_widget.tab_tool_tip(i).should == File.basename(__FILE__)}
      end
      
      it 'updates the label of the editors associated with the document' do
        @doc.instance_eval{emit document_url_changed(self)}
        @views.each{|v| v.parent.label.should == @url.path}
      end
      
      it 'updates the text amd icon of any tabs having a view associated with the document as last activated view' do
        pix = Qt::Pixmap.new(16,16)
        pix.fill Qt::Color.new(Qt.blue)
        icon = Qt::Icon.new pix
        flexmock(@doc).should_receive(:icon).and_return icon
        other_doc = Ruber[:world].new_document
        other_views = 2.times.map{|i| @env.editor_for! other_doc, :existing => :never, :new => @views[i]}
        @env.activate_editor other_views[1]
        @doc.instance_eval{emit document_url_changed(self)}
        @env.tab_widget.tab_text(0).should == File.basename(__FILE__)
        @env.tab_widget.tab_icon(0).pixmap(16,16).to_image.should == pix.to_image
        @env.tab_widget.tab_text(1).should == other_doc.document_name
        @env.tab_widget.tab_icon(1).pixmap(16,16).to_image.should_not == pix.to_image
      end
      
    end
       
  end
  
  describe 'when the modified status of a document associated with a view in the environment changes' do
    
    before do
      @doc = Ruber[:world].new_document
      @other_doc = Ruber[:world].new_document
      @views = 2.times.map{@env.editor_for! @doc, :existing => :never}
    end
    
    context 'if the document has become modified' do
      
      after do
        @doc.close false
      end
      
      it 'updates the label of the views associated with the document by putting [modified] after the name of the document' do
        other_views=2.times.map{@env.editor_for! @other_doc, :existing => :never}
        @doc.text = 'x'
        @views.each do |v|
          v.parent.label.should == @doc.document_name + ' [modified]'
        end
        other_views.each do |v|
          v.parent.label.should == @other_doc.document_name
        end
      end
      
      it 'updates the icon of any tabs having a view associated with the document as last activated view' do
        img = Ruber::Document::ICONS[:modified].pixmap(16,16).to_image
        other_views = 2.times.map{|i| @env.editor_for! @other_doc, :existing => :never, :new => @views[i]}
        @env.activate_editor other_views[1]
        @doc.text = 'x'
        @env.tab_widget.tab_icon(0).pixmap(16,16).to_image.should == img
        @env.tab_widget.tab_icon(1).pixmap(16,16).to_image.should_not == img
      end
      
    end
    
    context 'if the document has become not modified' do
      
      before do
        @doc.text = 'x'
      end
      
      after do
        @doc.close false
      end
      
      it 'updates the label of the views associated with the document' do
        other_views=2.times.map{@env.editor_for! @other_doc, :existing => :never}
        @doc.modified = false
        @views.each do |v|
          v.parent.label.should == @doc.document_name
        end
        other_views.each do |v|
          v.parent.label.should == @other_doc.document_name
        end
      end
      
      it 'updates the icon of any tabs having a view associated with the document as last activated view' do
        img = Ruber::Document::ICONS[:modified].pixmap(16,16).to_image
        other_views = 2.times.map{|i| @env.editor_for! @other_doc, :existing => :never, :new => @views[i]}
        @env.activate_editor other_views[1]
        @doc.modified = false
        @env.tab_widget.tab_icon(0).pixmap(16,16).to_image.should_not == img
        @env.tab_widget.tab_icon(1).pixmap(16,16).to_image.should_not == img
      end
      
    end
    
  end
  
  describe "#focus_on_editors?" do
    
    before do
      @views = Array.new(3){@env.editor_for! @doc, :existing => :never}
    end
    
    it 'returns true if one of the views in the environment received focus after the last one lost focus' do
      @views[1].instance_eval{emit focus_out(self)}
      @views[2].instance_eval{emit focus_in(self)}
      @env.focus_on_editors?.should be_true
    end
    
    it 'returns false if no view in the environment got focus after the last one
    lost focus' do
      @views[1].instance_eval{emit focus_out(self)}
      @env.focus_on_editors?.should be_false
    end
    
    it 'returns true if there are no views' do
      @views.each{|v| @env.close_editor v, false}
      @env.focus_on_editors?.should be_true
    end
    
  end
  
end