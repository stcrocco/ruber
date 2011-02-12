require './spec/common'
require 'ruber/pane'
require 'ruber/editor/document'

describe Ruber::Pane do
  
  class PaneSpecComponentManager < Qt::Object
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
    flexmock(Ruber).should_receive(:[]).with(:components).and_return(PaneSpecComponentManager.new).by_default
    @doc = Ruber::Document.new
  end
  
  it 'is enumerable' do
    Ruber::Pane.ancestors.should include(Enumerable)
  end
  
  context 'when created with one view' do
    
    it 'makes the view child of itself' do
      view = @doc.create_view nil
      pane = Ruber::Pane.new view
      view.parent.should == pane
    end
    
    it 'inserts the view in the layout' do
      view = @doc.create_view nil
      pane = Ruber::Pane.new view
      pane.layout.should include(view)
    end
    
    it 'allows a parent to be specified' do
      view = @doc.create_view nil
      w = Qt::Widget.new
      pane = Ruber::Pane.new view, w
      pane.parent.should == w
    end
    
  end
  
  context 'when created with two panes and an orientation' do
    
    before do
      @panes = 2.times.map{Ruber::Pane.new @doc.create_view(nil)}
    end
    
    it 'inserts the two panes in a splitter with the given orientation' do
      pane = Ruber::Pane.new Qt::Horizontal, @panes[0], @panes[1]
      splitter = pane.layout.find{|c| c.is_a? Qt::Splitter}
      splitter.should_not be_nil
      splitter.orientation.should == Qt::Horizontal
      splitter.widget(0).should == @panes[0]
      splitter.widget(1).should == @panes[1]
    end
    
     it 'makes the panes child of the splitter' do
       pane = Ruber::Pane.new Qt::Horizontal, @panes[0], @panes[1]
       splitter = pane.find_child(Qt::Splitter)
       @panes.each{|p| p.parent.should == splitter}
     end
     
     it 'allows a parent to be specified' do
       w = Qt::Widget.new
       pane = Ruber::Pane.new Qt::Horizontal, @panes[0], @panes[1], w
       pane.parent.should == w
     end
    
  end
  
  describe '#single_view?' do
    
    it 'returns true if the pane only contains one view' do
      pane = Ruber::Pane.new @doc.create_view(nil)
      pane.single_view?.should be_true
    end
    
    it 'returns false if the pane contains two views' do
      views = 2.times.map{@doc.create_view(nil)}
      pane = Ruber::Pane.new Qt::Vertical, views[0], views[1]
      pane.single_view?.should be_false
    end
    
  end
  
  describe '#orientation' do
    
    it 'returns nil if the pane contains a single view' do
      pane = Ruber::Pane.new @doc.create_view(nil)
      pane.orientation.should be_nil
    end
    
    it 'returns the orientation of the splitter if the pain contains multiple panes' do
      views = 2.times.map{@doc.create_view(nil)}
      pane = Ruber::Pane.new Qt::Vertical, views[0], views[1]
      pane.orientation.should == Qt::Vertical
      pane = Ruber::Pane.new Qt::Horizontal, views[0], views[1]
      pane.orientation.should == Qt::Horizontal
    end
    
  end
  
  describe '#view' do
    
    it 'returns the view if the pane contains a single view' do
      view = @doc.create_view(nil)
      pane = Ruber::Pane.new view
      pane.view.should == view
    end
    
    it 'returns nil if the pane contains multiple panes' do
      views = 2.times.map{@doc.create_view(nil)}
      pane = Ruber::Pane.new Qt::Vertical, views[0], views[1]
      pane.view.should be_nil
    end
    
  end
  
  describe '#split' do
    
    context 'if the pane contains a single view' do
      
      before do
        @view = @doc.create_view nil
        @pane = Ruber::Pane.new @view
      end
      
      shared_examples_for '#split when the pane contains a single view' do
        
        it 'inserts the pane containing each of the views in a splitter with the given orientation' do
          view = @doc.create_view nil
          @pane.split @view, view, Qt::Vertical, @pos
          @pane.single_view?.should be_false
          splitter = @pane.splitter
          splitter.should be_a(Qt::Splitter)
          splitter.orientation.should == Qt::Vertical
          splitter.count.should == 2
          splitter.each{|w| w.should be_a(Ruber::Pane)}
          splitter.widget(@old_idx).view.should == @view
          splitter.widget(@new_idx).view.should == view
        end
        
        it 'returns an array with the pane containing the old view as first element and the pane containing the new view as second element' do
          view = @doc.create_view nil
          res = @pane.split @view, view, Qt::Horizontal, @pos
          res[0].should be_a(Ruber::Pane)
          res[0].view.should == @view
          res[1].should be_a(Ruber::Pane)
          res[1].view.should == view
        end
        
        it 'hides the label' do
          view = @doc.create_view nil
          label = @pane.instance_variable_get(:@label)
          flexmock(label).should_receive(:hide).once
          @pane.split @view, view, Qt::Horizontal, @pos
        end
        
        it 'sets the label of the first pane to the text of the label and shows it' do
          view = @doc.create_view nil
          @pane.label = 'xyz'
          views = [@pane.view, view]
          panes = 2.times.map{|i| Ruber::Pane.new views[i], @pane.splitter}
          flexmock(Ruber::Pane).should_receive(:new).with(views[0], Qt::Splitter).once.and_return panes[0]
          flexmock(Ruber::Pane).should_receive(:new).with(views[1]).once.and_return panes[1]
          label = panes[0].instance_variable_get(:@label)
          flexmock(label).should_receive(:visible=).once.with(true)
          pane = @pane.split(@view, view, Qt::Horizontal, @pos)
          label.text.should == 'xyz'
        end
        
        it 'emits the split(QWidget*, QWidget*,QWidget*) signal passing self, the original and the new view as arguments' do
          view = @doc.create_view nil
          mk = flexmock{|m| m.should_receive(:pane_split).once.with(@pane, @view, view)}
          @pane.connect(SIGNAL('pane_split(QWidget*,QWidget*,QWidget*)')){|pn, v1,v2| mk.pane_split pn, v1, v2}
          @pane.split @view, view, Qt::Vertical, @pos
        end

      end
      
      context 'and the last argument is :after or missing' do
        before do
          @old_idx = 0
          @new_idx = 1
          @pos = :after
        end
        it_behaves_like '#split when the pane contains a single view'
      end
      
      context 'and the last argument is :after or missing' do
        before do
          @old_idx = 1
          @new_idx = 0
          @pos = :before
        end
        it_behaves_like '#split when the pane contains a single view'
      end
      
    end
    
    context 'if the pane already contains a splitter and it has the same orientation passed to the method' do
      
      before do
        @views = 2.times.map{@doc.create_view(nil)}
        @panes = @views.map{|v| Ruber::Pane.new v}
        @pane = Ruber::Pane.new Qt::Vertical, @panes[0], @panes[1]
      end
      
      shared_examples_for '#split when there\'s already a splitter with the same orientation' do
        
        it 'puts the view in a new pane and adds the given view to the splitter after the one specified as second argument' do
          view = @doc.create_view nil
          @pane.split @views[0], view, Qt::Vertical, @pos
          splitter = @pane.find_child(Qt::Splitter)
          splitter.count.should == 3
          pane = splitter.widget(@idx)
          pane.should be_a(Ruber::Pane)
          pane.find_child(Ruber::EditorView).should == view
        end
        
        it 'makes the new pane child of the splitter' do
          view = @doc.create_view nil
          @pane.split @views[0], view, Qt::Vertical, @pos
          splitter = @pane.find_child(Qt::Splitter)
          pane = splitter.widget(@idx)
          pane.parent.should == splitter
        end
        
        it 'returns an array with the pane containing the old view as first element and the pane containing the new view as second element' do
          view = @doc.create_view nil
          res = @pane.split @views[0], view, Qt::Horizontal, @pos
          res[0].should be_a(Ruber::Pane)
          res[0].view.should == @views[0]
          res[1].should be_a(Ruber::Pane)
          res[1].view.should == view
        end
        
        it 'emits the split(QWidget*, QWidget*,QWidget*) signal passing self, the original and the new view as arguments' do
          view = @doc.create_view nil
          mk = flexmock{|m| m.should_receive(:pane_split).once.with(@pane, @views[0], view)}
          @pane.connect(SIGNAL('pane_split(QWidget*,QWidget*,QWidget*)')){|pn, v1,v2| mk.pane_split pn, v1, v2}
          @pane.split @views[0], view, Qt::Vertical, @pos
        end

        
      end
      
      context 'and the last argument is :after or missing' do
        before do
          @idx = 1
          @pos = :after
        end
        it_behaves_like '#split when there\'s already a splitter with the same orientation'
      end
      
      context 'and the last argument is :before' do
        before do
          @idx = 0
          @pos = :before
        end
        it_behaves_like '#split when there\'s already a splitter with the same orientation'
      end
      
    end
    
    context 'if the pane already contains a splitter but it has a different orientation' do
      
      before do
        @views = 2.times.map{@doc.create_view(nil)}
        @panes = @views.map{|v| Ruber::Pane.new v}
        @pane = Ruber::Pane.new Qt::Horizontal, @panes[0], @panes[1]
      end
      
      shared_examples_for '#split when there\'s already a splitter but it has a different orientation' do
        
        it 'puts the two views in a new pane in the position of the existing view' do
          view = @doc.create_view nil
          old_splitter = @pane.find_child(Qt::Splitter)
          @pane.split @views[0], view, Qt::Vertical, @pos
          @pane.find_children(Ruber::Pane).select{|c| c.is_a? Ruber::Pane}.size.should == 4
          old_splitter.count.should == 2
          new_pane = old_splitter.widget 0
          new_pane.should be_a(Ruber::Pane)
          new_pane.should_not be_single_view
          inner_splitter = new_pane.find_child(Qt::Splitter)
          inner_splitter.orientation.should == Qt::Vertical
          inner_splitter.widget(@old_idx).view.should == @views[0]
          inner_splitter.widget(@new_idx).view.should == view
        end
        
        it 'returns an array with the pane containing the old view as first element and the pane containing the new view as second element' do
          view = @doc.create_view nil
          res = @pane.split @views[0], view, Qt::Horizontal, @pos
          res[0].should be_a(Ruber::Pane)
          res[0].view.should == @views[0]
          res[1].should be_a(Ruber::Pane)
          res[1].view.should == view
        end
        
        it 'emits the split(QWidget*, QWidget*,QWidget*) signal passing self, the original and the new view as arguments' do
          view = @doc.create_view nil
          mk = flexmock{|m| m.should_receive(:pane_split).once.with(@pane, @views[0], view)}
          @pane.connect(SIGNAL('pane_split(QWidget*,QWidget*,QWidget*)')){|pn, v1,v2| mk.pane_split pn, v1, v2}
          @pane.split @views[0], view, Qt::Vertical, @pos
        end

        
      end
      
      context 'and the last argument is :after or missing' do
        before do
          @old_idx = 0
          @new_idx = 1
          @pos = :after
        end
        it_behaves_like '#split when there\'s already a splitter but it has a different orientation'
      end
      
      context 'and the last argument is :before' do
        before do
          @old_idx = 1
          @new_idx = 0
          @pos = :before
        end
        it_behaves_like '#split when there\'s already a splitter but it has a different orientation'
      end
      
    end
    
    context 'if the given view is not directly contained in the pane' do
      
      it 'does nothing and returns nil if the view isn\'t contained in any of the children panes' do
        doc = Ruber::Document.new
        views = 5.times.map{doc.create_view}
        pane = Ruber::Pane.new(views[0])
        pane.split views[0], views[1], Qt::Horizontal, :after
        panes = pane.split views[0], views[2], Qt::Vertical, :after
        pane.split(views[3], views[4], Qt::Horizontal, :after).should be_nil
        pane.find_children(Ruber::EditorView).find{|v| v == views[4]}.should be_nil
      end
      
      it 'calls the same method of the pane containing the view' do
        doc = Ruber::Document.new
        views = 4.times.map{doc.create_view}
        pane = Ruber::Pane.new(views[0])
        pane.split views[0], views[1], Qt::Horizontal, :after
        panes = pane.split views[0], views[2], Qt::Vertical, :after
        flexmock(panes[1].parent.parent).should_receive(:split).with(views[2], views[3], Qt::Vertical, :after).once
        pane.split views[2], views[3], Qt::Vertical, :after
      end
      
      it 'emits the split(QWidget*, QWidget*,QWidget*) signal passing the pane where the view was contained, the original and the new view as arguments' do
        doc = Ruber::Document.new
        views = 4.times.map{doc.create_view}
        pane = Ruber::Pane.new(views[0])
        pane.split views[0], views[1], Qt::Horizontal, :after
        panes = pane.split views[0], views[2], Qt::Vertical, :after
        mk = flexmock{|m| m.should_receive(:pane_split).once.with(panes[1].parent.parent, views[2], views[3])}
        pane.connect(SIGNAL('pane_split(QWidget*,QWidget*,QWidget*)')){|pn, v1,v2| mk.pane_split pn, v1, v2}
        pane.split views[2], views[3], Qt::Vertical, :after
      end
      
    end
    
  end
  
  context 'when a view contained in it emits the closing signal' do
    
    context 'if the pane is in single view mode' do
      
      it 'calls the remove_view method' do
        doc = Ruber::Document.new
        view = doc.create_view nil
        pane = Ruber::Pane.new view
        flexmock(pane).should_receive(:remove_view).once.with(view)
        view.instance_eval{emit closing self}
      end
      
      it 'emits the removing_view(QWidget*,QWidget*) signal passing self and the view as arguments' do
        doc = Ruber::Document.new
        view = doc.create_view nil
        pane = Ruber::Pane.new view
        mk = flexmock{|m| m.should_receive(:removing_view).with(pane, view).once}
        pane.connect(SIGNAL('removing_view(QWidget*,QWidget*)')){|pn, v| mk.removing_view pn, v}
        view.instance_eval{emit closing self}
      end

    end
    
    context 'if the pane is in multiple view mode' do
      
      it 'does not attempt to remove the view' do
        doc = Ruber::Document.new
        views = 3.times.map{doc.create_view nil}
        pane = Ruber::Pane.new views[0]
        1.upto(2){|i| pane.split views[i-1], views[i], Qt::Vertical}
        flexmock(pane).should_receive(:remove_view).never
        views[0].instance_eval{emit closing self}
      end
      
      it 'emits the removing_view(QWidget*,QWidget*) signal passing the pane containing the view and the view itself as arguments' do
        doc = Ruber::Document.new
        views = 3.times.map{doc.create_view nil}
        pane = Ruber::Pane.new views[0]
        1.upto(2){|i| pane.split views[i-1], views[i], Qt::Vertical}
        mk = flexmock{|m| m.should_receive(:removing_view).with(views[0].parent, views[0]).once}
        pane.connect(SIGNAL('removing_view(QWidget*,QWidget*)')){|pn, v| mk.removing_view pn, v}
        views[0].instance_eval{emit closing self}
      end

    end
    
  end
  
  describe '#remove_view' do
    
    before do
      @doc = Ruber::Document.new
      @view = @doc.create_view nil
      @pane = Ruber::Pane.new @view
      flexmock(@pane).should_receive(:delete_later).by_default
    end
    
    it 'emits the closing_last_view signal passing self as argument' do
      mk = flexmock{|m| m.should_receive(:closing_last_view).once.with(@pane)}
      @pane.connect(SIGNAL('closing_last_view(QWidget*)')){|w| mk.closing_last_view w}
      @pane.send :remove_view, @view
    end
    
    it 'sets the view\'s parent to nil' do
      @pane.send :remove_view, @view
      @view.parent.should be_nil
    end
    
    it 'deletes the pane' do
      flexmock(@pane).should_receive(:delete_later).once
      @pane.send :remove_view, @view
    end
    
  end
  
  context 'when a child pane emits the closing_last_view signal' do
    
    before do
      @doc = Ruber::Document.new
      @views = 3.times.map{@doc.create_view}
    end
    
    it 'does nothing  if the pane isn\'t directly contained in the pane' do
      @pane = Ruber::Pane.new Qt::Vertical, Ruber::Pane.new(@views[0]), Ruber::Pane.new(@views[1])
      child_pane = @pane.split( @views[1], @views[2], Qt::Horizontal)[1]
      flexmock(@pane).should_receive(:remove_pane).never
      child_pane.instance_eval{emit closing_last_view(self)}
    end
    
    context 'when only one pane remains' do
      
      context 'and that pane contains a single view' do
        
        before do
          @pane = Ruber::Pane.new @views[0]
          @panes = @pane.split @views[0], @views[1], Qt::Vertical
        end
      
        it 'switches to single view mode containing the view of the remaining pane if the latter is in single view mode' do
          @panes[0].instance_eval{emit closing_last_view(self)}
          @pane.should be_single_view
          @pane.view.should == @views[1]
        end
        
        it 'uses the label of the remaining pane as its own label' do
          @panes[1].label = 'xyz'
          @panes[0].instance_eval{emit closing_last_view(self)}
          @pane.label.should == 'xyz'
        end
        
        it 'displays the label unless  the pane is s top level' do
          view = @doc.create_view
          panes = @panes[0].split @views[0], view, Qt::Vertical
          panes[1].label = 'xyz'
          label = @panes[0].instance_variable_get(:@label)
          flexmock(label).should_receive(:visible=).with(true).once
          panes[0].instance_eval{emit closing_last_view(self)}
        end
        
        it 'hides the label if it\'s a top level pane' do
          label = @pane.instance_variable_get(:@label)
          flexmock(label).should_receive(:visible=).with(false).once
          @panes[1].label = 'xyz'
          @panes[0].instance_eval{emit closing_last_view(self)}
        end
        
        it 'hides the label if the text is empty' do
          view = @doc.create_view
          panes = @panes[0].split @views[0], view, Qt::Vertical
          panes[1].label = ''
          label = @panes[0].instance_variable_get(:@label)
          flexmock(label).should_receive(:visible=).with(false).once
          panes[0].instance_eval{emit closing_last_view(self)}
        end
        
        it 'calls the delete_later method of the remaining pane' do
          flexmock(@panes[1]).should_receive(:delete_later).once
          @panes[0].instance_eval{emit closing_last_view(self)}
        end
        
      end
      
      context 'and that pane contains more than one view' do
        
        before do
          @views << @doc.create_view << @doc.create_view
          @pane = Ruber::Pane.new @views[0]
          @closing_pane, @remaining_pane = @pane.split @views[0], @views[1], Qt::Vertical
          @remaining_pane.split @views[1], @views[2], Qt::Horizontal
          @remaining_pane.split @views[2], @views[3], Qt::Horizontal
        end
        
        it 'removes the remaining pane from the splitter' do
          @closing_pane.instance_eval{emit closing_last_view self}
          @pane.splitter.children.select{|c| c.is_a?(Ruber::Pane)}.should_not include(@remaining_pane)
        end
        
        it 'makes all the children panes its own children' do
          @closing_pane.instance_eval{emit closing_last_view self}
          @pane.should_not be_single_view
          @pane.splitter.count.should == 3
          @pane.splitter.widget(0).view.should == @views[1]
          @pane.splitter.widget(1).view.should == @views[2]
          @pane.splitter.widget(2).view.should == @views[3]
        end
        
        it 'calls the delete_later method of the remaining pane' do
          flexmock(@remaining_pane).should_receive(:delete_later).once
          @closing_pane.instance_eval{emit closing_last_view(self)}
        end
        
      end
      
    end
    
    context 'when more than one pane remains' do
      
      it 'removes the pane from the splitter' do
        @pane = Ruber::Pane.new @views[0]
        @pane.split @views[0], @views[1], Qt::Vertical
        pane_to_delete = @pane.split( @views[1], @views[2], Qt::Vertical)[1]
        pane_to_delete.instance_eval{emit closing_last_view(self)}
        pane_to_delete.parent.should be_nil
      end
      
      it 'doesn\'t alter anything else' do
        @pane = Ruber::Pane.new @views[0]
        @pane.split @views[0], @views[1], Qt::Vertical
        panes = @pane.split @views[1], @views[2], Qt::Vertical
        panes[0].instance_eval{emit closing_last_view self}
        @pane.splitter.count.should == 2
        @pane.splitter.widget(0).view.should == @views[0]
        @pane.splitter.widget(1).view.should == @views[2]
      end
    
    end
    
  end
  
  describe '#each_pane' do
    
    before do
      @doc = Ruber::Document.new
      @views = 4.times.map{@doc.create_view}
      @pane = Ruber::Pane.new @views[0]
    end
    
    context 'when called with no argument' do
      
      it 'iterates on all panes which are direct child of the pane' do
        panes = []
        panes += @pane.split @views[0], @views[1], Qt::Vertical
        panes += @pane.split @views[1], @views[2], Qt::Vertical
        @pane.split @views[1], @views[3], Qt::Horizontal
        panes.uniq!
        res = []
        @pane.each_pane{|i| res << i}
        res.should == panes
      end
      
      it 'does nothing if the pane is in single view mode' do
        res = []
        @pane.each_pane{|w| res << w}
        res.should be_empty
      end
      
      it 'returns self if called with a block' do
        @pane.each_pane{|w| w}.should == @pane
        @pane.split @views[0], @views[1], Qt::Vertical
        @pane.each_pane{|w| w}.should == @pane
      end
      
      it 'returns an enumerable if called without a block' do
        panes = @pane.split @views[0], @views[1], Qt::Vertical
        res = []
        en = @pane.each_pane
        en.should be_an(Enumerator)
        en.each{|w| res << w}
        res.should == panes
      end
      
    end
    
    context 'when called with the :recursive argument' do
      
      it 'iterates on all panes, recursively' do
        panes = []
        panes += @pane.split @views[0], @views[1], Qt::Vertical
        panes += @pane.split @views[1], @views[2], Qt::Vertical
        panes.uniq!
        temp = @pane.split @views[1], @views[3], Qt::Horizontal
        panes.insert 2, temp[0]
        panes.insert 3, temp[1]
        panes.uniq!
        res = []
        @pane.each_pane(:recursive){|i| res << i}
        res.should == panes
      end
      
      it 'does nothing if the pane is in single view mode' do
        res = []
        @pane.each_pane(:recursive){|w| res << w}
        res.should be_empty
      end
      
      it 'returns self if called with a block' do
        @pane.each_pane(:recursive){|w| w}.should == @pane
        @pane.split @views[0], @views[1], Qt::Vertical
        @pane.each_pane(:recursive){|w| w}.should == @pane
      end

      it 'returns an enumerator which iterates on all child panes recursively if called without a block' do
        panes = []
        panes += @pane.split @views[0], @views[1], Qt::Vertical
        panes += @pane.split @views[1], @views[2], Qt::Vertical
        panes.uniq!
        temp = @pane.split @views[1], @views[3], Qt::Horizontal
        panes.insert 2, temp[0]
        panes.insert 3, temp[1]
        panes.uniq!
        res = []
        en = @pane.each_pane(:recursive)
        en.should be_an(Enumerator)
        en.each{|i| res << i}
        res.should == panes
      end
      
    end
    
  end
  
  describe '#each_view' do
    
    before do
      @doc = Ruber::Document.new
      @views = 4.times.map{@doc.create_view}
      @pane = Ruber::Pane.new @views[0]
    end
    
    it 'calls iterates over all views contained in the pane' do
      @pane.split @views[0], @views[1], Qt::Vertical
      @pane.split @views[1], @views[2], Qt::Vertical
      @pane.split @views[1], @views[3], Qt::Horizontal
      res = []
      @pane.each_view{|v| res << v}
      res.should == [@views[0], @views[1], @views[3], @views[2]]
    end
    
    it 'yields the single view contained in the pane if the pane is in single view mode' do
      res = []
      @pane.each_view{|v| res << v}
      res.should == [@views[0]]
    end
    
    it 'returns self' do
      @pane.each_view{}.should == @pane
      @pane.split @views[0], @views[1], Qt::Vertical
      @pane.split @views[1], @views[2], Qt::Vertical
      @pane.split @views[1], @views[3], Qt::Horizontal
      @pane.each_view{}.should == @pane
    end
    
    it 'returns an enumerator which iterates on all views if no block is given' do
      en = @pane.each_view
      en.should be_an(Enumerator)
      res_single = []
      en.each{|v| res_single << v}
      @pane.split @views[0], @views[1], Qt::Vertical
      @pane.split @views[1], @views[2], Qt::Vertical
      @pane.split @views[1], @views[3], Qt::Horizontal
      en = @pane.each_view
      en.should be_an(Enumerator)
      res_multi = []
      en.each{|v| res_multi << v}
      res_single.should == [@views[0]]
      res_multi.should == [@views[0], @views[1], @views[3], @views[2]]
    end
    
  end
  
  describe '#parent_pane' do
    
    before do
      @doc = Ruber::Document.new
      @views = 4.times.map{@doc.create_view}
      @pane = Ruber::Pane.new @views[0]
    end
    
    it 'returns nil if the pane is a toplevel widget' do
      @pane.parent_pane.should be_nil
    end
    
    it 'returns nil if the pane\'s parent is not a Qt::Splitter' do
      w = Qt::Widget.new
      @pane.parent = w
      @pane.parent_pane.should be_nil
    end
    
    it 'returns nil if the pane\'s gandparent is not a Pane' do
      w = Qt::Widget.new
      s = Qt::Splitter.new w
      s.add_widget @pane
      @pane.parent_pane.should be_nil
    end
    
    it 'returns the pane\'s grandparent if it\'s a Pane' do
      panes = @pane.split @views[0], @views[1], Qt::Horizontal
      panes[0].parent_pane.should == @pane
    end
    
  end
  
  describe '#contains?' do
    
    before do
      @doc = Ruber::Document.new
      @views = 4.times.map{@doc.create_view}
      @pane = Ruber::Pane.new @views[0]
    end
    
    context 'when called with one argument' do
      
      context 'and the argument is a pane' do
        
        it 'returns true if this pane contains, directly or not, the one given as argument' do
          panes = @pane.split @views[0], @views[1], Qt::Vertical
          @pane.contain?(panes[0]).should be_true
          panes = @pane.split @views[1], @views[2], Qt::Horizontal
          @pane.contain?(panes[1]).should be_true
        end
        
        it 'returns false if this pane doesn\'t contain the one given as argument' do
          pane = Ruber::Pane.new @views[2]
          @pane.contain?(pane).should be_false
        end
        
      end
      
      context 'and the argument is a view' do
        
        it 'returns true if the pane contains, directly or not, the view' do
          @pane.contain?(@views[0]).should be_true
          @pane.split @views[0], @views[1], Qt::Vertical
          @pane.split @views[1], @views[2], Qt::Horizontal
          @pane.contain?(@views[2]).should be_true
        end
        
        it 'returns vale if this pane doesn\'t contain the view' do
          @pane.contain?(@views[2]).should be_false
        end
        
      end
      
    end
    
    context 'when called with two arguments' do
      
      context 'and the first argument is a pane' do
        
        it 'returns true if this pane directly contains the one given as argument' do
          panes = @pane.split @views[0], @views[1], Qt::Vertical
          @pane.contain?(panes[0], :directly).should be_true
        end
        
        it 'returns false if this pane doesn\'t contain the one given as argument' do
          pane = Ruber::Pane.new @views[2]
          @pane.contain?(pane, :directly).should be_false
        end
        
        it 'returns false if this pane contains the one given as argument indirectly' do
          panes = @pane.split @views[0], @views[1], Qt::Vertical
          panes = @pane.split @views[1], @views[2], Qt::Horizontal
          @pane.contain?(panes[1], :directly).should be_false
        end
        
      end
      
    end
    
    context 'and the second argument is a view' do
      
      it 'returns true if this pane directly contains the view' do
        @pane.contain?(@views[0], :directly).should be_true
      end
      
      it 'returns false if this pane doesn\'t contain the view' do
        @pane.contain?(@views[1], :directly).should be_false
      end
      
      it 'returns false if this pane contains the one given as argument indirectly' do
        panes = @pane.split @views[0], @views[1], Qt::Vertical
        panes = @pane.split @views[1], @views[2], Qt::Horizontal
        @pane.contain?(@views[2], :directly).should be_false
      end
        
    end
    
  end
  
  describe '#set_view_label' do
    
    context 'when the pane is in single view mode' do
      
      it 'displays a label containing the given text if the contained view matches the first argument' do
        view1 = @doc.create_view
        view2 = @doc.create_view
        outer_pane = Ruber::Pane.new view1
        pane = outer_pane.split(view1, view2, Qt::Horizontal)[0]
        text = 'xyz'
        flexmock(pane.instance_variable_get(:@label)).should_receive(:visible=).once.with true
        pane.set_view_label view1, text
        label = pane.layout.item_at(1).widget
        label.should be_a(Qt::Label)
        label.text.should == text
      end
      
      it 'hides the label if the text is empty and the view matches the first argument' do
        view1 = @doc.create_view
        view2 = @doc.create_view
        outer_pane = Ruber::Pane.new view1
        pane = outer_pane.split(view1, view2, Qt::Horizontal)[0]
        label = pane.instance_variable_get(:@label)
        label.text = 'xyz'
        flexmock(pane.instance_variable_get(:@label)).should_receive(:visible=).once.with false
        pane.set_view_label view1, ''
        label.text.should == ''
      end
      
      it 'does nothing if the view argument isn\'t the same view contained in the pane' do
        view1 = @doc.create_view
        view2 = @doc.create_view
        view3 = @doc.create_view
        outer_pane = Ruber::Pane.new view1
        pane = outer_pane.split(view1, view2, Qt::Horizontal)[0]
        label = pane.instance_variable_get(:@label)
        orig_text = 'abc'
        label.text = orig_text
        flexmock(label).should_receive(:visible=).never
        text = 'xyz'
        pane.set_view_label view3, text
        label.text.should == orig_text
      end
      
      it 'changes the label text but doesn\'t display the label if the pane is a top-level pane' do
        view = @doc.create_view
        parent = Qt::Widget.new
        pane = Ruber::Pane.new view, parent
        pane.set_view_label view, 'text'
        label = pane.instance_variable_get(:@label)
        flexmock(label).should_receive(:visible=).never
        text = 'xyz'
        pane.set_view_label view, text
        label.text.should == text
      end
      
      it 'returns true if the view argument is the same view contained in the pane' do
        view1 = @doc.create_view
        view2 = @doc.create_view
        outer_pane = Ruber::Pane.new view1
        pane = outer_pane.split(view1, view2, Qt::Horizontal)[0]
        text = 'xyz'
        pane.set_view_label( view1, text).should be_true
        pane = Ruber::Pane.new view1
        pane.set_view_label(view1, text).should be_true
      end
      
      it 'returns false if the view argument is different from the view contained in the pane' do
        view1 = @doc.create_view
        view2 = @doc.create_view
        outer_pane = Ruber::Pane.new view1
        pane = outer_pane.split(view1, view2, Qt::Horizontal)[0]
        text = 'xyz'
        pane.set_view_label( view2, text).should be_false
        pane = Ruber::Pane.new view1
        pane.set_view_label(view2, text).should be_false
      end
      
    end
    
    context 'when the pane is in multiple view mode' do
      
      it 'calls the same method on all child panes until one of them returns true' do
        views = 3.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        text = 'xyz'
        flexmock(panes[0]).should_receive(:set_view_label).with(views[1], text).once.and_return false
        flexmock(panes[1]).should_receive(:set_view_label).with(views[1], text).once.and_return true
        flexmock(panes[2]).should_receive(:set_view_label).never
        outer_pane.set_view_label views[1], text
      end
      
      it 'returns true if one of the child panels\' set_view_label methods returns true' do
        views = 3.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        text = 'xyz'
        flexmock(panes[0]).should_receive(:set_view_label).with(views[1], text).once.and_return false
        flexmock(panes[1]).should_receive(:set_view_label).with(views[1], text).once.and_return true
        flexmock(panes[2]).should_receive(:set_view_label).never
        outer_pane.set_view_label(views[1], text).should be_true
      end
      
      it 'returns false if all the child panels\'s set_view_label methods return false' do
        views = 4.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        text = 'xyz'
        flexmock(panes[0]).should_receive(:set_view_label).with(views[3], text).once.and_return false
        flexmock(panes[1]).should_receive(:set_view_label).with(views[3], text).once.and_return false
        flexmock(panes[2]).should_receive(:set_view_label).with(views[3], text).once.and_return false
        outer_pane.set_view_label(views[3], text).should be_false
      end
      
    end
    
  end
  
  describe '#label=' do
    
    context 'when the pane is in single view mode' do
      
      it 'sets the label to the given value' do
        view = @doc.create_view
        pane = Ruber::Pane.new view
        text = 'xyz'
        pane.label = text
        pane.instance_variable_get(:@label).text.should == text
      end
      
      it 'shows the label if the text is not empty and the pane is not top level' do
        views = 2.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        pane = outer_pane.split( views[0], views[1], Qt::Vertical)[0]
        text = 'xyz'
        label = pane.instance_variable_get(:@label)
        flexmock(label).should_receive(:visible=).with(true).once
        pane.label = text
        label.text.should == text
      end
      
      it 'doesn\'t show the label if the pane is top-level' do
        view = @doc.create_view
        pane = Ruber::Pane.new view
        text = 'xyz'
        label = pane.instance_variable_get(:@label)
        flexmock(label).should_receive(:visible=).never
        pane.label = text
      end
      
      it 'hides the label if the text is empty' do
        views = 2.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        pane = outer_pane.split( views[0], views[1], Qt::Vertical)[0]
        label = pane.instance_variable_get(:@label)
        label.text = 'xyz'
        flexmock(label).should_receive(:visible=).with(false).once
        pane.label = ''
        label.text.should == ''
      end
      
    end
    
    context 'when the pane is in multiple view mode' do
      
      it 'does nothing' do
        views = 2.times.map{@doc.create_view}
        pane = Ruber::Pane.new views[0]
        pane.split( views[0], views[1], Qt::Vertical)[0]
        text = 'xyz'
        label = pane.instance_variable_get(:@label)
        flexmock(label).should_receive(:visible=).never
        flexmock(label).should_receive(:text=).never
        pane.label = text
      end
      
    end
    
  end
  
  describe '#label' do
    
    it 'returns the text of the label if the pane is in single view mode' do
      view = @doc.create_view
      pane = Ruber::Pane.new view
      pane.label = 'xyz'
      pane.label.should == 'xyz'
    end
    
    it 'returns an empty string if the label hasn\'t been set' do
      view = @doc.create_view
      pane = Ruber::Pane.new view
      pane.label.should == ''
    end
    
    it 'returns an empty string if the label has been set to an empty string' do
      view = @doc.create_view
      pane = Ruber::Pane.new view
      pane.label = ''
      pane.label.should == ''
    end
    
    it 'returns nil if the pane is in multiple view mode' do
      views = 2.times.map{@doc.create_view}
      pane = Ruber::Pane.new views[0]
      pane.label = 'xyz'
      pane.split( views[0], views[1], Qt::Vertical)[0]
      pane.label.should be_nil
    end
    
  end
  
  describe '#replace_view' do
    
    context 'if the pane is in single view mode' do
      
      context 'and the view in the pane is the one given as first argument' do
      
        it 'replaces the view contained in the pane with the one given as second argument' do
          views = 2.times.map{@doc.create_view}
          pane = Ruber::Pane.new views[0]
          pane.replace_view views[0], views[1]
          pane.view.should == views[1]
          pane.view.parent.should == pane
          pane.layout.should include(views[1])
        end
        
        it 'makes the old view parentless and removes it from the layout' do
          views = 2.times.map{@doc.create_view}
          pane = Ruber::Pane.new views[0]
          pane.replace_view views[0], views[1]
          views[0].parent.should be_nil
          pane.layout.should_not include(views[0])
        end
        
        it 'returns true' do
          views = 2.times.map{@doc.create_view}
          pane = Ruber::Pane.new views[0]
          pane.replace_view(views[0], views[1]).should be_true
        end
        
        it 'emits the view_replaced(QWidget*,QWidget*,QWidget*) signal passing self, the original view and the replacement view as arguments' do
          views = 2.times.map{@doc.create_view}
          pane = Ruber::Pane.new views[0]
          mk = flexmock{|m| m.should_receive(:view_replaced).with(pane, views[0], views[1]).once}
          pane.connect(SIGNAL('view_replaced(QWidget*,QWidget*,QWidget*)')){|pn, v1, v2| mk.view_replaced pn, v1, v2}
          pane.replace_view(views[0], views[1])
        end
      
      end
      
      context 'and the view in the pane is not the one given as first argument' do
        
        it 'does nothing' do
          views = 3.times.map{@doc.create_view}
          pane = Ruber::Pane.new views[0]
          pane.replace_view views[2], views[1]
          pane.view.should == views[0]
          views[0].parent.should == pane
          views[1].parent.should be_nil
          pane.layout.should include(views[0])
          pane.layout.should_not include(views[1])
        end
        
        it 'returns false' do
          views = 3.times.map{@doc.create_view}
          pane = Ruber::Pane.new views[0]
          pane.replace_view(views[2], views[1]).should be_false
        end
        
      end
      
    end
    
    context 'if the pane is in multiple view mode' do
      
      it 'calls the same method on all child panes until one of them returns true' do
        views = 4.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        flexmock(panes[0]).should_receive(:replace_view).with(views[1], views[3]).once.and_return false
        flexmock(panes[1]).should_receive(:replace_view).with(views[1], views[3]).once.and_return true
        flexmock(panes[2]).should_receive(:replace_view).never
        outer_pane.replace_view views[1], views[3]
      end
      
      it 'returns true if one of the child panes\' replace_view methods returns true' do
        views = 4.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        flexmock(panes[0]).should_receive(:replace_view).with(views[1], views[3]).once.and_return false
        flexmock(panes[1]).should_receive(:replace_view).with(views[1], views[3]).once.and_return true
        flexmock(panes[2]).should_receive(:replace_view).never
        outer_pane.replace_view(views[1], views[3]).should be_true
      end
      
      it 'emits the view_replaced(QWidget*,QWidget*,QWidget*) signal passing the pane containing the view, the original view and the replacement view as arguments if one of the child panes\' replace_view methods returns true' do
        views = 4.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        mk = flexmock{|m| m.should_receive(:view_replaced).with(views[1].parent, views[1], views[3]).once}
        outer_pane.connect(SIGNAL('view_replaced(QWidget*,QWidget*,QWidget*)')){|pn, v1, v2| mk.view_replaced pn, v1, v2}
        outer_pane.replace_view(views[1], views[3])
      end      
      
      it 'returns true if all of the child panes\' replace_view methods return false' do
        views = 5.times.map{@doc.create_view}
        outer_pane = Ruber::Pane.new views[0]
        panes = outer_pane.split(views[0], views[1], Qt::Horizontal)
        panes << outer_pane.split(views[1], views[2], Qt::Horizontal)[1]
        flexmock(panes[0]).should_receive(:replace_view).with(views[4], views[3]).once.and_return false
        flexmock(panes[1]).should_receive(:replace_view).with(views[4], views[3]).once.and_return false
        flexmock(panes[2]).should_receive(:replace_view).with(views[4], views[3]).once.and_return false
        outer_pane.replace_view(views[4], views[3]).should be_false
      end

    end
    
  end
  
  context "when the pane is hidden" do
    
    before do
      @app = KDE::Application.instance
      @pane = Ruber::Pane.new @doc.create_view
    end
    
    context 'and the hide event originates from the application' do
    
      it 'emits the about_to_hide signal passing self as argument' do
        e = Qt::HideEvent.new
        flexmock(e).should_receive(:spontaneous).and_return false
        @app.post_event @pane, e
        mk = flexmock{|m| m.should_receive(:pane_about_to_hide).once.with @pane}
        @pane.connect(SIGNAL('about_to_hide(QWidget*)')) do |w|
          mk.pane_about_to_hide w
        end
        @app.process_events
      end

    end
    
    context 'and the hide event originates outside the application' do
      
      it 'does not emit the about_to_hide signal' do
        e = Qt::HideEvent.new
        flexmock(e).should_receive(:spontaneous).and_return true
        @app.post_event @pane, e
        mk = flexmock{|m| m.should_receive(:pane_about_to_hide).never}
        @pane.connect(SIGNAL('about_to_hide(QWidget*)')) do |w|
          mk.pane_about_to_hide w
        end
        @app.process_events
      end
      
    end
    
  end
    
  context "when the pane becomes visible" do
    
    before do
      @app = KDE::Application.instance
      @pane = Ruber::Pane.new @doc.create_view
    end
    
    context 'and the show event originates from the application' do
      
      it 'emits the about_to_show signal passing self as argument' do
        e = Qt::ShowEvent.new
        flexmock(e).should_receive(:spontaneous).and_return false
        @app.post_event @pane, e
        mk = flexmock{|m| m.should_receive(:pane_about_to_show).once.with @pane}
        @pane.connect(SIGNAL('about_to_show(QWidget*)')) do |w|
          mk.pane_about_to_show w
        end
        @app.process_events
      end
      
    end
    
    context 'and the show event originates outside the application' do
      
      it 'does not emit the about_to_show signal' do
        e = Qt::ShowEvent.new
        flexmock(e).should_receive(:spontaneous).and_return true
        @app.post_event @pane, e
        mk = flexmock{|m| m.should_receive(:pane_about_to_show).never}
        @pane.connect(SIGNAL('about_to_show(QWidget*)')) do |w|
          mk.pane_about_to_show w
        end
        @app.process_events
      end
      
    end
          
  end
  
end