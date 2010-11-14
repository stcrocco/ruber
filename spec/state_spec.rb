require './spec/common'

require 'tempfile'
require 'fileutils'

require 'ruber/plugin_specification'
require 'ruber/editor/document'

require 'plugins/state/state'

describe Ruber::State::Plugin do
  
  before do
    #Needed because the Qt::Object connect method doesn't like @components not being a
    #Qt::Object
    class Ruber::State::Plugin
      def connect *args
      end
    end
    @components = flexmock('components'){|m| m.should_ignore_missing}
    @config = flexmock('config'){|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components).by_default
    flexmock(Ruber).should_receive(:[]).with(:app).and_return(KDE::Application.instance).by_default
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    pdf = Ruber::PluginSpecification.full :name => :state
    @plug = Ruber::State::Plugin.new pdf
  end
  
  after do
    class Ruber::State::Plugin
      remove_method :connect rescue nil
    end
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
    
    before do
      @documents = flexmock('documents')
      @projects = flexmock('projects')
      flexmock(KDE::Application.instance).should_receive(:starting?).and_return(true).by_default
      flexmock(Ruber).should_receive(:[]).with(:docs).and_return(@documents).by_default
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    end
    
    it 'calls the restore_last_state method if there\'s no open project and the only open document is pristine' do
      doc = flexmock('doc', :pristine? => true)
      @documents.should_receive(:to_a).once.and_return [doc]
      @documents.should_receive(:[]).with(0).once.and_return doc
      @projects.should_receive(:to_a).once.and_return []
      flexmock(@plug).should_receive(:restore_last_state).once
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there are open projects' do
      prj = flexmock('project')
      @projects.should_receive(:to_a).once.and_return [prj]
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there is more than one open document' do
      @documents.should_receive(:to_a).once.and_return 2.times.map{flexmock}
      @projects.should_receive(:to_a).once.and_return []
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if there aren\'t open documents' do
      @documents.should_receive(:to_a).once.and_return []
      @projects.should_receive(:to_a).once.and_return []
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'doesn\'t call the restore_last_state method if the only open document isn\'t pristine' do
      doc = flexmock('doc', :pristine? => false)
      @documents.should_receive(:to_a).once.and_return [doc]
      @documents.should_receive(:[]).with(0).once.and_return doc
      @projects.should_receive(:to_a).once.and_return []
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
    it 'does nothing if the application is already running' do
      doc = flexmock('doc', :pristine? => true)
      @documents.should_receive(:to_a).and_return [doc]
      @documents.should_receive(:[]).with(0).and_return doc
      @projects.should_receive(:to_a).and_return []
      flexmock(KDE::Application.instance).should_receive(:starting?).and_return false
      flexmock(@plug).should_receive(:restore_last_state).never
      @plug.send :delayed_initialize
    end
    
  end
  
  describe '#gather_settings' do
    
    before do
      @projects = flexmock('projects') do |m| 
        m.should_receive(:projects).and_return([]).by_default
        m.should_receive(:current).and_return(nil).by_default
      end
      @documents = flexmock('documents') do |m| 
        m.should_receive(:documents).and_return([]).by_default
        m.should_receive(:current).and_return(nil).by_default
      end
      @mw = flexmock('main window'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      flexmock(Ruber).should_receive(:[]).with(:docs).and_return(@documents).by_default
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    end
    
    it 'stores a list with the project file of each open project under the :open_projects key' do
      prjs = 5.times.map{|i| flexmock(i.to_s){|m| m.should_receive(:project_file).and_return i.to_s}}
      @projects.should_receive(:projects).once.and_return(prjs)
      @projects.should_receive(:current).once.and_return(nil)
      @plug.send(:gather_settings).should have_entries(:open_projects => (0...5).map(&:to_s))
    end
    
    it 'puts the file corresponding to the open project at the beginning of the :open_projects entry' do
      prjs = 5.times.map{|i| flexmock(i.to_s, :project_file => i.to_s)}
      @projects.should_receive(:projects).once.and_return(prjs)
      @projects.should_receive(:current).once.and_return prjs[2]
      @plug.send(:gather_settings).should have_entries(:open_projects => %w[2 0 1 3 4])
    end
    
    it 'stores the project files in an arbitrary order if there\'s no active project' do
      prjs = 5.times.map{|i| flexmock(i.to_s){|m| m.should_receive(:project_file).and_return i.to_s}}
      @projects.should_receive(:projects).once.and_return(prjs)
      @projects.should_receive(:current).once.and_return nil
      @plug.send(:gather_settings).should have_entries(:open_projects => (0...5).map(&:to_s))
    end
    
    it 'stores an empty array under the :open_projects key if there are no open projects' do
      @plug.send(:gather_settings).should have_entries(:open_projects => [])
    end
    
    it 'stores a list of the URLs of the files associated with all open documents under the :open_files key' do
      docs = 5.times.map{|i| flexmock(i.to_s, :has_file? => true, :view => flexmock){|m| m.should_receive(:url).and_return KDE::Url.new("file:///xyz/file #{i}")}}
      @documents.should_receive(:documents).once.and_return(docs)
      exp = [
        'file:///xyz/file%200',
        'file:///xyz/file%201',
        'file:///xyz/file%202',
        'file:///xyz/file%203',
        'file:///xyz/file%204',
        ]
      @plug.send(:gather_settings).should have_entries(:open_documents => exp)
    end
    
    it 'ignores documents which aren\'t associated with a file' do
      docs = 5.times.map do |i| 
        flexmock(i.to_s, :view => flexmock) do |m|
          m.should_receive(:url).and_return(i % 2 == 0 ? KDE::Url.new("file:///xyz/file #{i}") : KDE::Url.new)
          m.should_receive(:has_file?).and_return(i % 2 == 0)
        end
      end
      @documents.should_receive(:documents).once.and_return(docs)
      exp = [
        'file:///xyz/file%200',
        'file:///xyz/file%202',
        'file:///xyz/file%204',
        ]
      @plug.send(:gather_settings).should have_entries(:open_documents => exp)
    end
    
    it 'stores an empty array under the :open_files key if there are no open documents or if no open document is associated with a file' do
      docs = 5.times.map{flexmock(:url => KDE::Url.new, :has_file? => false)}
      @documents.should_receive(:documents).once.and_return(docs).once
      @documents.should_receive(:documents).once.and_return([]).once
      @plug.send(:gather_settings).should have_entries(:open_documents => [])
      @plug.send(:gather_settings).should have_entries(:open_documents => [])
    end
    
    it 'stores a list of the URLs associated with all the documents with an editor under the :visible_documents key' do
      docs = 5.times.map do |i| 
        flexmock(i.to_s) do |m| 
          m.should_receive(:url).and_return KDE::Url.new("file:///xyz/file #{i}")
          m.should_receive(:view).and_return(i % 2 == 0 ? flexmock("view #{i}") : nil)
          m.should_receive(:has_file?).and_return(i % 2 == 0)
        end
      end
      @documents.should_receive(:documents).once.and_return(docs)
      exp = [
        'file:///xyz/file%200',
        'file:///xyz/file%202',
        'file:///xyz/file%204',
        ]
      @plug.send(:gather_settings).should have_entries(:visible_documents => exp)
    end
    
    it 'doesn\'t insert files not associated with a file under the visible_documents key' do
      docs = 5.times.map do |i| 
        flexmock(i.to_s) do |m| 
          m.should_receive(:url).and_return( i % 2 == 0 ? KDE::Url.new("file:///xyz/file #{i}") : KDE::Url.new)
          m.should_receive(:view).and_return(flexmock)
          m.should_receive(:has_file?).and_return(i % 2 == 0)
        end
      end
      @documents.should_receive(:documents).once.and_return(docs)
      exp = [
        'file:///xyz/file%200',
        'file:///xyz/file%202',
        'file:///xyz/file%204',
        ]
      @plug.send(:gather_settings).should have_entries(:visible_documents => exp)
    end
    
    it 'stores an empty array under the :open_files key if there is no open document with a view associated with a file' do
      docs = 5.times.map do |i| 
        flexmock(:url => KDE::Url.new, :has_file? => (i % 2 == 0), :view => (i % 2 == 0 ? nil : flexmock))
      end
      @documents.should_receive(:documents).once.and_return(docs).once
      @documents.should_receive(:documents).once.and_return([]).once
      @plug.send(:gather_settings).should have_entries(:visible_documents => [])
      @plug.send(:gather_settings).should have_entries(:visible_documents => [])
    end
    
    it 'stores the path of the active document under the :active_document key' do
      docs = 5.times.map do |i| 
        flexmock(i.to_s, :has_file? => true, :view => flexmock) do |m|
          m.should_receive(:url).and_return KDE::Url.new("file:///xyz/file #{i}")
        end
      end
      @documents.should_receive(:documents).once.and_return(docs)
      @mw.should_receive(:current_document).once.and_return(docs[1])
      exp = "file:///xyz/file%201"
      @plug.send(:gather_settings).should have_entries(:active_document => exp)
    end
    
    it 'stores nil under the :active_document key if there\'s no current document' do
      @mw.should_receive(:current_document).once.and_return nil
      @plug.send(:gather_settings).should have_entries(:active_document => nil)
    end
    
    it 'stores nil under the :active_document key if the current document isn\'t associated with a file' do
      doc = flexmock('doc', :path => '')
      @mw.should_receive(:current_document).once.and_return doc
      @plug.send(:gather_settings).should have_entries(:active_document => nil)
    end
    
  end
  
  describe '#save_settings' do
    
    it 'stores the value corresponding to the :open_projects key in the hash returned by gather_settings in the state/open_projects setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:open_projects => %w[x y z])
      @config.should_receive(:[]=).with(:state, :open_projects, %w[x y z]).once
      @config.should_receive(:[]=)
      @plug.save_settings
    end
    
    it 'stores the value corresponding to the :open_documents key in the hash returned by gather_settings in the state/open_documents setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:open_documents => %w[x y z])
      @config.should_receive(:[]=).with(:state, :open_documents, %w[x y z]).once
      @config.should_receive(:[]=)
      @plug.save_settings
    end
    
    it 'stores the value corresponding to the :active_document key in the hash returned by gather_settings in the state/active_document setting' do
      flexmock(@plug).should_receive(:gather_settings).once.and_return(:active_document => 'x')
      @config.should_receive(:[]=).with(:state, :active_document, 'x').once
      @config.should_receive(:[]=)
      @plug.save_settings
    end
    
  end
  
  describe '#restore_cursor_position?' do
    
    it 'returns the value of the state/restore_cursor_position config entry if the @force_restore_cursor_position instance variable is nil' do
      @config.should_receive(:[]).with(:state, :restore_cursor_position).once.and_return(true)
      @config.should_receive(:[]).with(:state, :restore_cursor_position).once.and_return(false)
      @plug.instance_variable_set :@force_restore_cursor_position, nil
      @plug.restore_cursor_position?.should == true
      @plug.restore_cursor_position?.should == false
    end
    
    it 'returns the value of the @force_restore_cursor_position instance variable if it is not nil' do
      @config.should_receive(:[]).with(:state, :restore_cursor_position).never
      @plug.instance_variable_set :@force_restore_cursor_position, true
      @plug.restore_cursor_position?.should == true
      @plug.instance_variable_set :@force_restore_cursor_position, false
      @plug.restore_cursor_position?.should == false
    end
    
  end
  
  describe '#restore_project_files?' do
    
    it 'returns the value of the state/restore_project_files config entry if the @force_restore_project_files instance variable is nil' do
      @config.should_receive(:[]).with(:state, :restore_project_files).once.and_return(true)
      @config.should_receive(:[]).with(:state, :restore_project_files).once.and_return(false)
      @plug.instance_variable_set :@force_restore_project_files, nil
      @plug.restore_project_files?.should == true
      @plug.restore_project_files?.should == false
    end
    
    it 'returns the value of the @force_restore_project_files instance variable if it is not nil' do
      @config.should_receive(:[]).with(:state, :restore_project_files).never
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
        :active_document => 'z'
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
          :active_document => 'z'
        }
      }
      exp_hash = {
        [:state, :open_projects] => %w[a b c],
        [:state, :open_documents] => %w[x y z],
        [:state, :active_document] => 'z'
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
    
    before do
      @projects = flexmock('projects'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
      @mw = flexmock{|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    end
    
    it 'closes all projects' do
      prjs = 3.times.map{|i| flexmock(i.to_s)}
      prjs.each{|pr| @projects.should_receive(:close_project).with(pr).once}
      @projects.should_receive(:to_a).once.and_return(prjs)
      @plug.restore_projects
    end
    
    it 'uses the safe_open_project method of the main window to open the first entry of the state/open_projects setting' do
      @config.should_receive(:[]).with(:state, :open_projects).once.and_return %w[/x/y/z.ruprj /a/b/c.ruprj]
      prj = flexmock('project')
      @mw.should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return prj
      @plug.restore_projects
    end
    
    it 'activates the project returned by safe_open_project' do
      @config.should_receive(:[]).with(:state, :open_projects).once.and_return %w[/x/y/z.ruprj /a/b/c.ruprj]
      prj = flexmock('project')
      @mw.should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return prj
      @projects.should_receive(:current_project=).once.with(prj)
      @plug.restore_projects
    end
    
    it 'doesn\'t attempt to activate the project if safe_open_project returned nil' do
      @config.should_receive(:[]).with(:state, :open_projects).once.and_return %w[/x/y/z.ruprj /a/b/c.ruprj]
      prj = flexmock('project')
      @mw.should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return nil
      @projects.should_receive(:current_project=).never
      lambda{@plug.restore_projects}.should_not raise_error
    end
    
    it 'does nothing if the state/open_projects setting is empty' do
      @config.should_receive(:[]).with(:state, :open_projects).once.and_return []
      prj = flexmock('project')
      @projects.should_receive(:project).never
      @projects.should_receive(:current_project=).never
      @plug.restore_projects
    end
    
    it 'reads the settings from the argument, if given, rather than from the config object' do
      @config.should_receive(:[]).never
      h = {[:state, :open_projects] => ['/x/y/z.ruprj']}
      def h.[] group, name
        super [group, name]
      end
      prj = flexmock('project')
      @mw.should_receive(:safe_open_project).once.with('/x/y/z.ruprj').and_return prj
      @projects.should_receive(:current_project=).once.with(prj)
      @plug.restore_projects h
    end
    
  end
  
  describe '#restore_documents' do
    
    before do
      @mw = flexmock('main window'){|m| m.should_ignore_missing}
      @docs = flexmock('documents'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:docs).and_return(@docs).by_default
    end
    
    it 'closes all open documents' do
      @docs.should_receive(:close_all).once
      @plug.restore_documents
    end
    
    it 'creates a new document for each entry in the state/open_documents' do
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :active_document)
      @config.should_receive(:[]).with(:state, :visible_documents).and_return []
      files.each{|f| @docs.should_receive(:document).once.with(KDE::Url.new(f)).ordered}
      @mw.should_receive(:without_activating) #.once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @plug.restore_documents
    end
    
    it 'creates a new editor for each entry in the state/visible_documents from within a block passed to the main window\'s without_activating method' do
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :visible_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :active_document)
      docs = files.map{|f| flexmock("doc #{f}", :url => KDE::Url.new(f))}
      files.each_with_index{|f, i| @docs.should_receive(:document).with(f).once.and_return docs[i]}
      docs.each{|d| @mw.should_receive(:editor_for!).once.with(d).ordered}
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @plug.restore_documents
    end
    
    it 'doesn\'t attempt to open a document for an entry corresponding to a local file whih doesn\'t exist anymore' do
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :active_document)
      @config.should_receive(:[]).with(:state, :visible_documents).once.and_return []
      docs = files.map{|f| flexmock("doc #{f}", :url => KDE::Url.new(f))}
      @docs.should_receive(:document).once.with(files[0]).ordered.and_return(docs[0])
      @docs.should_receive(:document).once.with(files[1]).ordered.and_raise ArgumentError
      @docs.should_receive(:document).once.with(files[2]).ordered.and_return(docs[2])
      lambda{@plug.restore_documents}.should_not raise_error
    end
    
    it 'activates the document corresponding to the file specified in the state/active_document setting' do
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      docs = 3.times.map{|i| flexmock("doc#{i}", :url => KDE::Url.new(files[i]), :has_file? => true)}
      views = 3.times.map{|i| flexmock("view#{i}", :document => docs[i])}
      docs.each_with_index{|d, i| d.should_receive(:view).and_return views[i]}
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :active_document).once.and_return files[1]
      @config.should_receive(:[]).with(:state, :visible_documents).once.and_return files
      3.times{|i| @docs.should_receive(:document).with(files[i]).once.and_return(docs[i])}
      3.times{|i| @mw.should_receive(:editor_for!).once.with(docs[i]).and_return(views[i])}
      @mw.should_receive(:display_document).once.with(docs[1])
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @plug.restore_documents
    end
    
    it 'activates the last document if the state/active_document setting is nil' do
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      docs = 3.times.map{|i| flexmock("doc#{i}", :url => KDE::Url.new(files[i]))}
      views = 3.times.map{|i| flexmock("view#{i}", :document => docs[i])}
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :visible_documents).once.and_return files
      3.times{|i| @mw.should_receive(:editor_for!).once.with(docs[i]).and_return(views[i])}
      @config.should_receive(:[]).with(:state, :active_document).once.and_return nil
      3.times{|i| @docs.should_receive(:document).with(files[i]).once.and_return(docs[i])}
      @mw.should_receive(:display_document).once.with(docs[-1])
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @plug.restore_documents
    end
    
    it 'activates the last document if the state/active_document setting is a file not corresponding to an open document' do
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :visible_documents).once.and_return files
      @config.should_receive(:[]).with(:state, :active_document).once.and_return files[1]
      docs = 3.times.map{|i| flexmock("doc#{i}", :url => KDE::Url.new(files[i]))}
      views = 3.times.map{|i| flexmock("view#{i}", :document => docs[i])}
      3.times do |i|
        if i % 2 == 0
          @docs.should_receive(:document).with(files[i]).once.and_return(docs[i])
        else
          @docs.should_receive(:document).with(files[i]).once.and_raise ArgumentError
        end
      end
      [0, 2].each{|i| @mw.should_receive(:editor_for!).once.with(docs[i]).ordered.and_return(views[i])}
      @mw.should_receive(:display_document).once.with(docs[-1])
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @plug.restore_documents
    end
    
    it 'does nothing if the state/open_files entry is empty' do
      @config.should_receive(:[]).with(:state, :open_documents).once.and_return []
      lambda{@plug.restore_documents}.should_not raise_error
    end
    
    it 'reads the settings from the argument, if given, rather than from the config object' do
      @config.should_receive(:[]).never
      files = %w[/x/y/f1.rb /a/b/f2.rb /f3.rb].map{|f| "file://#{f}"}
      docs = 3.times.map{|i| flexmock("doc#{i}", :url => KDE::Url.new(files[i]))}
      views = 3.times.map{|i| flexmock("view#{i}", :document => docs[i])}
      files.each_with_index{|f, i| @docs.should_receive(:document).with(f).once.and_return(docs[i])}
      docs.each{|d| @mw.should_receive(:editor_for!).once.with(d).ordered}
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      h = {[:state, :open_documents] => files, [:state, :active_document] => nil, [:state, :visible_documents] => files}
      def h.[] group, name
        super [group, name]
      end
      @plug.restore_documents h
    end
    
  end
  
  describe 'restore' do
    
    it 'calls the restore_projects method if the state/open_project setting is not empty' do
      @config.should_receive(:[]).with(:state, :open_projects).and_return %w[/xyz/abc.ruprj]
      flexmock(@plug).should_receive(:restore_projects).once.with(@config)
      @plug.restore
    end
    
    it 'calls the restore_documents method if the state/open_projects setting is empty' do
      @config.should_receive(:[]).with(:state, :open_projects).and_return []
      flexmock(@plug).should_receive(:restore_documents).once.with(@config)
      @plug.restore
    end
    
    it 'uses the argument, rather than the config object, if one is given' do
      @config.should_receive(:[]).never
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
        @config.should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_all
        flexmock(@plug).should_receive(:restore).once
        @plug.restore_last_state
      end
      
    end
    
    describe ', when the state/startup_behaviour option is :restore_projects_only' do
      
      it 'calls restore_project from within a with block with :restore_project_files set to false' do
        @config.should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_projects_only
        flexmock(@plug).should_receive(:restore_projects).once
        flexmock(@plug).should_receive(:with).once.with({:restore_project_files => false}, FlexMock.on{|a| a.call || a.is_a?(Proc)})
        @plug.restore_last_state
      end
      
    end
    
    describe ', when the state/startup_behaviour option is :restore_documents_only' do
      
      it 'calls restore_documents' do
        @config.should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_documents_only
        flexmock(@plug).should_receive(:restore_documents).once
        @plug.restore_last_state
      end
      
    end
    
    describe ', when the state/startup_behaviour option is :restore_nothing' do
      
      it 'does nothing' do
        @config.should_receive(:[]).with(:state, :startup_behaviour).once.and_return :restore_nothing
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
  
  it 'inherits from Qt::Object' do
    Ruber::State::DocumentExtension.ancestors.should include(Qt::Object)
  end
  
  it 'includes the Ruber::Extension module' do
    Ruber::State::DocumentExtension.ancestors.should include(Ruber::Extension)
  end
  
  before do
    @components = flexmock{|m| m.should_ignore_missing}
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components).by_default
    @doc = Ruber::Document.new nil, __FILE__
    @ext = Ruber::State::DocumentExtension.new @doc.own_project
    @doc.own_project.add_extension :state, @ext
  end
  
  describe ', when created' do
    
    it 'connects the document\'s view_created(QObject*, QObject*) signal to its auto_restore slot' do
      flexmock(@ext).should_receive(:auto_restore).once
      @doc.create_view
    end
    
  end
  
  describe '#restore' do
    
    before do
      #Needed to avoid the need of creating a mock State plugin
      @doc.disconnect SIGNAL('view_created(QObject*, QObject*)'), @ext
    end
    
    it 'moves the cursor to the position stored in the document\'s project state/cursor_position setting' do
      view = @doc.create_view
      flexmock(@doc.own_project).should_receive(:[]).with(:state, :cursor_position).once.and_return([100, 20])
      flexmock(@doc.view).should_receive(:go_to).with(100, 20).once
      @ext.restore
    end
    
    it 'does nothing if the document doesn\'t have a view' do
      lambda{@ext.restore}.should_not raise_error
    end
    
  end
  
  describe '#save_settings' do
    
    before do
      #Needed to avoid the need of creating a mock State plugin
      @doc.disconnect SIGNAL('view_created(QObject*, QObject*)'), @ext
    end
    
    it 'stores an array containing the cursor position in the document\'s project state/cursor_position setting' do
      view = @doc.create_view
      flexmock(@doc.own_project).should_receive(:[]=).with(:state, :cursor_position, [100, 20]).once
      cur = KTextEditor::Cursor.new(100, 20)
      flexmock(@doc.view).should_receive(:cursor_position).once.and_return cur
      @ext.save_settings
    end

    it 'doesn\'t attempt to store the cursor position if the document has no view' do
      flexmock(@doc.own_project).should_receive(:[]=).with(:state, :cursor_position, Array).never
      @ext.save_settings
    end
    
  end
  
  describe 'auto_restore' do
    
    before do
      @plug = Object.new
      @plug.instance_variable_set :@force_restore_cursor_position, nil
      flexmock(Ruber).should_receive(:[]).with(:state).and_return(@plug).by_default
    end
    
    it 'calls the restore method if the State plugins wants the curesor position restored' do
      flexmock(@plug).should_receive(:restore_cursor_position?).once.and_return true
      flexmock(@ext).should_receive(:restore).once
      @ext.send :auto_restore
    end
    
    it 'does noting if the State plugins doesn\'t want the curesor position restored' do
      flexmock(@plug).should_receive(:restore_cursor_position?).once.and_return false
      flexmock(@ext).should_receive(:restore).never
      @ext.send :auto_restore
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
    @dir = File.join Dir.tmpdir, random_string(10)
    FileUtils.mkdir @dir
    @components = flexmock{|m| m.should_ignore_missing}
    @projects = Qt::Object.new
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(@components).by_default
    flexmock(Ruber).should_receive(:[]).with(:projects).and_return(@projects).by_default
    @prj = Ruber::Project.new 'Test', File.join(@dir, 'test.ruprj')
    @ext = Ruber::State::ProjectExtension.new @prj
    @prj.add_extension :state, @ext
  end
  
  after do
    FileUtils.rm_rf @dir
  end

  describe ', when created' do
    
    it 'connects the project\'s activated() signal to its auto_restore slot' do
      flexmock(@ext).should_receive(:auto_restore).once
      @prj.activate
    end
    
  end
  
  describe '#restore' do
    
    before do
      @mw = flexmock('main window'){|m| m.should_ignore_missing}
      @config = flexmock('config')
      @docs = flexmock('docs'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
      flexmock(Ruber).should_receive(:[]).with(:docs).and_return(@docs).by_default
    end
    
    it 'calls the document list\'s close_all method' do
      @docs.should_receive(:close_all).once
      flexmock(@prj).should_receive(:[]).with(:state, :open_documents).once.and_return []
      @ext.restore
    end
    
    it 'it calls the main_window\'s editor_for! for each entry in the project\'s state/open_documents setting from within a without_activating call' do
      files = %w[/a.rb /b.rb /c.rb]
      flexmock(@prj).should_receive(:[]).with(:state, :open_documents).once.and_return files
      flexmock(@prj).should_receive(:[]).with(:state, :active_document).once.and_return nil
      files.each{|f| @mw.should_receive(:editor_for!).with(f).once}
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @ext.restore
    end
    
    it 'activates the editor corresponding to the file in the project\'s state/active_document entry' do
      files = %w[/a.rb /b.rb /c.rb]
      flexmock(@prj).should_receive(:[]).with(:state, :open_documents).once.and_return files
      flexmock(@prj).should_receive(:[]).with(:state, :active_document).once.and_return files[1]
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @mw.should_receive(:display_document).once.with files[1]
      @ext.restore
    end
    
    it 'activates the editor corresponding to the last entry file in the project\'s state/open_documents entry if the state/active_documents entry is nil' do
      files = %w[/a.rb /b.rb /c.rb]
      editors = 3.times.map{|i| flexmock(i.to_s)}
      flexmock(@prj).should_receive(:[]).with(:state, :open_documents).once.and_return files
      flexmock(@prj).should_receive(:[]).with(:state, :active_document).once.and_return nil
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @mw.should_receive(:display_document).once.with files[-1]
      @ext.restore
    end

    it 'activates the editor corresponding to the last entry file in the project\'s state/open_documents entry if the state/active_documents doesn\'t correspond to one of the open files' do
      files = %w[/a.rb /b.rb /c.rb]
      flexmock(@prj).should_receive(:[]).with(:state, :open_documents).once.and_return files
      flexmock(@prj).should_receive(:[]).with(:state, :active_document).once.and_return '/d.rb'
      @mw.should_receive(:without_activating).once.with(FlexMock.on{|a| a.call || a.is_a?(Proc)})
      @mw.should_receive(:display_document).once.with files[-1]
      @ext.restore
    end
    
    it 'doesn\'t open any editor if the project\'s state/open_documents entry is empty' do
      files = []
      flexmock(@prj).should_receive(:[]).with(:state, :open_documents).once.and_return files
      flexmock(@prj).should_receive(:[]).with(:state, :active_document).and_return nil
      @mw.should_receive(:editor_for!).never
      @mw.should_receive(:editor_for).never
      @mw.should_receive(:without_activating).never
      @mw.should_receive(:activate_editor).never
      @ext.restore
    end
    
  end
  
  describe '#save_settings' do
    
    before do
      @mw = flexmock('main window'){|m| m.should_ignore_missing}
      @docs = flexmock('docs'){|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:docs).and_return(@docs).by_default
    end
    
    it 'stores the paths of the open documents associated with a file in the project\'s state/open_documents entry' do
      docs = %w[a b c].map{|i| flexmock(i.to_s, :path => "/#{i}")}
      @docs.should_receive(:documents_with_file).once.and_return docs
      flexmock(@prj).should_receive(:[]=).once.with :state, :open_documents, %w[a b c].map{|i| "/#{i}"}
      flexmock(@prj).should_receive(:[]=)
      @ext.save_settings
    end
    
    it 'stores an empty array in the project\'s state/open_documents entry if there\'s no open file or if none of them is associated with a document' do
      @docs.should_receive(:documents_with_file).once.and_return []
      flexmock(@prj).should_receive(:[]=).once.with :state, :open_documents, []
      flexmock(@prj).should_receive(:[]=)
      @ext.save_settings
    end
    
    it 'stores the path of the current document in the project\'s state/active_document entry' do
      docs = %w[a b c].map{|i| flexmock(i.to_s, :path => "/#{i}")}
      active = flexmock('doc', :path => '/b')
      @docs.should_receive(:documents_with_file).once.and_return docs
      @mw.should_receive(:current_document).once.and_return active
      flexmock(@prj).should_receive(:[]=).once.with :state, :active_document, '/b'
      flexmock(@prj).should_receive(:[]=)
      @ext.save_settings
    end
    
    it 'stores nil in the project\'s state/active_document entry if there\'s no active document or the active document isn\'t associated with a file' do
      docs = %w[a b c].map{|i| flexmock(i.to_s, :path => "/#{i}")}
      active = flexmock('doc', :path => '')
      @docs.should_receive(:documents_with_file).twice.and_return docs
      @mw.should_receive(:current_document).once.and_return active
      @mw.should_receive(:current_document).once.and_return nil
      flexmock(@prj).should_receive(:[]=).twice.with :state, :active_document, nil
      flexmock(@prj).should_receive(:[]=)
      @ext.save_settings
      @ext.save_settings
    end
    
  end
  
  describe 'auto_restore' do
    
    before do
      @config = flexmock('config')
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
      @plug = Object.new
      @plug.instance_variable_set :@force_restore_project_files, nil
      flexmock(Ruber).should_receive(:[]).with(:state).and_return(@plug).by_default
    end
    
    it 'disconnects the project\'s activated() signal from the extension' do
      flexmock(@plug).should_receive(:restore_project_files?).once.and_return false
      @ext.send :auto_restore
      flexmock(@ext).should_receive(:auto_restore).never
      flexmock(@prj).instance_eval{emit activated}
    end

    it 'calls the restore method if the State plugins wants the project files restored' do
      flexmock(@plug).should_receive(:restore_project_files?).once.and_return true
      flexmock(@ext).should_receive(:restore).once
      @ext.send :auto_restore
    end
    
    it 'does noting if the State plugins doesn\'t want the project_files restored' do
      flexmock(@plug).should_receive(:restore_project_files?).once.and_return false
      flexmock(@ext).should_receive(:restore).never
      @ext.send :auto_restore
    end

    
  end
  
end