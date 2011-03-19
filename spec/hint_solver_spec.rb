require './spec/common'
require 'ruber/world/hint_solver'
require 'ruber/editor/document'
require 'ruber/pane'

describe Ruber::World::HintSolver do
  
  class HintSolverSpecComponentManager < Qt::Object
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
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(HintSolverSpecComponentManager.new).by_default
    @doc = Ruber::Document.new
  end
  
  context 'when created' do
    
    it 'takes the tab widget as argument' do
      tabs = KDE::TabWidget.new
      lambda{Ruber::World::HintSolver.new tabs, KParts::PartManager.new(@main_window), []}.should_not raise_error
    end
    
  end
  
  describe '#find_editor' do
    
    before do
      @tabs = KDE::TabWidget.new
      @solver = Ruber::World::HintSolver.new @tabs, KParts::PartManager.new(@main_window), []
      @doc = Ruber::Document.new nil
    end
    
    context 'when the tab widget contains no tabs' do
      
      it 'returns nil' do
        @solver.find_editor(@doc, {}).should be_nil
      end
      
    end
    
    context 'if the tab widget doesn\'t contain any editor for the given document' do
      
      before do
        other_doc = Ruber::Document.new nil
        views = 3.times.map{other_doc.create_view}
        pane1 = Ruber::Pane.new views[0]
        pane1.split views[0], views[1], Qt::Vertical
        @tabs.add_tab pane1, '1'
        pane2 = Ruber::Pane.new views[2]
        @tabs.add_tab pane2, '2'
      end
      
      it 'returns nil' do
        @solver.find_editor(@doc, {}).should be_nil
      end
      
    end
    
    context 'if the existing hint is never' do
      
      it 'always returns nil' do
        @solver.find_editor(@doc, :existing => :never).should be_nil
        view = @doc.create_view
        @tabs.add_tab Ruber::Pane.new(view), '1'
        @solver.find_editor(@doc, :existing => :never).should be_nil
      end
      
    end
    
    context 'when an editor already exists for the document' do
    
      context 'if the existing hint is :always' do
        
        before do
          @view = @doc.create_view
          other_doc = Ruber::Document.new nil
          views = 3.times.map{other_doc.create_view}
          pane1 = Ruber::Pane.new views[0]
          pane1.split views[0], views[1], Qt::Vertical
          @tabs.add_tab pane1, '1'
          pane2 = Ruber::Pane.new views[2]
          pane2.split views[2], @view, Qt::Vertical
          @tabs.add_tab pane2, '2'
        end
        
        it 'returns the existing view if it is in the current tab' do
          @tabs.current_index = 1
          @solver.find_editor(@doc, :existing => :always).should == @view
        end
        
        it 'returns the existing view if it is not in the current tab' do
          @tabs.current_index = 0
          @solver.find_editor(@doc, :existing => :always).should == @view
        end
        
      end
      
      context 'if the existing hint is :current_tab' do
        
        before do
          @view = @doc.create_view
          other_doc = Ruber::Document.new nil
          views = 3.times.map{other_doc.create_view}
          pane1 = Ruber::Pane.new views[0]
          pane1.object_name = '1'
          pane1.split views[0], views[1], Qt::Vertical
          @tabs.add_tab pane1, '1'
          pane2 = Ruber::Pane.new views[2]
          pane2.split views[2], @view, Qt::Vertical
          pane2.object_name = '2'
          @tabs.add_tab pane2, '2'
        end
        
        it 'returns the existing view if it is in the current tab' do
          @tabs.current_index = 1
          @solver.find_editor(@doc, :existing => :current_tab).should == @view
        end
        
        it 'returns nil if the existing view is not in the current tab' do
          @tabs.current_index = 0
          @solver.find_editor(@doc, :existing => :current_tab).should be_nil
        end
        
      end
      
    end
    
    context 'if only one editor respects the existing hint' do
      
      it 'returns that editor, regardless of the strategy hint' do
        view = @doc.create_view
        other_doc = Ruber::Document.new
        other_view = other_doc.create_view
        pane = Ruber::Pane.new other_view
        pane.split other_view, view, Qt::Vertical
        @tabs.add_tab pane, 'x'
        @solver.find_editor(@doc, :strategy => :current).should == view
      end
      
    end
    
    context 'if more than an editor exists for the given document' do
      
      before do
        @views = 3.times.map{@doc.create_view}
        other_doc = Ruber::Document.new nil
        @other_views = 3.times.map{other_doc.create_view}
        pane1 = Ruber::Pane.new @other_views[0]
        pane1.object_name = '1'
        pane1.split @other_views[0], @other_views[1], Qt::Vertical
        pane1.split @other_views[1], @views[0], Qt::Horizontal
        @tabs.add_tab pane1, '1'
        pane2 = Ruber::Pane.new @other_views[2]
        pane2.split @other_views[2], @views[1], Qt::Vertical
        pane2.object_name = '2'
        @tabs.add_tab pane2, '2'
        @view_order = @solver.instance_variable_get(:@view_order)
      end
      
      context 'if the first entry in the strategy hint is :current' do
        
        it 'returns the current editor, if it is associated with the document' do
          @view_order << @views[1] << @other_views[2] << @other_views[1] << @views[0] << @views[2] << @other_views[0]
          @solver.find_editor( @doc, :existing => :always, :strategy => [:current]).should == @views[1]
        end
        
        it 'doesn\'t return the current editor if it\'s not associated with the document' do
          flexmock(@pm).should_receive(:active_part).and_return(@other_views[1].send(:internal))
          @view_order << @other_views[1] << @other_views[2] << @views[1] << @views[0] << @views[2] << @other_views[0]
          @solver.find_editor( @doc, :existing => :always, :strategy => [:current]).should_not == @other_views[1]
        end
        
      end
      
      context 'if the first entry in the strategy hint is :current_tab' do
        
        it 'returns the first editor in the current tab which corresponds to the document, if any' do
          flexmock(@pm).should_receive(:active_part).and_return(@views[1].send(:internal))
          @tabs.current_index = 0
          view = @doc.create_view
          @tabs.current_widget.split @views[0], view, Qt::Horizontal, :before
          @solver.find_editor( @doc, :existing => :always, :strategy => [:current_tab]).should == view
        end
        
      end
      
      context 'if the first entry in the strategy hint is :last_current_tab' do
        
        it 'returns the last editor in the current tab associated with the document, if the tab contains more than one editor associated with it' do
          @tabs.current_index = 0
          view = @doc.create_view
          @tabs.current_widget.split @views[0], view, Qt::Horizontal, :before
          @solver.find_editor( @doc, :existing => :always, :strategy => [:last_current_tab]).should == @views[0]
        end
        
        it 'returns the editor associated with the document in the current tab if there\'s only one such editor' do
          @tabs.current_index = 0
          @solver.find_editor( @doc, :existing => :always, :strategy => [:last_current_tab]).should == @views[0]
        end
        
      end
      
      context 'if the first entry in the strategy hint is :next' do
        
        it 'returns the first editor in the current tab associated with the document, if any' do
          @tabs.current_index = 0
          view = @doc.create_view
          @tabs.current_widget.split @views[0], view, Qt::Horizontal, :before
          @solver.find_editor( @doc, :existing => :always, :strategy => [:next]).should == view
        end
        
        it 'returns the first editor associated with the document it finds, starting from the current tab if no editor for the document exists in the current tab' do
          other_doc = Ruber::Document.new
          other_view = other_doc.create_view
          pane = Ruber::Pane.new other_view
          @tabs.insert_tab 1, pane, 'new'
          @tabs.current_index = 1
          @tabs.widget(2).split @views[1], @views[2], Qt::Horizontal
          @solver.find_editor(@doc, :existing => :always, :strategy => [:next]).should == @views[1]
        end
        
        it 'returns the first editor associated with the document starting from the first tab if no editor in or after the current tab is found' do
          other_doc = Ruber::Document.new
          other_view = other_doc.create_view
          pane = Ruber::Pane.new other_view
          @tabs.add_tab pane, 'new'
          pane2 = Ruber::Pane.new other_doc.create_view
          @tabs.add_tab pane2, 'new2'
          @tabs.current_index = 2
          @solver.find_editor(@doc, :existing => :always, :strategy => [:next]).should == @views[0]
        end
        
      end
      
      context 'if the first entry in the strategy hint is :previous' do
      
        it 'returns the first editor associated with the document it finds, starting from the tab before the current and going backwards tab' do
          other_doc = Ruber::Document.new
          other_view = other_doc.create_view
          pane = Ruber::Pane.new other_view
          @tabs.insert_tab 1, pane, 'new'
          @tabs.widget(0).split @views[0], @views[2], Qt::Horizontal
          @tabs.current_index = 1
          @solver.find_editor(@doc, :existing => :always, :strategy => [:previous]).should == @views[2]
        end
      
        it 'returns the last editor associated with the document starting from the last tab if no editor before the current tab is found' do
          other_doc = Ruber::Document.new
          other_view = other_doc.create_view
          pane = Ruber::Pane.new other_view
          @tabs.insert_tab 1, pane, 'new'
          pane2 = Ruber::Pane.new other_doc.create_view
          @tabs.insert_tab 0, pane2, 'new2'
          @tabs.current_index = 1
          @solver.find_editor(@doc, :existing => :always, :strategy => [:previous]).should == @views[1]
        end
      
      end
      
      context 'if the first entry in the strategy hint is :first' do
        
        it 'returns the first editor associated with the document' do
          @solver.find_editor(@doc, :existing => :always, :strategy => [:first]).should == @views[0]
        end
        
      end
      
      context 'if the first entry in the strategy hint is :last' do
        
        it 'returns the last editor associated with the document' do
          @solver.find_editor(@doc, :existing => :always, :strategy => [:last]).should == @views[1]
        end
        
      end
      
      context 'if the first entry in the strategy hint is :last_used' do
        
        it 'returns the editor which respects the existing hint and comes first in the view_order list among those associated with the document' do
          @tabs.clear
          views = 3.times.map{@doc.create_view}
          other_doc = Ruber::Document.new
          other_views = 3.times.map{other_doc.create_view}
          order = @solver.instance_variable_get(:@view_order)
          order << other_views[1] << views[2] << other_views[0] << other_views[2] << views[0] << views[1]
          pane1 = Ruber::Pane.new other_views[0]
          pane1.split other_views[0], views[1], Qt::Vertical
          @tabs.add_tab pane1, '1'
          pane2 = Ruber::Pane.new views[0]
          pane2.split views[0], views[2], Qt::Vertical
          @tabs.add_tab pane2, '2'
          pane3 = Ruber::Pane.new other_views[1]
          pane3.split other_views[1], other_views[2], Qt::Vertical
          @tabs.add_tab pane3, '3'
          @solver.find_editor(@doc, :existing => :always, :strategy => [:last_used]).should == views[2]
        end
        
      end
      
      it 'attempts all the listed strategies until one succeeds' do
        other_doc = Ruber::Document.new
        pane = Ruber::Pane.new other_doc.create_view
        @tabs.add_tab pane, 'new'
        @tabs.current_index = 2
        @solver.find_editor(@doc, :existing => :always, :strategy => [:current, :last]).should == @views[1]
      end
      
      it 'uses :next as fallback strategy if all listed strategies fail' do
        other_doc = Ruber::Document.new
        pane = Ruber::Pane.new other_doc.create_view
        @tabs.insert_tab 1, pane, 'new'
        @tabs.current_index = 1
        @solver.find_editor(@doc, :existing => :always, :strategy => :current).should == @views[1]
      end
      
    end
    
  end
  
  describe '#place_editor' do
    
    before do
      @tabs = KDE::TabWidget.new
      @solver = Ruber::World::HintSolver.new @tabs, KParts::PartManager.new(@main_window), []
      @doc = Ruber::Document.new nil
    end
    
    context 'when the new hint is :new_tab' do
      
      it 'returns nil' do
        @solver.place_editor(:new => :new_tab).should be_nil
      end
      
    end
    
    context 'when the new hint is current' do
      
      it 'returns the current view' do
        views = 3.times.map{@doc.create_view}
        pane1 = Ruber::Pane.new views[0]
        pane2 = Ruber::Pane.new views[1]
        pane2.split views[1], views[2], Qt::Horizontal
        @tabs.add_tab pane1, '1'
        @tabs.add_tab pane2, '2'
        @tabs.current_index = 1
        view_order = @solver.instance_variable_get(:@view_order)
        view_order << views[2] << views[1] << views[0]
        @solver.place_editor(:new => :current).should == views[2]
      end
      
      it 'returns nil if there\'s no tab' do
        @solver.place_editor(:new => :current).should be_nil
      end
      
      it 'returns nil if the current view can\'t be found' do
        views = 3.times.map{@doc.create_view}
        pane1 = Ruber::Pane.new views[0]
        pane2 = Ruber::Pane.new views[1]
        pane2.split views[1], views[2], Qt::Horizontal
        @tabs.add_tab pane1, '1'
        @tabs.add_tab pane2, '2'
        @tabs.current_index = 1
        @solver.place_editor(:new => :current).should be_nil
      end
      
    end
    
    context 'when the new hint is :current_tab' do
      
      it 'returns the first view in the current tab' do
        views = 3.times.map{@doc.create_view}
        pane1 = Ruber::Pane.new views[0]
        pane2 = Ruber::Pane.new views[1]
        pane2.split views[1], views[2], Qt::Horizontal
        @tabs.add_tab pane1, '1'
        @tabs.add_tab pane2, '2'
        @tabs.current_index = 1
        @solver.place_editor(:new => :current_tab).should == views[1]
      end
      
      it 'returns nil if there\'s no tab' do
        @solver.place_editor(:new => :current_tab).should be_nil
      end
      
    end
    
    context 'when the new hint is an integer' do
      
      it 'returns the first view in the tab with that index' do
        views = 3.times.map{@doc.create_view}
        pane1 = Ruber::Pane.new views[0]
        pane2 = Ruber::Pane.new views[1]
        pane2.split views[1], views[2], Qt::Horizontal
        @tabs.add_tab pane1, '1'
        @tabs.add_tab pane2, '2'
        @tabs.current_index = 0
        @solver.place_editor(:new => 1).should == views[1]
      end
      
      it 'returns nil if there\'s not a pane with that index' do
        @solver.place_editor(:new => 1).should be_nil
        
        views = 3.times.map{@doc.create_view}
        pane1 = Ruber::Pane.new views[0]
        pane2 = Ruber::Pane.new views[1]
        pane2.split views[1], views[2], Qt::Horizontal
        @tabs.add_tab pane1, '1'
        @tabs.add_tab pane2, '2'
        @tabs.current_index = 0
        @solver.place_editor(:new => 5).should be_nil
      end
      
    end
    
    context 'when the new hint is a view' do
      
      it 'returns the view' do
        views = 3.times.map{@doc.create_view}
        pane1 = Ruber::Pane.new views[1]
        pane1.split views[1], views[2], Qt::Vertical
        pane2 = Ruber::Pane.new views[0]
        @tabs.add_tab pane1, '1'
        @tabs.add_tab pane2, '2'
        @solver.place_editor(:new =>  views[2]).should == views[2]
      end
      
      it 'returns nil if the view\'s parent isn\'t a pane' do
        view = @doc.create_view
        @solver.place_editor(:new =>  view).should be_nil
        w = Qt::Widget.new
        view = @doc.create_view w
        @solver.place_editor(:new =>  view).should be_nil
      end
      
    end
    
  end
  
end