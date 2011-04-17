require './spec/framework'
require './spec/common'

require 'tempfile'
require 'fileutils'

require 'ruber/plugin_specification'
require 'ruber/editor/document'
require 'ruber/pane'

require 'plugins/state/state'

shared_examples_for 'a component of the state plugin saving an environment' do
  
  before :all do
    default_keys = {:tabs => :tabs, :cursor_positions => :cursor_positions, :active_view => :active_view}
    @keys = default_keys.merge(@keys || {})
  end
  
  it 'stores a tree of the open editors for each tab under the state/tabs entry' do
    docs = [nil, __FILE__, File.join(File.dirname(__FILE__), 'common.rb'), nil].map! do |f|
      f ? Ruber[:world].document(f) : Ruber[:world].new_document
    end
    views = [
      docs[1].create_view,
      docs[0].create_view,
      docs[3].create_view,
      docs[2].create_view,
      docs[1].create_view,
      docs[0].create_view
    ]
    tab1 = Ruber::Pane.new views[0]
    tab1.split views[0], views[1], Qt::Vertical
    tab1.split views[0], views[2], Qt::Horizontal
    tab2 = Ruber::Pane.new views[3]
    tab2.split views[3], views[4], Qt::Horizontal
    tab3 = Ruber::Pane.new views[5]
    flexmock(@env).should_receive(:tabs).and_return [tab1, tab2, tab3]
    flexmock(@env).should_receive(:documents).and_return(docs)
    exp = [
      [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
      [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
      [0]
    ]
    @state.save_settings
    @container[:state, @keys[:tabs]].should == exp
  end
  
  it 'uses arrays with a single element in the :tabs entry to represent tabs with a single view' do
    docs = [__FILE__, nil].map{|f| f ? Ruber[:world].document(f) : Ruber[:world].new_document}
    flexmock(@env).should_receive(:documents).and_return(docs)
    views = docs.reverse.map{|d| d.create_view}
    tabs = views.map{|v| Ruber::Pane.new v}
    flexmock(@env).should_receive(:tabs).and_return tabs
    exp = [[0], ['file://' + __FILE__]]
    @state.save_settings
    @container[:state, @keys[:tabs]].should == exp
  end
  
  it 'stores an empty array under the tabs entry if there aren\'t open editors' do
    docs = [
      Ruber[:world].new_document,
      Ruber[:world].document(__FILE__),
    ]
    flexmock(@env).should_receive(:documents).and_return([])
    @state.save_settings
    @container[:state, @keys[:tabs]].should == []
  end
  
  it 'stores the active view as an array of integers referring to the tabs entry in the active_view entry' do
    docs = [
      Ruber[:world].new_document,
      Ruber[:world].document(__FILE__),
      Ruber[:world].document(File.join(File.dirname(__FILE__), 'common.rb')),
      Ruber[:world].new_document,
      ]
    flexmock(@env).should_receive(:documents).and_return(docs)
    views = [
      docs[1].create_view,
      docs[0].create_view,
      docs[3].create_view,
      docs[2].create_view,
      docs[1].create_view,
      docs[0].create_view
    ]
    tab1 = Ruber::Pane.new views[0]
    tab1.split views[0], views[1], Qt::Vertical
    tab1.split views[0], views[2], Qt::Horizontal
    tab2 = Ruber::Pane.new views[3]
    tab2.split views[3], views[4], Qt::Horizontal
    tab3 = Ruber::Pane.new views[5]
    flexmock(@env).should_receive(:tabs).and_return [tab1, tab2, tab3]
    exp = [
      [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
      [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
      [0]
    ]
    sorted_views = [2,1,3,5,4].map{|i| views[i]}
    flexmock(@env).should_receive(:views).and_return(sorted_views)
    flexmock(@env).should_receive(:tab).with(sorted_views[0]).and_return tab1
    @state.save_settings
    @container[:state, @keys[:active_view]].should == [0, 1]
  end
  
  it 'sets the active_view entry to nil if there is no view' do
    docs = [
      Ruber[:world].new_document,
      Ruber[:world].document(__FILE__),
      ]
    flexmock(@env).should_receive(:documents).and_return(docs)
    @state.save_settings
    @container[:state, @keys[:active_view]].should be_nil
  end
  
  it 'stores the cursor position for each view in each tab in the cursor_positions entry' do
    docs = [
      Ruber[:world].new_document,
      Ruber[:world].document(__FILE__),
      Ruber[:world].document(File.join(File.dirname(__FILE__), 'common.rb')),
      Ruber[:world].new_document,
      ]
    flexmock(@env).should_receive(:documents).and_return docs
    views = [
      docs[1].create_view,
      docs[0].create_view,
      docs[3].create_view,
      docs[2].create_view,
      docs[1].create_view,
      docs[0].create_view
    ]
    tab1 = Ruber::Pane.new views[0]
    tab1.split views[0], views[1], Qt::Vertical
    tab1.split views[1], views[2], Qt::Horizontal
    tab2 = Ruber::Pane.new views[3]
    tab2.split views[3], views[4], Qt::Horizontal
    tab3 = Ruber::Pane.new views[5]
    cursor_positions = [
      [[5, 1], [95,102], [1, 4]],
      [[0,0], [45,93]],
      [[12,42]]
    ]
    i = 0
    cursor_positions.each do |t|
      t.each do |pos|
        flexmock(views[i]).should_receive(:cursor_position).and_return(KTextEditor::Cursor.new(*pos))
        i += 1
      end
    end
    flexmock(@env).should_receive(:tabs).and_return [tab1, tab2, tab3]
    @state.save_settings
    @container[:state, @keys[:cursor_positions]].should == cursor_positions
  end
  
  it 'stores an empty array under the cursor_positions entry if there is no view in the environment' do
    docs = [
      Ruber[:world].new_document,
      Ruber[:world].document(__FILE__),
      ]
    flexmock(@env).should_receive(:documents).and_return(docs)
    @state.save_settings
    @container[:state, @keys[:cursor_positions]].should == []
  end
  
end

describe Ruber::State::Plugin do
  
  before do
    Ruber[:world].close_all :all, :false
    Ruber[:components].load_plugin 'plugins/state/'
    Ruber[:world].close_all :all, :false
    @plug = Ruber[:components][:state]
  end
  
  after do
    Ruber[:world].close_all :all, :false
    Ruber[:components].unload_plugin(:state)
  end
  
  it 'inherits Ruber::Plugin' do
    Ruber::State::Plugin.ancestors.should include(Ruber::Plugin)
  end
  
  describe '#when created' do
    
    it 'sets the @force_restore_project_files instance variable to nil' do
      @plug.instance_variables.should include(:@force_restore_project_files)
      @plug.instance_variable_get(:@force_restore_project_files).should be_nil
    end
    
    it 'sets the @force_restore_cursor_position instance variable to nil' do
      @plug.instance_variables.should include(:@force_restore_cursor_position)
      @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
    end
    
  end
  
  describe '#delayed_initialize' do
    
    it 'calls the restore_last_state method if there\'s no open project and the only open document is pristine' do
      Ruber[:world].new_document
      flexmock(@plug).should_receive(:restore_last_state).once
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there are open projects' do
      prj = flexmock('project')
      flexmock(Ruber[:world]).should_receive(:projects).once.and_return [prj]
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there is more than one open document' do
      2.times{Ruber[:world].new_document}
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there aren\'t open documents' do
      flexmock(Ruber[:world]).should_receive(:documents).and_return []
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if the only open document isn\'t pristine' do
      doc = Ruber[:world].new_document
      doc.text = 'xyz'
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'passes the :force argument to restore_last_state if restoring session' do
      Ruber[:world].new_document
      flexmock(Ruber[:app]).should_receive(:sessionRestored?).and_return true
      flexmock(@plug).should_receive(:restore_last_state).once.with(:force)
      @plug.send :delayed_initialize
    end
    
    it 'does nothing if the application is already running' do
      doc = Ruber[:world].new_document
      flexmock(KDE::Application.instance).should_receive(:starting?).and_return false
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
  end
  
  context 'when saving settings' do
    
    before :all do
      @keys = {
      :tabs => :default_environment_tabs,
      :active_view => :default_environment_active_view,
      :cursor_positions => :default_environment_cursor_positions
    }
    end
    
    before do
      @files = [nil, '/prj1.ruprj', '/prj2.ruprj']
      @prjs = @files.map{|f| f ? flexmock(:project_file => f) : nil}
      @envs = @prjs.map{|pr| flexmock :project => pr}
      @state = @plug
      @container = Ruber[:config]
      @env = Ruber[:world].default_environment
    end
    
   
    it 'lists the active environment as first element under the state/last_state key' do
      flexmock(Ruber[:world]).should_receive(:active_environment).and_return(@envs[1])
      exp = [@files[1], @files[0], @files[2]]
      flexmock(Ruber[:world]).should_receive(:environments).and_return @envs
      @plug.save_settings
      Ruber[:config][:state, :last_state].should == exp
    end
    
    it 'puts the default environment as first element of the state/last_state entry if there\'s no active environment' do
      flexmock(Ruber[:world]).should_receive(:active_environment).and_return(nil)
      flexmock(Ruber[:world]).should_receive(:environments).and_return @envs
      @plug.save_settings
      Ruber[:config][:state, :last_state].should == @files
    end
    
    it_behaves_like 'a component of the state plugin saving an environment'
    
  end
  
  context 'when restoring an environment' do
    
    it 'recreates the tabs contained in the environment' do
      data = {
        :tabs => [
                  [Qt::Vertical, 0, 1, 'file://'+__FILE__],
                  [Qt::Horizontal, [Qt::Vertical, 1,0], 'file://'+__FILE__]
                 ],
        :cursor_positions => []
      }
      env = Ruber[:world].default_environment
      @plug.send :restore_environment, env, data
      env.tabs.count.should == 2
      env.tabs[0].panes.map{|pn| pn.view.document.path}.should == ['', '', __FILE__]
      env.tabs[1].views.map{|v| v.document.path}.should == ['', '', __FILE__]
      env.tabs[0].views[1].document.should == env.tabs[1].views[0].document
      env.tabs[1].views[0].document.should == env.tabs[0].views[1].document
      env.tabs[0].views[0].document.should_not == env.tabs[0].views[1].document
    end
    
    it 'creates empty documents for local files which do not exist' do
      data = {
        :tabs => [[Qt::Vertical, 0, 'file://'+__FILE__, 'file:///xyz.rb']],
        :cursor_positions => [],
        :active_view => [0,0]
      }
      env = Ruber[:world].default_environment
      lambda{@plug.send :restore_environment, env, data}.should_not raise_error
      env.views[2].document.should be_pristine
    end
    
    it 'creates empty documents for remote files which do not exist' do
      data = {
        :tabs => [[Qt::Vertical, 0, 'file://'+__FILE__, 'http:///xyz.org/abc.txt']],
        :cursor_positions => [],
        :active_view => [0,0]
      }
      env = Ruber[:world].default_environment
      lambda{@plug.send :restore_environment, env, data}.should_not raise_error
      env.views[2].document.should be_pristine
    end
    
    it 'activates the view which was active last time' do
      data = {
        :tabs => [
                  [Qt::Vertical, 0, 1, 'file://'+__FILE__],
                  [Qt::Horizontal, [Qt::Vertical, 1,0], 'file://'+__FILE__]
                ],
        :cursor_positions => [],
        :active_view => [1,2]
      }
      env = Ruber[:world].default_environment
      @plug.send :restore_environment, env, data
      env.views[0].should == env.tabs[1].panes[1].view
    end
    
    it 'moves the cursor of each view to the position it was last time' do
      positions = [
        [[10,5]],
        [[78,12]]
      ]
      data = { 
        :tabs => [
                   [Qt::Vertical,'file://'+__FILE__],
                   [Qt::Horizontal, 'file://'+__FILE__]
                 ],
       :cursor_positions => positions
      }
      doc = Ruber[:world].document __FILE__
      views = Array.new(2){doc.create_view}
      views.each do |v| 
        flexmock(doc).should_receive(:create_view).once.and_return v
      end
      flexmock(views[0]).should_receive(:go_to).once.with(*positions[0][0])
      flexmock(views[1]).should_receive(:go_to).once.with(*positions[1][0])
      @plug.send :restore_environment, Ruber[:world].default_environment, data
    end
    
    it 'gives focus to the active window' do
      data = { 
        :tabs => [
                  [Qt::Vertical,'file://'+__FILE__],
                  [Qt::Horizontal, 'file://'+__FILE__]
                 ],
        :cursor_positions => [],
        :active_view => [1,0]
      }
      doc = Ruber[:world].document __FILE__
      views = Array.new(2){doc.create_view}
      views.each do |v| 
        flexmock(doc).should_receive(:create_view).once.and_return v
      end
      flexmock(views[1]).should_receive(:set_focus).once
      @plug.send :restore_environment, Ruber[:world].default_environment, data
      
    end
    
    it 'does nothing if there are no views' do
      Ruber[:config][:state, :startup_behaviour] = [:default_environment]
      Ruber[:config][:state, :default_environment_tabs] = []
      Ruber[:config][:state, :default_environment_active_view] = nil
      @plug.send :restore_environment, Ruber[:world].default_environment, :tabs => [], :cursor_positions => []
      Ruber[:world].default_environment.tabs.should be_empty
    end
    
  end
  
  describe '#restore_last_state' do
    
    context 'when called with no arguments' do
    
      context 'if the state/startup_behaviour config option contains :default_environment' do
        
        it 'restores the default environment' do
          data = {
            :tabs => [[Qt::Vertical, 0, 'file://'+__FILE__]],
            :cursor_positions => [[2,3], [4,5]],
            :active_view => [0,1]
          }
          cfg = Ruber[:config][:state]
          cfg[:startup_behaviour] = [:default_environment]
          cfg[:default_environment_tabs] = data[:tabs]
          cfg[:default_environment_cursor_positions]  = data[:cursor_positions]
          cfg[:default_environment_active_view] = data[:active_view]
          flexmock(@plug).should_receive(:restore_environment).with(Ruber[:world].default_environment, data).once
          @plug.send(:restore_last_state)
        end
        
      end
      
      context 'if the state/startup_behaviour config option doesn\'t contain :default_environment' do

        it 'doesn\'t recreate the tabs in the default environment' do
          Ruber[:config][:state, :startup_behaviour] = []
          Ruber[:config][:state, :default_environment_tabs] = [
            [Qt::Vertical, 0, 1, 'file://'+__FILE__],
            [Qt::Horizontal, [Qt::Vertical, 1,0], 'file://'+__FILE__]
          ]
          @plug.send(:restore_last_state)
          flexmock(@plug).should_receive(:restore_environment).never
        end
      
      end
      
      context 'if the state/startup_behaviour config option contains :projects' do
        
        before do
          @project_files = Array.new(3) do |i| 
            file = Tempfile.new ['', 'ruprj']
            file.write YAML.dump(:general => {:project_name => "project #{i}"})
            file.flush
            file
          end
        end
        
        after do
          Ruber[:world].close_all(:projects, :discard)
        end
        
        it 'opens the projects listed under the state/last_state config option' do
          exp = @project_files.map &:path
          Ruber[:config][:state, :startup_behaviour] = [:projects]
          Ruber[:config][:state, :last_state] = exp
          @plug.send :restore_last_state
          Ruber[:world].projects.map(&:project_file).should == exp
        end
        
        it 'ignores any project whose project file doesn\'t exist' do
          files = @project_files.map &:path
          @project_files[1].close!
          Ruber[:config][:state, :startup_behaviour] = [:projects]
          Ruber[:config][:state, :last_state] = files
          exp = files.dup
          exp.delete_at(1)
          @plug.send :restore_last_state
          Ruber[:world].projects.map(&:project_file).should == exp
        end
        
        it 'ignores any project whose project file is invalid' do
          @project_files[1] << "\n{"
          @project_files[1].flush
          files = @project_files.map &:path
          Ruber[:config][:state, :startup_behaviour] = [:projects]
          Ruber[:config][:state, :last_state] = files
          exp = files.dup
          exp.delete_at(1)
          @plug.send :restore_last_state
          Ruber[:world].projects.map(&:project_file).should == exp
        end
        
        it 'restores all opened projects' do
          files = @project_files.map &:path
          prjs = @project_files.map{|f| Ruber[:world].project(f.path)}
          prjs.each do |prj|
            flexmock(@plug).should_receive(:restore_environment).with( Ruber[:world].environment(prj), Hash).once
          end
          Ruber[:config][:state, :startup_behaviour] = [:projects]
          Ruber[:config][:state, :last_state] = files
          @plug.send :restore_last_state
        end
        
        it 'activates the project which is listed first in the state/last_state option' do
          files = @project_files.map &:path
          Ruber[:config][:state, :startup_behaviour] = [:projects]
          Ruber[:config][:state, :last_state] = files
          @plug.send :restore_last_state
          Ruber[:world].active_project.should == Ruber[:world].project(files[0])
        end
        
        it 'activates the default environment if the first entry of the state/last_state option is nil' do
          files = @project_files.map(&:path).unshift nil
          Ruber[:config][:state, :startup_behaviour] = [:projects]
          Ruber[:config][:state, :last_state] = files
          @plug.send :restore_last_state
          Ruber[:world].active_project.should be_nil
        end
        
      end
      
      context 'if the state/startup_behaviour config option doesn\'t contain :projects' do
        
        it 'doesn\'t attempt to open other projects' do
          Ruber[:config][:state, :startup_behaviour] = []
          flexmock(Ruber[:world]).should_receive(:project).never
          @plug.send :restore_last_state
        end
        
      end
      
    end
    
    context 'when called with :force as argument' do
      
      before do
        @project_files = Array.new(3) do |i| 
          file = Tempfile.new ['', 'ruprj']
          file.write YAML.dump(:general => {:project_name => "project #{i}"})
          file.flush
          file
        end
      end
      
      after do
        Ruber[:world].close_all(:all, :discard)
      end
      
      it 'restores the default environment even if the state/startup_behaviour option doesn\'t contain :default_environment' do
        data = {
          :tabs => [[Qt::Vertical, 0, 'file://'+__FILE__]],
          :cursor_positions => [[2,3], [4,5]],
          :active_view => [0,1]
        }
        cfg = Ruber[:config][:state]
        cfg[:startup_behaviour] = []
        cfg[:default_environment_tabs] = data[:tabs]
        cfg[:default_environment_cursor_positions]  = data[:cursor_positions]
        cfg[:default_environment_active_view] = data[:active_view]
        flexmock(@plug).should_receive(:restore_environment).with(Ruber[:world].default_environment, data).once
        @plug.send :restore_last_state, :force
      end
      
      it 'opens the projects listed under the state/last_state config option even
      if the state/startup_behaviour option doesn\'t contain :projects' do
        exp = @project_files.map &:path
        Ruber[:config][:state, :startup_behaviour] = []
        Ruber[:config][:state, :last_state] = exp
        @plug.send :restore_last_state, :force
        Ruber[:world].projects.map(&:project_file).should == exp
      end     
      
      it 'restores all opened projects even if the state/startup_behaviour option doesn\'t contain :projects' do
        files = @project_files.map &:path
        prjs = @project_files.map{|f| Ruber[:world].project(f.path)}
        prjs.each do |prj|
          flexmock(@plug).should_receive(:restore_environment).with( Ruber[:world].environment(prj), Hash).once
        end
        flexmock(@plug).should_receive(:restore_environment).with Ruber[:world].default_environment, Hash
        Ruber[:config][:state, :startup_behaviour] = []
        Ruber[:config][:state, :last_state] = files
        @plug.send :restore_last_state, :force
      end
      
      it 'activates the project which is listed first in the state/last_state option even if the state/startup_behaviour option doesn\'t contain :projects' do
        files = @project_files.map &:path
        Ruber[:config][:state, :startup_behaviour] = []
        Ruber[:config][:state, :last_state] = files
        @plug.send :restore_last_state, :force
        Ruber[:world].active_project.should == Ruber[:world].project(files[0])
      end
      
    end
    
  end
  
  context 'when a project is created' do
    
      before do
        @project_file =  Tempfile.new ['', 'ruprj']
        @project_file.write YAML.dump(:general => {:project_name => "project"})
        @project_file.flush
      end
      
      after do
        Ruber[:world].close_all(:all, :discard)
      end

    
    context 'if the state/restore_projects option is true' do
      
      before do
        Ruber[:config][:state, :restore_projects] = true
      end
      
      it 'calls the restore_environment method passing the project\'s environment and the data associated with it as argument' do
        flexmock(@plug).should_receive(:restore_environment).once.with(FlexMock.on{|env| env.project.project_file == @project_file.path}, Hash)
        Ruber[:world].project @project_file.path
      end
      
      it 'doesn\'t call the restore_environment if the environment already contains views' do
        prj = Ruber[:world].project @project_file.path
        flexmock(@plug).should_receive(:restore_environment).never
        Ruber[:world].environment(prj).editor_for! __FILE__
        Ruber[:world].instance_eval{emit project_created(prj)}
      end
      
    end
    
    context 'if the state/restore_projects option is true' do
      
      before do
        Ruber[:config][:state, :restore_projects] = false
      end
      
      it 'does nothing' do
        flexmock(@plug).should_receive(:restore_environment).never
        Ruber[:world].project @project_file.path
      end

    end
    
  end
    
end

describe Ruber::State::DocumentExtension do
  
  before do
    Ruber[:components].load_plugin 'plugins/state/'
    Ruber[:world].documents.dup.each{|d| d.close false}
    @plug = Ruber[:components][:state]
    @doc = Ruber[:world].document __FILE__
    @prj = @doc.own_project
    @ext = @doc.own_project.extension(:state)
  end
  
  after do
    Ruber[:world].documents.dup.each{|d| d.close false}
    Ruber[:components].unload_plugin :state
  end
  
  
  it 'inherits from Qt::Object' do
    Ruber::State::DocumentExtension.ancestors.should include(Qt::Object)
  end
  
  it 'includes the Ruber::Extension module' do
    Ruber::State::DocumentExtension.ancestors.should include(Ruber::Extension)
  end
  
  describe ', when created' do
    
    it 'connects the document\'s view_created(QObject*, QObject*) signal to its auto_restore slot, passing the view to it' do
      flexmock(@ext).should_receive(:auto_restore).once.with(Ruber::EditorView)
      @doc.create_view
    end
    
  end
  
  describe '#restore' do
    
    context 'if no other view associated with the document received focus before' do
      
      it 'moves the cursor to the position specified in the state/cursor_position entry of the document project' do
        exp = [10, 5]
        views = 3.times.map{@doc.create_view}
        @prj[:state, :cursor_position] = exp
        @ext.restore views[1]
        cur = views[1].cursor_position
        cur.line.should == exp[0]
        cur.column.should == exp[1]
      end
      
    end
    
    context 'if another view associated with the document has received focus before' do
      
      it 'moves the cursor to the position of the cursor in the view which last received focus' do
        exp = [10, 5]
        views = 3.times.map{@doc.create_view}
        views[0].instance_eval{emit focus_in(self)}
        flexmock(@prj).should_receive(:[]).with(:state, :cursor_position).never
        flexmock(views[0]).should_receive(:cursor_position).and_return(KTextEditor::Cursor.new(*exp))
        @ext.restore views[1]
        cur = views[1].cursor_position
        cur.line.should == exp[0]
        cur.column.should == exp[1]
      end
      
    end

  end
  
  describe '#save_settings' do
    
    it 'stores the cursor position in the view which last got focus under the state/cursor_position key' do
      views = 3.times.map{@doc.create_view}
      #simply calling set_focus to give focus to the view wouldn't work because
      #set_focus relies on a running event loop
      views[1].instance_eval{emit focus_in(self)}
      views[0].instance_eval{emit focus_in(self)}
      views[2].instance_eval{emit focus_in(self)}
      flexmock(views[1]).should_receive(:cursor_position).and_return(KTextEditor::Cursor.new(120,25))
      flexmock(views[0]).should_receive(:cursor_position).and_return(KTextEditor::Cursor.new(33,45))
      flexmock(views[2]).should_receive(:cursor_position).and_return(KTextEditor::Cursor.new(50,15))
      @ext.save_settings
      @prj[:state, :cursor_position].should == [50,15]
    end
    
    it 'keeps using the view which last got focus' do
      views = 3.times.map{@doc.create_view}
      views[1].instance_eval{emit focus_in(self)}
      views[0].instance_eval{emit focus_in(self)}
      flexmock(@ext).should_receive(:save_settings)
      views[1].close
      flexmock(@prj).should_receive(:[]).with(:state, :cursor_position).never
      flexmock(views[0]).should_receive(:cursor_position).once.and_return(KTextEditor::Cursor.new(2,3))
      @doc.create_view
    end

    
    it 'does nothing if none of the views associated with the document have received focus' do
      views = 3.times.map{@doc.create_view}
      flexmock(views[1]).should_receive(:cursor_position).never
      flexmock(views[0]).should_receive(:cursor_position).never
      flexmock(views[2]).should_receive(:cursor_position).never
      flexmock(@prj).should_receive(:[]=).with(:state, :cursor_position).never
      @ext.save_settings
    end
    
  end
  
  describe 'auto_restore' do

    context 'if the state/restore_cursor_position option is true' do
      
      before do
        Ruber[:config][:state, :restore_cursor_position] = true
      end
      
      it 'calls the restore method' do
        view = @doc.create_view
        flexmock(@ext).should_receive(:restore).once.with(view)
        @ext.send :auto_restore, view
      end
    
    end
    
    context 'if the state plugin doesn\'t want the cursor position restored' do
      
      before do
        Ruber[:config][:state, :restore_cursor_position] = false
      end
      
      it 'does nothing' do
        view = @doc.create_view
        flexmock(@ext).should_receive(:restore).never
        @ext.send :auto_restore, view
      end
      
    end
    
  end
  
  context 'when a view associated with the document is closed' do
    
    context 'and the view is the one which last got focus' do
    
      it 'calls the save_settings method' do
        views = 3.times.map{@doc.create_view}
        views[1].instance_eval{emit focus_in(self)}
        views[0].instance_eval{emit focus_in(self)}
        flexmock(@ext).should_receive(:save_settings).once
        views[0].close
        #needed because otherwise the save_settings method is called again when
        #the document is closed in the after block
        flexmock(@ext).should_receive(:save_settings)
      end
      
      it 'behaves as if no other view had ever got focus' do
        views = 3.times.map{@doc.create_view}
        views[1].instance_eval{emit focus_in(self)}
        views[0].instance_eval{emit focus_in(self)}
        flexmock(@ext).should_receive(:save_settings)
        views[0].close
        flexmock(@prj).should_receive(:[]).with(:state, :cursor_position).once.and_return([10,2])
        @doc.create_view
      end
      
    end
    
    context 'and the view isn\'t the last one which got focus' do

      it 'does nothing' do
        views = 3.times.map{@doc.create_view}
        views[1].instance_eval{emit focus_in(self)}
        views[0].instance_eval{emit focus_in(self)}
        flexmock(@ext).should_receive(:save_settings).never
        views[1].close
        #needed because otherwise the save_settings method is called again when
        #the document is closed in the after block
        flexmock(@ext).should_receive(:save_settings)
      end
      
      it 'keeps using the view which last got focus' do
        views = 3.times.map{@doc.create_view}
        views[1].instance_eval{emit focus_in(self)}
        views[0].instance_eval{emit focus_in(self)}
        flexmock(@ext).should_receive(:save_settings)
        views[1].close
        flexmock(@prj).should_receive(:[]).with(:state, :cursor_position).never
        flexmock(views[0]).should_receive(:cursor_position).once.and_return(KTextEditor::Cursor.new(2,3))
        @doc.create_view
      end
      
    end
    
  end
  
end

describe Ruber::State::ProjectExtension do
  
  it 'inherits from Qt::Object' do
    Ruber::State::ProjectExtension.ancestors.should include(Qt::Object)
  end
  
  it 'includes the Ruber::Extension module' do
    Ruber::State::ProjectExtension.ancestors.should include(Ruber::Extension)
  end
  
  before do
    Ruber[:world].documents.dup.each{|doc| doc.close false}
    Ruber[:components].load_plugin 'plugins/state/'
    @plug = Ruber[:components][:state]
    @dir = File.join Dir.tmpdir, random_string(10)
    FileUtils.mkdir @dir
    @prj = Ruber[:world].new_project File.join(@dir, 'test.ruprj'), 'Test'
    @ext = @prj.extension :state
    @env = Ruber[:world].environment @prj
  end
  
  after do
    FileUtils.rm_rf @dir
    Ruber[:components].unload_plugin :state
  end

  describe '#save_settings' do
    
    before do
      @state = @ext
      @container = @prj
    end
    
    it_behaves_like 'a component of the state plugin saving an environment'
    
  end
      
end