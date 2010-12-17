require './spec/common'

require 'forwardable'

require 'ruber/main_window/view_manager'
require 'ruber/editor/document'

describe Ruber::MainWindow::ViewManager do
  
  class ViewManagerSpecComponentManager < Qt::Object
    extend Forwardable
    signals 'component_loaded(QObject*)', 'unloading_component(QObject*)'
    def_delegators :@data, :[], :<<
    def_delegator :@data, :each, :each_component
    
    def initialize parent = nil
      super
      @data = []
    end
    
  end
      
  before do
    @main_window = Qt::Widget.new
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@main_window).by_default
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(ViewManagerSpecComponentManager.new).by_default
    @tabs = KDE::TabWidget.new
  end
  
  it 'derives from Qt::Object' do
    Ruber::MainWindow::ViewManager.ancestors.should include(Qt::Object)
  end
  
  context 'when created' do
    
    
    it 'takes the tab widget and a toplevel parent widget as argument' do
      manager = Ruber::MainWindow::ViewManager.new @tabs, @main_window
      manager.parent.should == @main_window
    end
    
    it 'creates a part manager for its parent' do
      manager = Ruber::MainWindow::ViewManager.new @tabs, @main_window
      pm = manager.instance_variable_get(:@part_manager)
      pm.should be_a(KParts::PartManager)
    end
    
  end
  
  describe '#editor_for' do
    
    before do
      @manager = Ruber::MainWindow::ViewManager.new @tabs, @main_window
      @doc = Ruber::Document.new
    end
    
    it 'uses a HintSolver to find out the editor to return' do
      hs = @manager.instance_variable_get(:@solver)
      views = 2.times.map{@doc.create_view}
      hints = {:existing => :always, :strategy => :last_used}
      flexmock(hs).should_receive(:find_editor).once.with(@doc, hints).and_return views[1]
      @manager.editor_for(@doc, hints).should == views[1]
    end
    
    it 'returns nil if the hint solver can\'t find an editor and the :create_if_needed hint is false' do
      @manager.editor_for(@doc, {:create_if_needed => false}).should be_nil
    end
        
  end
  
end