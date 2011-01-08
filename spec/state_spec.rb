require './spec/framework'
require './spec/common'

require 'tempfile'
require 'fileutils'

require 'ruber/plugin_specification'
require 'ruber/editor/document'
require 'ruber/pane'

require 'plugins/state/state'

describe Ruber::State::Plugin do
  
  before do
#     #Needed because the Qt::Object connect method doesn't like @components not being a
#     #Qt::Object
#     class Ruber::State::Plugin
#       def connect *args
#       end
#     end
#     @components = flexmock('components'){|m| m.should_ignore_missing}
#     @config = flexmock('config'){|m| m.should_ignore_missing}
#     flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components).by_default
#     flexmock(Ruber).should_receive(:[]).with(:app).and_return(KDE::Application.instance).by_default
#     flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    Ruber[:documents].close_all(false)
    Ruber[:components].load_plugin 'plugins/state/'
    @plug = Ruber[:components][:state]
#     data = YAML.load('plugins/state/plugin.yaml')
#     psf = Ruber::PluginSpecification.full data
#     @plug = Ruber::State::Plugin.new psf
  end
  
  after do
    Ruber[:components].unload_plugin(:state)
  end
#   
#   after do
#     class Ruber::State::Plugin
#       remove_method :connect rescue nil
#     end
#   end
  
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
    
#     before do
#       @documents = flexmock('documents')
#       @projects = flexmock('projects')
#       flexmock(KDE::Application.instance).should_receive(:starting?).and_return(true).by_default
#     end
    
    it 'calls the restore_last_state method if there\'s no open project and the only open document is pristine' do
      Ruber[:documents].new_document
      flexmock(@plug).should_receive(:restore_last_state).once
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there are open projects' do
      prj = flexmock('project')
      flexmock(Ruber[:projects]).should_receive(:to_a).once.and_return [prj]
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there is more than one open document' do
      2.times{Ruber[:documents].new_document}
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there aren\'t open documents' do
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if the only open document isn\'t pristine' do
      doc = Ruber[:documents].new_document
      doc.text = 'xyz'
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'does nothing if the application is already running' do
      doc = Ruber[:documents].new_document
      flexmock(KDE::Application.instance).should_receive(:starting?).and_return false
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
  end
  
  describe '#gather_settings' do
    
    it 'stores a list with the project file of each open project under the :open_projects key' do
      prjs = 5.times.map{|i| flexmock(i.to_s){|m| m.should_receive(:project_file).and_return i.to_s}}
      flexmock(Ruber[:projects]).should_receive(:projects).once.and_return(prjs)
      flexmock(Ruber[:projects]).should_receive(:current).once.and_return(nil)
      @plug.send(:gather_settings).should have_entries(:open_projects => (0...5).map(&:to_s))
    end
    
    it 'puts the file corresponding to the open project at the beginning of the :open_projects entry' do
      prjs = 5.times.map{|i| flexmock(i.to_s, :project_file => i.to_s)}
      flexmock(Ruber[:projects]).should_receive(:projects).once.and_return(prjs)
      flexmock(Ruber[:projects]).should_receive(:current).once.and_return prjs[2]
      @plug.send(:gather_settings).should have_entries(:open_projects => %w[2 0 1 3 4])
    end
    
    it 'stores the project files in an arbitrary order if there\'s no active project' do
      prjs = 5.times.map{|i| flexmock(i.to_s){|m| m.should_receive(:project_file).and_return i.to_s}}
      flexmock(Ruber[:projects]).should_receive(:projects).once.and_return(prjs)
      flexmock(Ruber[:projects]).should_receive(:current).once.and_return nil
      @plug.send(:gather_settings).should have_entries(:open_projects => (0...5).map(&:to_s))
    end
    
    it 'stores an empty array under the :open_projects key if there are no open projects' do
      @plug.send(:gather_settings).should have_entries(:open_projects => [])
    end
    
    it 'stores a list of the URLs of the files associated with all open documents under the :open_files key' do
      docs = 5.times.map{|i| flexmock(i.to_s, :has_file? => true, :view => flexmock){|m| m.should_receive(:url).and_return KDE::Url.new("file:///xyz/file #{i}")}}
      flexmock(Ruber[:documents]).should_receive(:documents).once.and_return(docs)
      exp = [
        'file:///xyz/file%200',
        'file:///xyz/file%201',
        'file:///xyz/file%202',
        'file:///xyz/file%203',
        'file:///xyz/file%204',
        ]
      @plug.send(:gather_settings).should have_entries(:open_documents => exp)
    end
    
    it 'stores nil in place of documents not associated with files' do
      docs = 5.times.map do |i| 
        flexmock(i.to_s, :view => flexmock) do |m|
          m.should_receive(:url).and_return(i % 2 == 0 ? KDE::Url.new("file:///xyz/file #{i}") : KDE::Url.new)
          m.should_receive(:has_file?).and_return(i % 2 == 0)
        end
      end
      flexmock(Ruber[:documents]).should_receive(:documents).once.and_return(docs)
      exp = [
        'file:///xyz/file%200',
        nil,
        'file:///xyz/file%202',
        nil,
        'file:///xyz/file%204',
        ]
      @plug.send(:gather_settings).should have_entries(:open_documents => exp)
    end
    
    it 'stores an empty array under the :open_files key if there are no open documents' do
      @plug.send(:gather_settings).should have_entries(:open_documents => [])
    end
    
    it 'stores a tree of the open editors for each tab under the tabs entry' do
      docs = [nil, __FILE__, File.join(File.dirname(__FILE__), 'common.rb'), nil].map! do |f|
        f ? Ruber[:documents].document(f) : Ruber[:documents].new_document
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
      flexmock(Ruber[:main_window]).should_receive(:tabs).once.and_return [tab1, tab2, tab3]
      exp = [
        [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
        [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
        [0]
      ]
      @plug.send(:gather_settings)[:tabs].should == exp
    end
    
    it 'uses arrays with a single element in the :tabs entry to represent tabs with a single view' do
      docs = [__FILE__, nil].map{|f| f ? Ruber[:documents].document(f) : Ruber[:documents].new_document}
      views = docs.reverse.map{|d| d.create_view}
      tabs = views.map{|v| Ruber::Pane.new v}
      flexmock(Ruber[:main_window]).should_receive(:tabs).once.and_return tabs
      exp = [[0], ['file://' + __FILE__]]
      @plug.send(:gather_settings)[:tabs].should == exp
    end
    
    it 'stores an empty array under the tabs entry if there aren\'t open editors' do
      docs = [
        Ruber[:documents].new_document,
        Ruber[:documents].document(__FILE__),
      ]
      @plug.send(:gather_settings)[:tabs].should == []
    end
    
    it 'stores the active view as an array of integers referring to the tabs entry in the active_view entry' do
      docs = [
        Ruber[:documents].new_document,
        Ruber[:documents].document(__FILE__),
        Ruber[:documents].document(File.join(File.dirname(__FILE__), 'common.rb')),
        Ruber[:documents].new_document,
        ]
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
      flexmock(Ruber[:main_window]).should_receive(:tabs).once.and_return [tab1, tab2, tab3]
      exp = [
        [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
        [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
        [0]
      ]
      flexmock(Ruber[:main_window]).should_receive(:active_editor).and_return(views[2])
      flexmock(Ruber[:main_window]).should_receive(:tab).with(views[2]).and_return tab1
      @plug.send(:gather_settings)[:active_view].should == [0,1]
    end
    
    it 'sets the active_view entry to nil if there isn\'t an active editor' do
      docs = [
        Ruber[:documents].new_document,
        Ruber[:documents].document(__FILE__),
        ]
      @plug.send(:gather_settings)[:active_view].should be_nil
    end
    
    it 'stores the cursor position for each view in each tab in the cursor_positions entry' do
      docs = [
        Ruber[:documents].new_document,
        Ruber[:documents].document(__FILE__),
        Ruber[:documents].document(File.join(File.dirname(__FILE__), 'common.rb')),
        Ruber[:documents].new_document,
        ]
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
      flexmock(Ruber[:main_window]).should_receive(:tabs).once.and_return [tab1, tab2, tab3]
      @plug.send(:gather_settings)[:cursor_positions].should == cursor_positions
    end

  end
  
  describe '#save_settings' do
    
    it 'stores the value corresponding to the :open_projects key in the hash returned by gather_settings in the state/open_projects setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:open_projects => %w[x y z])
      flexmock(Ruber[:config]).should_receive(:[]=).with(:state, :open_projects, %w[x y z]).once
      flexmock(Ruber[:config]).should_receive(:[]=)
      @plug.save_settings
    end
    
    it 'stores the value corresponding to the :open_documents key in the hash returned by gather_settings in the state/open_documents setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:open_documents => %w[x y z])
      flexmock(Ruber[:config]).should_receive(:[]=).with(:state, :open_documents, %w[x y z]).once
      flexmock(Ruber[:config]).should_receive(:[]=)
      @plug.save_settings
    end
    
    it 'stores the value corresponding to the :active_view key in the hash returned by gather_settings in the state/active_editor setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:active_view => [1, 2])
      flexmock(Ruber[:config]).should_receive(:[]=).with(:state, :active_view, [1,2]).once
      flexmock(Ruber[:config]).should_receive(:[]=)
      @plug.save_settings
    end
    
    it 'stores the value corresponding to the :tabs key of the has returned by gather_settings in the state/tabs setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:tabs => [Qt::Horizontal, 'file://'+__FILE__, 0])
      flexmock(Ruber[:config]).should_receive(:[]=).with(:state, :tabs, [Qt::Horizontal, 'file://'+__FILE__, 0]).once
      flexmock(Ruber[:config]).should_receive(:[]=)
      @plug.save_settings

    end
    
  end
  
  describe '#restore_cursor_position?' do
    
    it 'returns the value of the state/restore_cursor_position config entry if the @force_restore_cursor_position instance variable is nil' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :restore_cursor_position).once.and_return(true)
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :restore_cursor_position).once.and_return(false)
      @plug.instance_variable_set :@force_restore_cursor_position, nil
      @plug.restore_cursor_position?.should == true
      @plug.restore_cursor_position?.should == false
    end
    
    it 'returns the value of the @force_restore_cursor_position instance variable if it is not nil' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :restore_cursor_position).never
      @plug.instance_variable_set :@force_restore_cursor_position, true
      @plug.restore_cursor_position?.should == true
      @plug.instance_variable_set :@force_restore_cursor_position, false
      @plug.restore_cursor_position?.should == false
    end
    
  end
  
  describe '#restore_project_files?' do
    
    it 'returns the value of the state/restore_project_files config entry if the @force_restore_project_files instance variable is nil' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :restore_project_files).once.and_return(true)
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :restore_project_files).once.and_return(false)
      @plug.instance_variable_set :@force_restore_project_files, nil
      @plug.restore_project_files?.should == true
      @plug.restore_project_files?.should == false
    end
    
    it 'returns the value of the @force_restore_project_files instance variable if it is not nil' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :restore_project_files).never
      @plug.instance_variable_set :@force_restore_project_files, true
      @plug.restore_project_files?.should == true
      @plug.instance_variable_set :@force_restore_project_files, false
      @plug.restore_project_files?.should == false
    end
    
  end
  
  describe 'session_data' do
    
    it 'returns a hash containing the hash returned by the gather_settings method under the "State" key' do
      hash = {
        :open_projects => %w[a b c],
        :open_documents => %w[x y z],
        :tabs => [Qt::Horizontal, 'file://'+__FILE__, 0],
        :active_view => [0,0]
        }
      flexmock(@plug).should_receive(:gather_settings).once.and_return hash
      res = @plug.session_data
      res['State'].should == hash
    end
    
  end
  
  describe '#restore_session' do
    
    it 'calls restore from within a with block with :restore_cursor_position and :restore_project_files set to true passing the hash contained in the State entry of the argument' do
      hash = {
        'State' => {
          :open_projects => %w[a b c],
          :open_documents => %w[x y z],
          :tabs => [Qt::Horizontal, 'file://'+__FILE__, 0],
          :active_view => [0,0]
        }
      }
      exp_hash = {
        [:state, :open_projects] => %w[a b c],
        [:state, :open_documents] => %w[x y z],
        [:state, :active_view] => [0,0],
        [:state, :tabs] => [Qt::Horizontal, 'file://'+__FILE__, 0],
        }
      default = {:open_projects => [], :open_documents => [], :active_document => nil}
      flexmock(@plug).should_receive(:with).with({:restore_cursor_position => true, :restore_project_files => true, :force => true}, FlexMock.on{|a| a.call || a.is_a?(Proc)}).once
      flexmock(@plug).should_receive(:restore).with(FlexMock.on{|a| a == exp_hash and a[:state, :open_projects] == %w[a b c]}).once
      @plug.restore_session hash
    end
    
  end
  
  describe '#with' do
    
    describe ', when the @force_restore_cursor_position instance variable is nil' do
    
      it 'calls the given block after setting the @force_restore_project_files instance variable to the :restore_cursor_position entry if the entry is a true value' do
        restore_doc = nil
        @plug.with(:restore_cursor_position => 'x'){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should == 'x'
      end
      
      it 'calls the given block after setting the @force_restore_project_files instance variable to false if the :restore_cursor_position entry is given and is a false value' do
        restore_doc = nil
        @plug.with(:restore_cursor_position => false){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should == false
        restore_doc = nil
        @plug.instance_variable_set :@force_restore_cursor_position, nil
        @plug.with(:restore_cursor_position => nil){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should == false
      end
      
      it 'calls the block without changing the @force_restore_cursor_position instance variable if the :restore_cursor_position entry isn\'t given' do
        restore_doc = true
        @plug.with({}){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should be_nil
      end
      
      it 'sets the @force_restore_cursor_position back to nil after executing the block, even if the block raises an exception' do
        @plug.with(:restore_cursor_position => true){@plug.instance_variable_get(:@force_restore_cursor_position).should be_true}
        @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
        @plug.with(:restore_cursor_position => false){@plug.instance_variable_get(:@force_restore_cursor_position).should == false}
        @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
        begin @plug.with(:restore_cursor_position => true){raise Exception}
        rescue Exception
        end
        @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
      end
      
    end
    
    describe ', when the @force_restore_cursor_position instance variable is not nil' do
      
      describe ' and the :force entry isn\'t true' do
        
        it 'calls the block without changing the value of the @force_restore_cursor_position instance variable' do
          restore = nil
          @plug.instance_variable_set(:@force_restore_cursor_position, 'x')
          @plug.with(:restore_cursor_position => 'y'){restore = @plug.instance_variable_get(:@force_restore_cursor_position)}
          restore.should == 'x'
        end
        
      end
      
      describe ' and the :force entry is true' do
        
        before do
          @plug.instance_variable_set :@force_restore_cursor_position, 'y'
        end
        
        it 'calls the given block after setting the @force_restore_project_files instance variable to the :restore_cursor_position entry if the entry is a true value' do
          restore_doc = nil
          @plug.with(:restore_cursor_position => 'x', :force => true){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
          restore_doc.should == 'x'
        end
        
        it 'calls the given block after setting the @force_restore_project_files instance variable to false if the :restore_cursor_position entry is given and is a false value' do
          restore_doc = nil
          @plug.with(:restore_cursor_position => false, :force => true){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
          restore_doc.should == false
          restore_doc = nil
          @plug.instance_variable_set :@force_restore_cursor_position, nil
          @plug.with(:restore_cursor_position => nil, :force => true){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
          restore_doc.should == false
        end
        
        it 'calls the block without changing the @force_restore_cursor_position instance variable if the :restore_cursor_position entry isn\'t given' do
          restore_doc = true
          @plug.with({:force => true}){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
          restore_doc.should == 'y'
        end
        
        it 'sets the @force_restore_cursor_position back to the original value after executing the block, even if the block raises an exception' do
          @plug.with(:restore_cursor_position => true, :force => true){@plug.instance_variable_get(:@force_restore_cursor_position).should be_true}
          @plug.instance_variable_get(:@force_restore_cursor_position).should == 'y'
          @plug.with(:restore_cursor_position => false, :force => true){@plug.instance_variable_get(:@force_restore_cursor_position).should == false}
          @plug.instance_variable_get(:@force_restore_cursor_position).should == 'y'
          begin @plug.with(:restore_cursor_position => true, :force => true){raise Exception}
          rescue Exception
          end
          @plug.instance_variable_get(:@force_restore_cursor_position).should == 'y'
        end
          
      end
      
    end
    
    describe ', when the @force_restore_cursor_position instance variable is nil' do
      
      it 'calls the given block after setting the @force_restore_project_files instance variable to the :restore_cursor_position entry if the entry is a true value' do
        restore_doc = nil
        @plug.with(:restore_cursor_position => 'x'){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should == 'x'
      end
      
      it 'calls the given block after setting the @force_restore_project_files instance variable to false if the :restore_cursor_position entry is given and is a false value' do
        restore_doc = nil
        @plug.with(:restore_cursor_position => false){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should == false
        restore_doc = nil
        @plug.instance_variable_set :@force_restore_cursor_position, nil
        @plug.with(:restore_cursor_position => nil){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should == false
      end
      
      it 'calls the block without changing the @force_restore_cursor_position instance variable if the :restore_cursor_position entry isn\'t given' do
        restore_doc = true
        @plug.with({}){restore_doc = @plug.instance_variable_get(:@force_restore_cursor_position)}
        restore_doc.should be_nil
      end
      
      it 'sets the @force_restore_cursor_position back to nil after executing the block, even if the block raises an exception' do
        @plug.with(:restore_cursor_position => true){@plug.instance_variable_get(:@force_restore_cursor_position).should be_true}
        @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
        @plug.with(:restore_cursor_position => false){@plug.instance_variable_get(:@force_restore_cursor_position).should == false}
        @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
        begin @plug.with(:restore_cursor_position => true){raise Exception}
        rescue Exception
        end
        @plug.instance_variable_get(:@force_restore_cursor_position).should be_nil
      end
      
    end
    
    describe ', when the @force_restore_project_files instance variable is not nil' do
      
      describe ' and the :force entry isn\'t true' do
        
        it 'calls the block without changing the value of the @force_restore_project_files instance variable' do
          restore = nil
          @plug.instance_variable_set(:@force_restore_project_files, 'x')
          @plug.with(:restore_project_files => 'y'){restore = @plug.instance_variable_get(:@force_restore_project_files)}
          restore.should == 'x'
        end
        
      end
      
      describe ' and the :force entry is true' do
        
        before do
          @plug.instance_variable_set :@force_restore_project_files, 'y'
        end
        
        it 'calls the given block after setting the @force_restore_project_files instance variable to the :restore_project_files entry if the entry is a true value' do
          restore_prj = nil
          @plug.with(:restore_project_files => 'x', :force => true){restore_prj = @plug.instance_variable_get(:@force_restore_project_files)}
          restore_prj.should == 'x'
        end
        
        it 'calls the given block after setting the @force_restore_project_files instance variable to false if the :restore_project_files entry is given and is a false value' do
          restore_prj = nil
          @plug.with(:restore_project_files => false, :force => true){restore_prj = @plug.instance_variable_get(:@force_restore_project_files)}
          restore_prj.should == false
          restore_prj = nil
          @plug.instance_variable_set :@force_restore_project_files, nil
          @plug.with(:restore_project_files => nil, :force => true){restore_prj = @plug.instance_variable_get(:@force_restore_project_files)}
          restore_prj.should == false
        end
        
        it 'calls the block without changing the @force_restore_project_files instance variable if the :restore_project_files entry isn\'t given' do
          restore_prj = true
          @plug.with({:force => true}){restore_prj = @plug.instance_variable_get(:@force_restore_project_files)}
          restore_prj.should == 'y'
        end
        
        it 'sets the @force_restore_project_files back to the original value after executing the block, even if the block raises an exception' do
          @plug.with(:restore_project_files => true, :force => true){@plug.instance_variable_get(:@force_restore_project_files).should be_true}
          @plug.instance_variable_get(:@force_restore_project_files).should == 'y'
          @plug.with(:restore_project_files => false, :force => true){@plug.instance_variable_get(:@force_restore_project_files).should == false}
          @plug.instance_variable_get(:@force_restore_project_files).should == 'y'
          begin @plug.with(:restore_project_files => true, :force => true){raise Exception}
          rescue Exception
          end
          @plug.instance_variable_get(:@force_restore_project_files).should == 'y'
        end
        
      end
      
    end
    
  end
  
  describe '#restore_document' do
    
    it 'calls the document\'s state extension\'s restore method' do
      ext = flexmock('extension'){|m| m.should_receive(:restore).once}
      doc = flexmock('doc'){|m| m.should_receive(:extension).once.with(:state).and_return ext}
      @plug.restore_document doc
    end
    
  end
  
  describe '#restore_project' do
    
    it 'calls the project\'s state extension\'s restore method' do
      ext = flexmock('extension'){|m| m.should_receive(:restore).once}
      prj = flexmock('prj'){|m| m.should_receive(:extension).once.with(:state).and_return ext}
      @plug.restore_project prj
    end
    
  end
  
  describe '#restore_projects' do
    
    it 'closes all projects' do
      prjs = 3.times.map{|i| flexmock(i.to_s)}
      prjs.each{|pr| flexmock(Ruber[:projects]).should_receive(:close_project).with(pr).once}
      flexmock(Ruber[:projects]).should_receive(:to_a).once.and_return(prjs)
      @plug.restore_projects
    end
    
    it 'uses the safe_open_project method of the main window to open the first entry of the state/open_projects setting' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :open_projects).once.and_return %w[/x/y/z.ruprj /a/b/c.ruprj]
      prj = flexmock('project', :project_file => '/x/y/z.ruprj')
      flexmock(Ruber[:main_window]).should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return prj
      flexmock(Ruber[:projects]).should_receive(:current_project=)
      @plug.restore_projects
    end
    
    it 'activates the project returned by safe_open_project' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :open_projects).once.and_return %w[/x/y/z.ruprj /a/b/c.ruprj]
      prj = flexmock('project')
      flexmock(Ruber[:main_window]).should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return prj
      flexmock(Ruber[:projects]).should_receive(:current_project=).once.with(prj)
      @plug.restore_projects
    end
    
    it 'doesn\'t attempt to activate the project if safe_open_project returned nil' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :open_projects).once.and_return %w[/x/y/z.ruprj /a/b/c.ruprj]
      prj = flexmock('project')
      flexmock(Ruber[:main_window]).should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return nil
      flexmock(Ruber[:projects]).should_receive(:current_project=).never
      lambda{@plug.restore_projects}.should_not raise_error
    end
    
    it 'does nothing if the state/open_projects setting is empty' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :open_projects).once.and_return []
      prj = flexmock('project')
      flexmock(Ruber[:projects]).should_receive(:project).never
      flexmock(Ruber[:projects]).should_receive(:current_project=).never
      @plug.restore_projects
    end
    
    it 'reads the settings from the argument, if given, rather than from the config object' do
      flexmock(Ruber[:config]).should_receive(:[]).never
      h = {[:state, :open_projects] => ['/x/y/z.ruprj']}
      def h.[] group, name
        super [group, name]
      end
      prj = flexmock('project')
      flexmock(Ruber[:main_window]).should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return prj
      flexmock(Ruber[:projects]).should_receive(:current_project=).once.with(prj)
      @plug.restore_projects h
    end
    
  end
  
  describe '#restore_documents' do
    
    it 'closes all open documents' do
      flexmock(Ruber[:documents]).should_receive(:close_all).once
      @plug.restore_documents
    end
    
    it 'creates a new document for each entry in the state/open_documents' do
      files = [__FILE__, File.join(File.dirname(__FILE__), 'common.rb'), File.join(File.dirname(__FILE__), 'framework.rb')].map{|f| "file://#{f}"}
      Ruber[:config][:state, :open_documents] = files
      @plug.restore_documents
      Ruber[:documents].count.should == files.count
      Ruber[:documents].each_with_index do |doc, i|
        doc.url.url.should == files[i]
      end
    end
    
    it 'creates empty documents for numeric entries under the state/open_documents key' do
      files = [0, 'file:///x/y/f1.rb', 'file:///a/b/f2.rb', 2]
      Ruber[:config][:state, :open_documents] = files
      flexmock(Ruber[:documents]).should_receive(:new_document).once.ordered
      flexmock(Ruber[:documents]).should_receive(:document).once.with(KDE::Url.new(files[1])).ordered
      flexmock(Ruber[:documents]).should_receive(:document).once.with(KDE::Url.new(files[2])).ordered
      flexmock(Ruber[:documents]).should_receive(:new_document).once.ordered
      flexmock(Ruber[:main_window]).should_receive(:without_activating)
      @plug.restore_documents
    end
    
    it 'creates a tab for each array in the :tabs entry if all of them contain a single element' do
      docs = [nil, __FILE__, File.join(File.dirname(__FILE__), 'common.rb'), nil].map{|f| f ? 'file://' + f : nil}
      views = [[docs[1]], [1], [0]]
      Ruber[:config][:state, :open_documents] = docs
      Ruber[:config][:state, :tabs] = views
      @plug.restore_documents
      tabs = Ruber[:main_window].tabs
      tabs.count.should == 3
      tabs[0].view.document.path.should == __FILE__
      tabs[1].view.document.should == Ruber[:documents][3]
      tabs[2].view.document.should == Ruber[:documents][0]
    end
    
    it 'creates nested tabs for each element of the :tabs entry which is a nested array' do
      docs = [nil, __FILE__, File.join(File.dirname(__FILE__), 'common.rb'), nil].map{|f| f ? 'file://' + f : nil}
      views =[
        [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
        [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
        [0]
      ]
      Ruber[:config][:state, :open_documents] = docs
      Ruber[:config][:state, :tabs] = views
      @plug.restore_documents
      tabs = Ruber[:main_window].tabs
      tabs.count.should == 3
      tabs[0].orientation.should == Qt::Vertical
      child_pane = tabs[0].splitter.widget(0)
      child_pane.orientation.should == Qt::Horizontal
      view_list = child_pane.to_a
      view_list[0].document.path.should == __FILE__
      view_list[1].document.should == Ruber[:documents][-1]
      tabs[0].splitter.widget(1).view.document.should == Ruber[:documents][0]
      tabs[1].orientation.should == Qt::Horizontal
      view_list = tabs[1].to_a
      view_list[0].document.path.should == File.join(File.dirname(__FILE__), 'common.rb')
      view_list[1].document.path.should == __FILE__
      tabs[2].should be_single_view
      tabs[2].view.document.should == Ruber[:documents][0]
    end
    
    it 'moves the cursor position of each view according to the contents of the :cursor_positions entry' do
      docs = ['file://'+__FILE__, 'file://'+File.join(File.dirname(__FILE__), 'common.rb'), 'file://'+File.join(File.dirname(__FILE__), 'framework.rb')]
      views =[
        [Qt::Vertical, [Qt::Horizontal, docs[0], docs[1] ], docs[2]],
        [docs[1]]
      ]
      positions = [
        [[30, 16], [53,33], [1,2]],
        [[2,6]]
      ]
      Ruber[:config][:state, :open_documents] = docs
      Ruber[:config][:state, :tabs] = views
      Ruber[:config][:state, :cursor_positions] = positions
      @plug.restore_documents
      tabs = Ruber[:main_window].tabs
      tabs.each_with_index do |t, i|
        t.to_a.each_with_index do |v, j|
          c = v.cursor_position
          c.line.should == positions[i][j][0]
          c.column.should == positions[i][j][1]
        end
      end
    end
    
    it 'doesn\'t attempt to change the cursor positions if the cursor_positions entry is empty' do
      docs = ['file://'+__FILE__, 'file://'+File.join(File.dirname(__FILE__), 'common.rb'), 'file://'+File.join(File.dirname(__FILE__), 'framework.rb')]
      views =[
        [Qt::Vertical, [Qt::Horizontal, docs[0], docs[1] ], docs[2]],
        [docs[1]]
      ]
      Ruber[:config][:state, :open_documents] = docs
      Ruber[:config][:state, :tabs] = views
      @plug.restore_documents
      tabs = Ruber[:main_window].tabs
      tabs.each_with_index do |t, i|
        t.to_a.each_with_index do |v, j|
          c = v.cursor_position
          c.line.should == 0
          c.column.should == 0
        end
      end
    end
    
    it 'gives focus to the editor corresponding to the value in the active_editor entry' do
      docs = [nil, __FILE__, File.join(File.dirname(__FILE__), 'common.rb'), nil].map{|f| f ? 'file://' + f : nil}
      views =[
        [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
        [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
        [0]
      ]
      Ruber[:config][:state, :open_documents] = docs
      Ruber[:config][:state, :tabs] = views
      Ruber[:config][:state, :active_view] = [1, 1]
      flexmock(Ruber[:main_window]).should_receive(:focus_on_editor).once.with(FlexMock.on{|v, h| v == Ruber[:main_window].tabs[1].to_a[1]})
      @plug.restore_documents
    end
    
    it 'doesn\'t attempt to give focus to an editor if the active_editor entry is nil' do
      docs = [nil, __FILE__, File.join(File.dirname(__FILE__), 'common.rb'), nil].map{|f| f ? 'file://' + f : nil}
      views =[
        [Qt::Vertical, [Qt::Horizontal, 'file://' + __FILE__, 1], 0],
        [Qt::Horizontal, 'file://' + File.join(File.dirname(__FILE__), 'common.rb'), 'file://' + __FILE__],
        [0]
      ]
      Ruber[:config][:state, :open_documents] = docs
      Ruber[:config][:state, :tabs] = views
      Ruber[:config][:state, :active_view] = nil
      flexmock(Ruber[:main_window]).should_receive(:focus_on_editor).never
      @plug.restore_documents
    end
    
    it 'uses the settings stored in the object passed as a argument instead of those in the global configuration object' do
      docs = [nil, 'file://'+__FILE__]
      conf = flexmock do |m|
        m.should_receive(:[]).with(:state, :open_documents).once.and_return docs
        m.should_receive(:[]).with(:state, :tabs).once.and_return []
        m.should_receive(:[]).with(:state, :active_view).once.and_return nil
        m.should_receive(:[]).with(:state, :cursor_positions).once.and_return []
      end
      flexmock(Ruber[:config]).should_receive(:[]).never
      @plug.restore_documents conf
      documents = Ruber[:documents].to_a
      documents.size.should == 2
      documents[0].should be_pristine
      documents[1].path.should == __FILE__
    end
    
  end
  
  describe 'restore' do
    
    it 'calls the restore_projects method if the state/open_project setting is not empty' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :open_projects).and_return %w[/xyz/abc.ruprj]
      flexmock(@plug).should_receive(:restore_projects).once.with(Ruber[:config])
      @plug.restore
    end
    
    it 'calls the restore_documents method if the state/open_projects setting is empty' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:state, :open_projects).and_return []
      flexmock(@plug).should_receive(:restore_documents).once.with(Ruber[:config])
      @plug.restore
    end
    
    it 'uses the argument, rather than the config object, if one is given' do
      flexmock(Ruber[:config]).should_receive(:[]).never
      h = {[:state, :open_projects] => %w[/xyz/abc.ruprj]}
      def h.[](group, name)
        super [group, name]
      end
      flexmock(@plug).should_receive(:restore_projects).once.with(h)
      @plug.restore h
      h[[:state, :open_projects]] = []
      flexmock(@plug).should_receive(:restore_documents).once.with(h)
      @plug.restore h
    end
    
  end
  
  describe 'restore_last_state' do
    
    describe ', when the state/startup_behaviour option is :restore_all' do
      
      it 'calls the restore method' do
        flexmock(Ruber[:config]).should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_all
        flexmock(@plug).should_receive(:restore).once
        @plug.restore_last_state
      end
      
    end
    
    describe ', when the state/startup_behaviour option is :restore_projects_only' do
      
      it 'calls restore_project from within a with block with :restore_project_files set to false' do
        flexmock(Ruber[:config]).should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_projects_only
        flexmock(@plug).should_receive(:restore_projects).once
        flexmock(@plug).should_receive(:with).once.with({:restore_project_files => false}, FlexMock.on{|a| a.call || a.is_a?(Proc)})
        @plug.restore_last_state
      end
      
    end
    
    describe ', when the state/startup_behaviour option is :restore_documents_only' do
      
      it 'calls restore_documents' do
        flexmock(Ruber[:config]).should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_documents_only
        flexmock(@plug).should_receive(:restore_documents).once
        @plug.restore_last_state
      end
      
    end
    
    describe ', when the state/startup_behaviour option is :restore_nothing' do
      
      it 'does nothing' do
        flexmock(Ruber[:config]).should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_nothing
        flexmock(@plug).should_receive(:with).never
        flexmock(@plug).should_receive(:restore_projects).never
        flexmock(@plug).should_receive(:restore_documents).never
        flexmock(@plug).should_receive(:restore).never
        @plug.restore_last_state
      end
      
    end
    
  end
  
end

describe Ruber::State::DocumentExtension do
  
  before do
    Ruber[:components].load_plugin 'plugins/state/'
    Ruber[:documents].close_all(false)
    @plug = Ruber[:components][:state]
    @doc = Ruber[:documents].document __FILE__
    @prj = @doc.own_project
    @ext = @doc.own_project.extension(:state)
  end
  
  after do
    Ruber[:documents].close_all(false)
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
    
#       it 'keeps using the view which last got focus' do
#         views = 3.times.map{@doc.create_view}
#         views[1].instance_eval{emit focus_in(self)}
#         views[0].instance_eval{emit focus_in(self)}
#         flexmock(@ext).should_receive(:save_settings)
#         views[1].close
#         flexmock(@prj).should_receive(:[]).with(:state, :cursor_position).never
#         flexmock(views[0]).should_receive(:cursor_position).once.and_return(KTextEditor::Cursor.new(2,3))
#         @doc.create_view
#       end

    
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

    context 'if the state plugin wants the cursor position restored' do
    
      it 'calls the restore method if the State plugins wants the curesor position restored' do
        view = @doc.create_view
        flexmock(@plug).should_receive(:restore_cursor_position?).once.and_return true
        flexmock(@ext).should_receive(:restore).once.with(view)
        @ext.send :auto_restore, view
      end
    
    end
    
    context 'if the state plugin doesn\'t want the cursor position restored' do
    
      it 'does nothing' do
        view = @doc.create_view
        flexmock(@plug).should_receive(:restore_cursor_position?).once.and_return false
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
      
      it 'after behaves as if no other view had ever got focus' do
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

      it 'does nothing if the view is not the last which got focus' do
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
    Ruber[:documents].close_all(false)
    Ruber[:components].load_plugin 'plugins/state/'
    @plug = Ruber[:components][:state]
    @dir = File.join Dir.tmpdir, random_string(10)
    FileUtils.mkdir @dir
    @prj = Ruber[:projects].new_project File.join(@dir, 'test.ruprj'), 'Test'
    @ext = @prj.extension :state
  end
  
  after do
    FileUtils.rm_rf @dir
    Ruber[:components].unload_plugin :state
  end

  describe ', when created' do
    
    it 'connects the project\'s activated() signal to its auto_restore slot' do
      flexmock(@ext).should_receive(:auto_restore).once
      @prj.activate
    end
    
    it 'connects the save_settings slot to the deactivated signal of the project' do
      flexmock(@ext).should_receive(:save_settings).once
      @prj.instance_eval{emit deactivated}
    end
    
  end

  describe '#restore' do
    
    it 'calls the restore_documents method of the state plugin passing the project as argument' do
      flexmock(Ruber[:state]).should_receive(:restore_documents).once.with(@prj)
      @ext.restore
    end
    
  end

  describe '#save_settings' do
    
    it 'stores the entries returned by the documents_state and tabs_state entries of the state plugin in the project' do
      @prj.activate
      docs_state = ['file://'+__FILE__, nil]
      tabs_state = {
        :tabs => [['file://'+__FILE__], [0]],
        :cursor_positions => [],
        :active_view => [[1,0]]
      }
      state = Ruber[:state]
      flexmock(state).should_receive(:documents_state).once.and_return(docs_state)
      flexmock(state).should_receive(:tabs_state).once.and_return(tabs_state)
      @ext.save_settings
      @prj[:state, :open_documents].should == docs_state
      @prj[:state, :tabs].should == tabs_state[:tabs]
      @prj[:state, :active_view].should == tabs_state[:active_view]
      @prj[:state, :cursor_positions].should == tabs_state[:cursor_positions]
    end
    
  end
  
  describe 'auto_restore' do
    
    
    it 'disconnects the project\'s activated() signal from the extension' do
      flexmock(Ruber[:state]).should_receive(:restore_project_files?).once.and_return false
      @ext.send :auto_restore
      flexmock(@ext).should_receive(:auto_restore).never
      flexmock(@prj).instance_eval{emit activated}
    end

    it 'calls the restore method if the State plugins wants the project files restored' do
      flexmock(Ruber[:state]).should_receive(:restore_project_files?).once.and_return true
      flexmock(@ext).should_receive(:restore).once
      @ext.send :auto_restore
    end
    
    it 'does noting if the State plugins doesn\'t want the project_files restored' do
      flexmock(Ruber[:state]).should_receive(:restore_project_files?).once.and_return false
      flexmock(@ext).should_receive(:restore).never
      @ext.send :auto_restore
    end

    
  end
  
end