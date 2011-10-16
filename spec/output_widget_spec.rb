require './spec/common'
require 'ruber/output_widget'

describe Ruber::OutputWidget::ActionList do
  
  before do
    @list = Ruber::OutputWidget::ActionList.new
    @list << 'a' << 'b' << nil << 'c' << nil << 'd' << 'e' << nil << 'f' << 'g'
  end

  describe '#insert_after' do

    describe ', when the first argument is an integer' do
      
      it 'inserts the entries, in order, after a number of nil entries given by the first argument' do
        @list.insert_after 2, 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'x', 'y', 'd', 'e', nil, 'f', 'g']
      end
      
      it 'inserts the entries in order at the end of the list if the list contains less separators than requested' do
        @list.insert_after 10, 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'd', 'e', nil, 'f', 'g', 'x', 'y']
      end
      
    end
    
    describe 'when the first argument is a string' do
      
      it 'inserts the entries, in order, after the first entry equal to the first argument' do
        @list.insert_after 'd', 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'd', 'x', 'y', 'e', nil, 'f', 'g']
      end
      
      it 'inserts the entries in order at the end of the list if the list doesn\'t contain the first argument' do
        @list.insert_after 'z', 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'd', 'e', nil, 'f', 'g', 'x', 'y']
      end
      
    end
    
  end
  
  describe '#insert_before' do
    
    describe ', when the first argument is an integer' do
      
      it 'inserts the entries, in order, before the nth nil entry, where n is the first argument' do
        @list.insert_before 2, 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', 'x', 'y', nil, 'd', 'e', nil, 'f', 'g']
      end
      
      it 'inserts the entries in order at the end of the list if the list contains less separators than requested' do
        @list.insert_before 10, 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'd', 'e', nil, 'f', 'g', 'x', 'y']
      end
      
    end
    
    describe 'when the first argument is a string' do
      
      it 'inserts the entries, in order, before the first entry equal to the first argument' do
        @list.insert_before 'd', 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'x', 'y', 'd', 'e', nil, 'f', 'g']
      end
      
      it 'inserts the entries in order at the end of the list if the list doesn\'t contain the first argument' do
        @list.insert_before 'z', 'x', 'y'
        @list.should == ['a', 'b', nil, 'c', nil, 'd', 'e', nil, 'f', 'g', 'x', 'y']
      end
      
    end
    
  end
  
end

describe Ruber::OutputWidget do
  
  it 'inherits from Qt::Widget' do
    Ruber::OutputWidget.ancestors.should include(Qt::Widget)
  end
  
  it 'includes the GuiStatesHandler modules' do
    Ruber::OutputWidget.ancestors.should include(Ruber::GuiStatesHandler)
  end
  
  describe ', when created' do
    
    it 'can take up to two arguments' do
      lambda{Ruber::OutputWidget.new}.should_not raise_error
      lambda{Ruber::OutputWidget.new Qt::Widget.new}.should_not raise_error
      lambda{Ruber::OutputWidget.new Qt::Widget.new, :view => :list}.should_not raise_error
    end
    
    it 'has a grid layout' do
      Ruber::OutputWidget.new.layout.should be_a(Qt::GridLayout)
    end

    it 'uses the object passed in the model option as model, if given' do
      mod = Qt::StringListModel.new
      ow = Ruber::OutputWidget.new(nil, :model => mod)
      ow.model.should equal(mod)
    end
    
    it 'creates a model which is an instance of Ruber::OutputWidget::Model if the model option isn\'t given' do
      ow = Ruber::OutputWidget.new
      ow.model.should be_a(Ruber::OutputWidget::Model)
    end
    
    it 'makes sure the model contains at least one column' do
      ow = Ruber::OutputWidget.new
      ow.model.should be_a(Ruber::OutputWidget::Model)
      ow.model.column_count.should >= 1
      mod = Qt::StringListModel.new
      ow = Ruber::OutputWidget.new nil, :model => mod
      ow.model.column_count.should >= 1
      mod = Qt::StringListModel.new
      mod.insert_columns(0,5)
      ow = Ruber::OutputWidget.new nil, :model => mod
      ow.model.column_count.should >= 1
    end
    
    it 'uses the content of the view option as view, if it\'s a Qt::Widget' do
      v = Qt::TreeView.new
      ow = Ruber::OutputWidget.new nil, :view => v
      ow.view.should be_the_same_as(v)
    end
    
    it 'takes ownership of the view, if the view option is a Qt::Widget' do
      v = Qt::TreeView.new
      ow = Ruber::OutputWidget.new nil, :view => v
      ow.view.parent.should be_the_same_as(ow)
    end
    
    it 'creates a new instance of class Ruber::OutputWidget::ListView and uses it as view if the view option is :list or is missing' do
      w = Ruber::OutputWidget.new Qt::Widget.new, :view => :list
      w.view.should be_a(Ruber::OutputWidget::ListView)
      w.view.parent.should equal(w)
      w = Ruber::OutputWidget.new
      w.view.should be_a(Ruber::OutputWidget::ListView)
    end
    
    it 'creates a new instance of class Ruber::OutputWidget::ListView and uses it as view if the view option is :tree' do
      w = Ruber::OutputWidget.new Qt::Widget.new, :view => :tree
      w.view.should be_a(Ruber::OutputWidget::TreeView)
      w.view.parent.should equal(w)
    end
    
    it 'creates an instance of class OutputWidget::TableView with parent self and stores it in the @view instance variable if the second argument is :table' do
      w = Ruber::OutputWidget.new Qt::Widget.new, :view => :table
      w.view.should be_a(Ruber::OutputWidget::TableView)
      w.view.parent.should equal(w)
    end
    
    it 'inserts the view in the layout at position (1,0)' do
      w = Ruber::OutputWidget.new
      w.layout.item_at_position(1,0).widget.should be_a(Ruber::OutputWidget::ListView)
    end
    
    it 'has a checkable Qt::ToolButton in the first line, aligned to the right' do
      w = Ruber::OutputWidget.new
      it = w.layout.item_at_position(0,0)
      it.widget.should be_a(Qt::ToolButton)
      it.alignment.should == Qt::AlignRight | Qt::AlignVCenter
      it.widget.should be_checkable
    end
    
    it 'sets the selection mode to Extended' do
      w = Ruber::OutputWidget.new
      w.view.selection_mode.should == Qt::AbstractItemView::ExtendedSelection
    end
    
    it 'makes the view use the widget\'s model' do
      w = Ruber::OutputWidget.new
      w.view.model.should be_the_same_as(w.model)
    end
    
    it 'makes the model child of the view' do
      mod = Qt::StandardItemModel.new
      view = Qt::ListView.new
      ow = Ruber::OutputWidget.new nil, :model => mod, :view => view
      ow.model.parent.should be_the_same_as(view)
    end
    
    it 'connects the view\'s selection model\'s selectionChanged signal with its own selection_changed slot' do
      ow = Ruber::OutputWidget.new
      flexmock(ow).should_receive(:selection_changed).once.with(Qt::ItemSelection, Qt::ItemSelection)
      ow.view.selection_model.instance_eval{emit selectionChanged(Qt::ItemSelection.new, Qt::ItemSelection.new)}
    end
    
    it 'connects the view\'s "activated(QModelIndex)" signal with its "maybe_open_file(QModelIndex)" slot' do
      ow = Ruber::OutputWidget.new
      ow.model.append_row Qt::StandardItem.new('x')
      flexmock(ow).should_receive(:maybe_open_file).once.with(ow.model.index(0,0))
      ow.view.instance_eval{emit activated(ow.model.index(0,0))}
    end
    
    it 'connects the model\'s rowsInserted signal with its own rows_changed slot' do
      ow = Ruber::OutputWidget.new
      flexmock(ow).should_receive(:rows_changed).once
      ow.model.insertRows(0, 4)
    end
    
    it 'connects the model\'s rowsRemoved signal with its own rows_changed slot' do
      ow = Ruber::OutputWidget.new
      5.times{|i| ow.model.append_row Qt::StandardItem.new(i.to_s)}
      flexmock(ow).should_receive(:rows_changed).once
      ow.model.removeRows(0, 4)
    end
    
    it 'connects the model\'s rowsInserted signal to the do_auto_scroll slot' do
      ow = Ruber::OutputWidget.new
      flexmock(ow).should_receive(:do_auto_scroll).once.with(Qt::ModelIndex.new, 0, 3)
      ow.model.insertRows(0, 4)
    end
    
    it 'connects the view\'s "context_menu_requested(QPoint)" signal with its "show_menu(QPoint)" slot' do
      w = Ruber::OutputWidget.new
      flexmock(w).should_receive(:show_menu).once.with(Qt::Point.new(2,3))
      w.view.instance_eval{emit context_menu_requested(Qt::Point.new(2,3))}
    end
    
    it 'has an empty menu' do
      w = Ruber::OutputWidget.new
      w.instance_variable_get(:@menu).should be_empty
    end
    
    it 'calls the initialize_states_handler method' do
      w = Ruber::OutputWidget.new
      w.instance_variable_get(:@gui_state_handler_states).should be_a(Hash)
      w.instance_variable_get(:@gui_state_handler_handlers).should be_a(Hash)
    end
    
    it 'inserts the "copy", "copy_selected" and "clear" entries in the action list' do
      w = Ruber::OutputWidget.new
      w.instance_variable_get(:@action_list).should == ['copy', 'copy_selected', nil, 'clear']
    end
    
    it 'creates the actions for the "copy", "copy_selected" and "clear" entries' do
      w = Ruber::OutputWidget.new
      actions = w.instance_variable_get(:@actions)
      actions['copy'].should be_a(KDE::Action)
      actions['copy_selected'].should be_a(KDE::Action)
      actions['clear'].should be_a(KDE::Action)
    end
    
    it 'connects the "copy" action\'s triggered signal with its copy slot' do
      w = Ruber::OutputWidget.new
      flexmock(w).should_receive(:copy).once
      w.instance_variable_get(:@actions)['copy'].instance_eval{emit triggered}
    end
    
    it 'connects the "copy_selected" action\'s triggered signal with its copy_selected slot' do
      w = Ruber::OutputWidget.new
      flexmock(w).should_receive(:copy_selected).once
      w.instance_variable_get(:@actions)['copy_selected'].instance_eval{emit triggered}
    end
    
    it 'connects the "clear" action\'s triggered signal with its clear_output slot' do
      w = Ruber::OutputWidget.new
      flexmock(w).should_receive(:clear_output).once
      w.instance_variable_get(:@actions)['clear'].instance_eval{emit triggered}
    end
    
    it 'register handlers for the "copy", "copy_selected" and "clear" actions' do
      w = Ruber::OutputWidget.new
      handlers = w.instance_variable_get(:@gui_state_handler_handlers)
      actions = w.instance_variable_get(:@actions)
      handlers['no_text'].map(&:action).should == [actions['copy'], actions['copy_selected'], actions['clear']]
      handlers['no_selection'].map(&:action).should == [actions['copy_selected']]
    end
    
    it 'creates an handler which returns true if the no_text state is false and true otherwise for the "copy" action' do
      w = Ruber::OutputWidget.new
      handlers = w.instance_variable_get(:@gui_state_handler_handlers)
      handlers['no_text'][0].handler.call('no_text' => true).should be_false
      handlers['no_text'][0].handler.call('no_text' => false).should be_true
    end
    
    it 'creates an handler which returns true only if both the no_text and no_selection states are false for the "copy_selected" action' do
      w = Ruber::OutputWidget.new
      handlers = w.instance_variable_get(:@gui_state_handler_handlers)
      h = handlers['no_text'][1].handler
      h.call('no_text' => true, 'no_selection' => true).should be_false
      h.call('no_text' => false, 'no_selection' => true).should be_false
      h.call('no_text' => true, 'no_selection' => false).should be_false
      h.call('no_text' => false, 'no_selection' => false).should be_true
    end
    
    it 'creates an handler which returns true if the no_text state is false and true otherwise for the "clear" action' do
      w = Ruber::OutputWidget.new
      handlers = w.instance_variable_get(:@gui_state_handler_handlers)
      handlers['no_text'][2].handler.call('no_text' => true).should be_false
      handlers['no_text'][2].handler.call('no_text' => false).should be_true
    end

    it 'sets the "no_text" state to true' do
      w = Ruber::OutputWidget.new
      w.gui_state('no_text').should be_true
    end
    
    it 'sets the "no_selection" state to true' do
      w = Ruber::OutputWidget.new
      w.gui_state('no_selection').should be_true
    end
    
    it 'has no color registered' do
      w = Ruber::OutputWidget.new
      w.instance_variable_get(:@colors).should == {}
    end
    
    it 'has auto_scrolling enabled' do
      w = Ruber::OutputWidget.new
      w.auto_scroll.should be_true
    end
    
    it 'has the ignore_word_wrap_option attribute set to false' do
      w = Ruber::OutputWidget.new
      w.ignore_word_wrap_option.should be_false
    end
    
    it 'has no working dir' do
      w = Ruber::OutputWidget.new
      w.working_dir.should be_nil
    end
    
    it 'sets the @skip_first_file_in_title instance variable to true' do
      w = Ruber::OutputWidget.new
      w.skip_first_file_in_title.should be_true
    end

    it 'sets the @use_default_font to the value specified in opts' do
      w = Ruber::OutputWidget.new nil, :use_default_font => true
      w.instance_variable_get(:@use_default_font).should be_true
      w = Ruber::OutputWidget.new nil
      w.instance_variable_get(:@use_default_font).should be_nil
    end

  end
    
  describe 'fill_menu' do
    
    before do
      @ow = Ruber::OutputWidget.new
    end
    
    it 'emits the "about_to_fill_menu()" signal' do
      m = flexmock{|mk| mk.should_receive(:setup_actions).once}
      @ow.connect(SIGNAL(:about_to_fill_menu)){m.setup_actions}
      @ow.send :fill_menu
    end
    
    it 'inserts the actions and separators in the same order as they are in the @action_list instance variable, taking them from the @actions instance variable' do
      menu = @ow.instance_variable_get(:@menu)
      class << @ow
        public :action_list, :actions
      end
      @ow.action_list.insert_before 'copy_selected', 'test1', nil, 'test2'
      @ow.action_list << 'test3'
      @ow.actions['test1'] = KDE::Action.new(nil)
      @ow.actions['test2'] = KDE::Action.new(nil)
      @ow.actions['test3'] = KDE::Action.new(nil)
      flexmock(menu).should_receive(:add_action).with(@ow.actions['copy']).once.ordered
      flexmock(menu).should_receive(:add_action).with(@ow.actions['test1']).once.ordered
      flexmock(menu).should_receive(:add_separator).once.ordered
      flexmock(menu).should_receive(:add_action).with(@ow.actions['test2']).once.ordered
      flexmock(menu).should_receive(:add_action).with(@ow.actions['copy_selected']).once.ordered
      flexmock(menu).should_receive(:add_separator).once.ordered
      flexmock(menu).should_receive(:add_action).with(@ow.actions['clear']).once.ordered
      flexmock(menu).should_receive(:add_action).with(@ow.actions['test3']).once.ordered
      @ow.send :fill_menu
    end
    
  end
  
  describe '#show_menu' do
    
    before do
      @ow = Ruber::OutputWidget.new
    end
    
    it 'fills the menu if it is empty' do
      flexmock(@ow).should_receive(:fill_menu).once
      @ow.send :show_menu, Qt::Point.new(2,3)
    end
    
    it 'doesn\'t fill the menu if it isn\'t empty' do
      @ow.send :fill_menu
      #The following line is needed to avoid displaying the menu
      flexmock(@ow.instance_variable_get(:@menu)).should_receive(:popup)
      flexmock(@ow).should_receive(:fill_menu).never
      @ow.send :show_menu, Qt::Point.new(2,3)
    end
    
    it 'calls the popup method of the menu, passing it the argument, after filling it' do
      flexmock(@ow).should_receive(:fill_menu).once.ordered
      flexmock(@ow.instance_variable_get(:@menu)).should_receive(:popup).with(Qt::Point.new(2,3)).once.ordered
      @ow.send :show_menu, Qt::Point.new(2,3)
    end
    
  end
  
  describe '#data_changed' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @model = @ow.model
    end
    
    it 'sets the "no_text" state to false if the model contains at least an item' do
      flexmock(@model).should_receive(:row_count).once.and_return 3
      @ow.send(:rows_changed)
      @ow.state('no_text').should be_false
    end
    
    it 'sets the "no_text" state to true if the model contains at least an item' do
      @ow.send(:rows_changed)
      @ow.state('no_text').should be_true
    end
    
  end
  
  describe '#selection_changed' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @model = @ow.model
      3.times{|i| @model.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'sets the "no_selection" state to false if the selection contains at least one item' do
      sm = @ow.view.selection_model
      sm.select @model.index(0,0), Qt::ItemSelectionModel::Select
      @ow.send :selection_changed, Qt::ModelIndex.new, Qt::ModelIndex.new
      @ow.state('no_selection').should be_false
    end
    
    it 'sets the "no_selection" state to true if the selection contains at least one item' do
      sm = @ow.view.selection_model
      sm.select @model.index(0,0), Qt::ItemSelectionModel::Select
      sm.select @model.index(0,0), Qt::ItemSelectionModel::Deselect
      @ow.send :selection_changed, Qt::ModelIndex.new, Qt::ModelIndex.new
      @ow.state('no_selection').should be_true
    end
    
  end
  
  describe '#set_color_for' do
    
    before do
      @ow = Ruber::OutputWidget.new
    end
    
    it 'stores the given color under the given name' do
      @ow.set_color_for :error, Qt::Color.new(Qt.red)
      @ow.instance_variable_get(:@colors)[:error].should == Qt::Color.new(255, 0, 0)
    end
    
    it 'overwrites an existing entry with the same name' do
      @ow.set_color_for :error, Qt::Color.new(Qt.red)
      @ow.set_color_for :error, Qt::Color.new(Qt.blue)
      @ow.instance_variable_get(:@colors)[:error].should == Qt::Color.new(0, 0, 255)
    end
    
  end
  
  describe '#scroll_to' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    describe ', when called with a positive integer' do
      
      it 'it scrolls the view so that the row with the argument as index is at the bottom' do
        idx = @mod.index(2, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to 2
      end
      
      it 'scrolls so that the last item is at the bottom if the argument is greater than the index of the last row' do
        idx = @mod.index(4, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to 6
      end
      
    end
    
    describe ', when called with a negative integer' do
      
      it 'scrolls the view so that the row with index the argument, counting from below, is at the bottom' do
        idx = @mod.index(1, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to -4
      end
      
      it 'scrolls so that the first item is at the bottom if the absolute value of the argument is greater than the index of the last row - 1' do
        idx = @mod.index(0, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to -8
      end
      
    end
    
    describe ', when called with a Qt::ModelIndex' do
      
      it 'scrolls the view so that the item corresponding to the index is at the bottom of the view' do
        @mod.append_column(5.times.map{|i| Qt::StandardItem.new (2*i).to_s})
        idx = @mod.index(2,1)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to idx
      end
      
      it 'scrolls so that the last element is at the bottom if the index is invalid' do
        idx = @mod.index(4,0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to Qt::ModelIndex.new
      end
      
    end
    
    describe ', when called with nil' do
      
      it 'scrolls so that the last element is at the bottom' do
        idx = @mod.index(4,0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx, Qt::AbstractItemView::PositionAtBottom).once
        @ow.scroll_to nil
      end
      
    end
    
  end
  
  describe '#set_output_type' do
    
    before do
      @ow = Ruber::OutputWidget.new nil
      @colors = {:message => Qt::Color.new(Qt.blue), :error => Qt::Color.new(Qt.green)}
      @colors.each_pair{|k, v| @ow.set_color_for k, v}
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'sets the foreground of the given index with the color associated with the type' do
      @ow.set_output_type @mod.index(2,0), :error
      @ow.model.item(2,0).foreground.color.should == @colors[:error]
    end
    
    it 'sets the role corresponding to Ruber::OutputWidget::OutputTypeRole to a string version of the type' do
      @ow.set_output_type @mod.index(2,0), :error
      @ow.model.item(2,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'error'
    end
    
    it 'doesn\'t change the foreground if there\'s no color defined for the given type' do
      color = Qt::Color.new(Qt.yellow)
      @ow.model.item(2,0).foreground = Qt::Brush.new(color)
      @ow.set_output_type @mod.index(2,0), :test
      @ow.model.item(2,0).foreground.color.should == color
    end
    
    it 'doesn\'t change the output type if there\'s no color defined for the given type' do
      @ow.model.item(2,0).set_data(Qt::Variant.new('other'), Ruber::OutputWidget::OutputTypeRole)
      @ow.set_output_type @mod.index(2,0), :test
      @ow.model.item(2,0).data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'other'
    end
    
    it 'returns the type if the type was changed successfully' do
      @ow.set_output_type(@mod.index(2,0), :error).should == :error
    end
    
    it 'returns nil if the type wasn\'t changed successfully' do
      @ow.set_output_type(@mod.index(2,0), :test).should be_nil
    end
    
  end
  
  describe '#do_auto_scroll' do
    
    before do
      @ow = Ruber::OutputWidget.new
      5.times{|i| @ow.model.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'calls the scroll_to method passing the index of the model associated with the view corresponding to the last row and column 0 under the given parent, if auto scrolling is enabled' do
      flexmock(@ow.view).should_receive(:model).once.and_return(@ow.model)
      flexmock(@ow).should_receive(:scroll_to).once.with(@ow.model.index(3,0))
      @ow.send :do_auto_scroll, Qt::ModelIndex.new, 1, 3
    end
    
    it 'does nothing if auto scrolling is disabled' do
      @ow.auto_scroll = false
      flexmock(@ow).should_receive(:scroll_to).never
      @ow.send :do_auto_scroll, Qt::ModelIndex.new, 1, 3      
    end
    
    it 'does nothing if the slider is not at the maximum value' do
      flexmock(@ow).should_receive(:scroll_to).never
      scroll = @ow.view.vertical_scroll_bar
      scroll.maximum = 100
      scroll.value = 30
      @ow.send :do_auto_scroll, Qt::ModelIndex.new, 1, 3
    end
    
  end
  
  describe '#with_auto_scrolling' do
    
    before do
      @ow = Ruber::OutputWidget.new
    end
    
    it 'calls the block after setting the value of the auto_scroll attribute to the argument' do
      as = true
      @ow.with_auto_scrolling(false){as = @ow.auto_scroll}
      as.should be_false
      @ow.auto_scroll = false
      @ow.with_auto_scrolling(true){as = @ow.auto_scroll}
      as.should be_true
    end
    
    it 'restores the value of the auto_scroll attribute after executing the block' do
      @ow.with_auto_scrolling(false){}
      @ow.auto_scroll.should be_true
      @ow.with_auto_scrolling(true){}
      @ow.auto_scroll.should be_true
      @ow.auto_scroll = false
      @ow.with_auto_scrolling(false){}
      @ow.auto_scroll.should be_false
      @ow.with_auto_scrolling(true){}
      @ow.auto_scroll.should be_false
    end
    
    it 'restores the value of the auto_scroll attribute even if the block raises an exception' do
      @ow.with_auto_scrolling(false){raise StandardError} rescue nil
      @ow.auto_scroll.should be_true
      @ow.with_auto_scrolling(true){raise StandardError} rescue nil
      @ow.auto_scroll.should be_true
      @ow.auto_scroll = false
      @ow.with_auto_scrolling(false){raise StandardError} rescue nil
      @ow.auto_scroll.should be_false
      @ow.with_auto_scrolling(true){raise StandardError} rescue nil
      @ow.auto_scroll.should be_false
    end
    
  end
  
  describe '#title=' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @ow.set_color_for :message, Qt::Color.new(Qt.blue)
      3.times{|i| @ow.model.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'adds a new entry of type message at index 0, 0 if no title exists' do
      old_rc = @ow.model.row_count
      @ow.title = 'x'
      @ow.model.row_count.should == old_rc + 1
      it = @ow.model.item 0
      it.text.should == 'x'
      it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      it.data(Ruber::OutputWidget::IsTitleRole).to_bool.should be_true
    end
    
    it 'replaces the old title with the new one if a title already existed' do
      @ow.title = 'x'
      old_rc = @ow.model.row_count
      @ow.title = 'y'
      @ow.model.row_count.should == old_rc
      it = @ow.model.item 0
      it.text.should == 'y'
      it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      it.data(Ruber::OutputWidget::IsTitleRole).to_bool.should be_true
    end
    
  end
  
  describe '#has_title?' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @ow.set_color_for :message, Qt::Color.new(Qt.blue)
      3.times{|i| @ow.model.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'returns true if the item at row 0, column 0 has the IsTitleRole set to true' do
      @ow.title = 'x'
      @ow.should have_title
    end
    
    it 'returns false if the item at row 0, column 0 has the IsTitleRole set to false or unset' do
      @ow.should_not have_title
      @ow.model.item(0).set_data Qt::Variant.new(false), Ruber::OutputWidget::IsTitleRole
      @ow.should_not have_title
    end
    
    it 'returns false if the model is empty' do
      @ow.model.clear
      @ow.should_not have_title
    end
    
  end
  
  describe '#load_settings' do
    
    before do
      @colors = {
        :message => Qt::Color.new(0,0,0),
        :message_good => Qt::Color.new(0, 0, 255),
        :message_bad => Qt::Color.new(104, 0, 104),
        :output => Qt::Color.new(0, 0, 255),
        :output1 => Qt::Color.new(0, 0, 150),
        :output2 => Qt::Color.new(0, 255, 255),
        :error => Qt::Color.new(255, 0, 0),
        :error1 => Qt::Color.new(150, 0, 0),
        :error2 => Qt::Color.new(255, 255, 0),
        :warning => Qt::Color.new(160, 160, 164),
        :warning1 => Qt::Color.new(104, 104, 104),
        :warning2 => Qt::Color.new(192, 192, 192),
      }
      @config = flexmock do |m|
        @colors.each_pair{|k, v| m.should_receive(:[]).with(:output_colors, k).and_return(v).by_default}
        m.should_receive(:[]).with(:general, :wrap_output).and_return(false).by_default
        m.should_receive(:[]).with(:general, :output_font).and_return(Qt::Font.new('Courier', 10)).by_default
      end
      flexmock(Ruber).should_receive(:[]).with(:config).and_return @config
      @ow = Ruber::OutputWidget.new
    end
    
    it 'reads the colors stored in the output_colors config group' do
      @ow.send :load_settings
      res = @ow.instance_variable_get(:@colors)
      @colors.each_pair{|k, v| res[k].should == v}
    end
    
    it 'changes the foreground role of all the entries according to the new settings' do
      mod = @ow.model
      @colors.each_key do |k|
        it = Qt::StandardItem.new k.to_s
        it.foreground = Qt::Brush.new Qt::Color.new(Qt.green)
        it.set_data Qt::Variant.new(k.to_s), Ruber::OutputWidget::OutputTypeRole
        mod.append_row it
      end
      @ow.send :load_settings
      mod.row_count.times do |i| 
        it = mod.item i
        it.foreground.color.should == @colors[it.text.to_sym]
      end
    end
    
    it 'doesn\'t change items which have an unknown output type' do
      mod = @ow.model
      color = Qt::Color.new(123, 18, 234)
      it1 = Qt::StandardItem.new 'x'
      it1.set_data Qt::Variant.new('unknown'), Ruber::OutputWidget::OutputTypeRole
      it1.foreground = Qt::Brush.new(color)
      mod.append_row it1
      it2 = Qt::StandardItem.new 'y'
      it2.foreground = Qt::Brush.new(color)
      mod.append_row it2
      @ow.send :load_settings
      it1.foreground.color.should == color
      it2.foreground.color.should == color
    end
    
    it 'also changes the color of children items' do
      mod = @ow.model
      it1 = Qt::StandardItem.new('parent'){set_data Qt::Variant.new('error'), Ruber::OutputWidget::OutputTypeRole}
      it2 = Qt::StandardItem.new('child'){set_data Qt::Variant.new('output'), Ruber::OutputWidget::OutputTypeRole}
      it1.append_row it2
      mod.append_row it1
      @ow.send :load_settings
      it1.foreground.color.should == @colors[:error]
      it2.foreground.color.should == @colors[:output]
    end
    
    it 'sets the view font to the value stored in the general/output_font setting if the @use_default_font instance variable is false' do
      flexmock(@ow.view).should_receive(:font=).with(Qt::Font.new('Courier', 10)).once
      @ow.send :load_settings
    end
    
    it 'doesn\'t change the view font if the @use_default_font instance variable is true' do
      @ow.instance_variable_set(:@use_default_font, true)
      flexmock(@ow.view).should_receive(:font=).never
      @ow.send :load_settings
    end

    
    it 'attempts to set the word_wrap property of the view according to the general/wrap_output setting' do
      flexmock(@ow.view).should_receive(:word_wrap=).with(false).once
      @ow.send :load_settings
    end
    
    it 'doesn\'t attempt to change the word_wrap property of the view if the ignore_word_wrap_option attribute is true' do
      @ow.ignore_word_wrap_option = true
      flexmock(@ow.view).should_receive(:word_wrap=).never
      @ow.send :load_settings
    end
    
    it 'doesn\'t fail if the view doesn\'t have a word_wrap= method' do
      flexmock(@ow.view).should_receive(:word_wrap=).with(false).once.and_raise(NoMethodError)
      lambda{@ow.send :load_settings}.should_not raise_error
    end
    
  end
  
  describe '#clear_output' do
    
    it 'removes all the rows in the model' do
      ow = Ruber::OutputWidget.new
      mod = ow.model
      5.times{|i| mod.append_row Qt::StandardItem.new(i.to_s)}
      it = mod.item(2)
      it.append_row(Qt::StandardItem.new('x'))
      ow.send(:clear_output)
      mod.row_count.should == 0
    end
    
  end
  
  describe '#copy' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'calls the text_for_clipboard method passing it an array containing all the indexes' do
      c1 = Qt::StandardItem.new 'c1'
      c2 = Qt::StandardItem.new 'c2'
      c3 = Qt::StandardItem.new 'c3'
      c1.append_row c3
      it = @mod.item(3,0)
      it.append_row c1
      it.append_row c2
      exp = [@mod.index(0,0), @mod.index(1,0), @mod.index(2,0), it.index, c1.index, c3.index, c2.index, @mod.index(4,0)]
      flexmock(@ow).should_receive(:text_for_clipboard).once.with(exp)
      @ow.send :copy
    end
    
    it 'inserts the value returned by text_for_clipboard in the clipboard' do
      text = random_string
      flexmock(@ow).should_receive(:text_for_clipboard).once.with(5.times.map{|i| @mod.index(i,0)}).and_return text
      @ow.send :copy
      KDE::Application.clipboard.text.should == text
    end
    
  end
  
  describe '#copy_selected' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.append_column 5.times.map{|i| Qt::StandardItem.new (i+5).to_s}
      sm = @ow.view.selection_model
      @exp = [[1,0], [2,1], [3,1]].map{|i, j| @mod.index i, j}
      @exp.each{|i| sm.select i, Qt::ItemSelectionModel::Select}
    end
    
    it 'calls the text_for_clipboard method passing the list of selected items as argument' do
      flexmock(@ow).should_receive(:text_for_clipboard).once.with @exp
      @ow.send :copy_selected
    end
    
    it 'inserts the value returned by text_for_clipboard in the clipboard' do
      text = random_string
      flexmock(@ow).should_receive(:text_for_clipboard).once.with(@exp).and_return text
      @ow.send :copy_selected
      KDE::Application.clipboard.text.should == text
    end

  end
  
  describe '#text_for_clipboard' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.append_column 5.times.map{|i| Qt::StandardItem.new (i+5).to_s}
      sm = @ow.view.selection_model
      @exp = [[1,0], [2,1], [3,1]].map{|i, j| @mod.index i, j}
      @exp.each{|i| sm.select i, Qt::ItemSelectionModel::Select}
    end
    
    it 'returns a string where the text of all the top-level items in a single row in the argument are on the same line, separated by tabs' do
      text = @ow.send :text_for_clipboard, [@mod.index(0,0), @mod.index(1,1), @mod.index(1,0), @mod.index(0,1)]
      text.should == "0\t5\n1\t6"
    end
    
    it 'ignores any child item' do
      @mod.item(0,0).append_row Qt::StandardItem.new('c')
      text = @ow.send :text_for_clipboard, [@mod.index(0,0), @mod.index(1,1), @mod.index(1,0), @mod.index(0,1), @mod.index(0,0, @mod.index(0,0))]
      text.should == "0\t5\n1\t6"
    end
    
  end
  
  describe '#pinned_down?' do
    
    before do
      @ow = Ruber::OutputWidget.new
    end
    
    it 'returns true if the pinned tool button is on' do
      @ow.instance_variable_get(:@pin_button).checked = true
      @ow.should be_pinned_down
    end
    
    it 'returns false if the pinned tool button is off' do
      @ow.instance_variable_get(:@pin_button).checked = false
      @ow.should_not be_pinned_down
    end
      
  end

  
  describe '#maybe_open_file' do
    
    before do
      begin 
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).and_return(0).by_default
      rescue NameError
        Ruber::Application = flexmock{|m| m.should_receive(:keyboard_modifiers).and_return(0).by_default}
      end
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      @mod.append_row Qt::StandardItem.new ''
      @mw = flexmock{|m| m.should_ignore_missing}
      @cfg = flexmock{|m| m.should_receive(:[]).with(:general, :tool_open_files).and_return(:new_tab).by_default}
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(@cfg).by_default
    end
    
    after do
      Ruber.send :remove_const, :Application unless Ruber::Application.is_a?(KDE::Application)
    end
    
    it 'calls the find_filename_in_index method passing it the index' do
      flexmock(@ow).should_receive(:find_filename_in_index).once.with @mod.index(0,0)
      @ow.send :maybe_open_file, @mod.index(0,0)
    end
    
    describe ', when the find_filename_in_index methods returns an array' do
      
      before do
        flexmock(@ow).should_receive(:find_filename_in_index).with(@mod.index(0,0)).and_return([__FILE__, 10]).by_default
      end
      
      context 'when the Meta key is not pressed' do
        
        it 'calls the display_document method of the main window using the hints returned by hints but with the :existing key set to always' do
          hints = {:existing => :never, :new => :current, :split => :horizontal}
          flexmock(@ow).should_receive(:hints).and_return(hints)
          exp = hints.merge :existing => :always, :line => 9
          @mw.should_receive(:display_document).once.with(__FILE__, exp)
          @ow.send :maybe_open_file, @mod.index(0,0)
        end
        
      end
      
      context 'when the Meta key is pressed' do
        it 'calls the display_document method of the main window using the hints returned by hints but with the :existing key set to :never' do
          flexmock(Ruber::Application).should_receive(:keyboard_modifiers).and_return(Qt::MetaModifier)
          hints = {:existing => :always, :new => :current, :split => :horizontal}
          flexmock(@ow).should_receive(:hints).and_return(hints)
          exp = hints.merge :existing => :never, :line => 9
          @mw.should_receive(:display_document).once.with(__FILE__, exp)
          @ow.send :maybe_open_file, @mod.index(0,0)
        end

      end
      
      it 'decreases line numbers by one' do
        @mw.should_receive(:display_document).once.with(__FILE__, FlexMock.on{|h| h[:line].should == 9})
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'doesn\'t decrease the line number if it\'s 0' do
        flexmock(@ow).should_receive(:find_filename_in_index).with(@mod.index(0,0)).and_return([__FILE__, 0])
        @mw.should_receive(:display_document).once.with(__FILE__, FlexMock.on{|h| h[:line].should == 0})
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'hides the tool widget if #pinned_down? returns false' do
        flexmock(@ow).should_receive(:pinned_down?).and_return false
        @mw.should_receive(:hide_tool).with(@ow).once
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'doesn\'t hide the tool widget if #pinned_down? returns true' do
        flexmock(@ow).should_receive(:pinned_down?).and_return true
        @mw.should_receive(:hide_tool).with(@ow).never
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'doesn\'t hide the tool widget if the user pressed the middle mouse button' do
        flexmock(Ruber::Application).should_receive(:mouse_buttons).and_return(Qt::MidButton)
        flexmock(@ow).should_receive(:pinned_down?).and_return false
        @mw.should_receive(:hide_tool).with(@ow).never
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'gives focus to the editor' do
        ed = flexmock{|m| m.should_receive(:set_focus).once}
        @mw.should_receive(:display_document).once.and_return(ed)
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'doesn\'t attempt to give focus to the editor if no editor is found' do
        @mw.should_receive(:display_document).once.and_return nil
        lambda{@ow.send :maybe_open_file, @mod.index(0,0)}.should_not raise_error
      end
      
      it 'does nothing if the Control and/or Shift modifiers are pressed' do
        flexmock(@ow).should_receive(:find_filename_in_index).never
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).once.and_return(Qt::ShiftModifier.to_i)
        @ow.send :maybe_open_file, @mod.index(0,0)
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).once.and_return(Qt::ControlModifier.to_i)
        @ow.send :maybe_open_file, @mod.index(0,0)
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).once.and_return((Qt::ShiftModifier|Qt::ControlModifier).to_i)
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
      it 'ignores the Control and the shift modifiers if the selection mode of the view is NoSelection' do
        @ow.view.selection_mode = Qt::AbstractItemView::NoSelection
        flexmock(@ow).should_receive(:find_filename_in_index).with(@mod.index(0,0)).and_return([__FILE__, 10]).times(3)
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).once.and_return(Qt::ShiftModifier.to_i)
        @ow.send :maybe_open_file, @mod.index(0,0)
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).once.and_return(Qt::ControlModifier.to_i)
        @ow.send :maybe_open_file, @mod.index(0,0)
        flexmock(Ruber::Application).should_receive(:keyboard_modifiers).once.and_return((Qt::ShiftModifier|Qt::ControlModifier).to_i)
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
    end
    
    describe ', when the find_filename_in_index methods returns nil' do
      
      it 'does nothing' do
        @mw.should_receive(:display_document).never
        flexmock(@ow).should_receive(:find_filename_in_index).once.with(@mod.index(0,0)).and_return nil
        @ow.send :maybe_open_file, @mod.index(0,0)
      end
      
    end
    
  end
  
  describe '#hints' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @cfg = flexmock{|m| m.should_ignore_missing}
      @world = flexmock{|m| m.should_ignore_missing}
      flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
      flexmock(Ruber).should_receive(:[]).with(:config).and_return(@cfg).by_default
      flexmock(Ruber).should_receive(:[]).with(:world).and_return(@world).by_default
    end
    
    context 'when the general/tool_open_files setting is :split_horizontally' do
      
      before do
        @cfg.should_receive(:[]).with(:general, :tool_open_files).and_return(:split_horizontally).by_default
      end
      
      it 'returns {:new => :current_tab, :split => :horizontal}' do
        @ow.send(:hints).should == {:new => :current_tab, :split => :horizontal}
      end
      
      it 'returns {:new => :new_tab} if there is more than one view in the current tab' do
        views = Array.new(2){|i| flexmock("view #{i}")}
        tab = flexmock{|m| m.should_receive(:views).and_return views}
        env = flexmock do |m| 
          m.should_receive(:tab).with(views[1]).and_return tab
          m.should_receive(:active_editor).once.and_return views[1]
        end
        @world.should_receive(:active_environment).once.and_return env
        @ow.send(:hints).should == {:new => :new_tab}
      end
      
      it 'returns {:new => :new_tab} if there are no tabs' do
        env = flexmock do |m| 
          m.should_receive(:tab).and_return nil
          m.should_receive(:active_editor).and_return nil
        end
        @world.should_receive(:active_environment).once.and_return env
        @ow.send(:hints).should == {:new => :new_tab}
      end
      
    end
    
    context 'when the general/tool_open_files setting is :split_vertically' do
      
      before do
        @cfg.should_receive(:[]).with(:general, :tool_open_files).and_return(:split_vertically).by_default
      end

      it 'returns {:new => :current_tab, :split => :vertical}' do
        @ow.send(:hints).should == {:new => :current_tab, :split => :vertical}
      end
      
      it 'returns {:new => :new_tab} if there is more than one view in the current tab' do
        views = Array.new(2){|i| flexmock("view #{i}")}
        tab = flexmock{|m| m.should_receive(:views).and_return views}
        env = flexmock do |m| 
          m.should_receive(:tab).with(views[1]).and_return tab
          m.should_receive(:active_editor).once.and_return views[1]
        end
        @world.should_receive(:active_environment).once.and_return env
        @ow.send(:hints).should == {:new => :new_tab}
      end

      it 'returns {:new => :new_tab} if there are no tabs' do
        env = flexmock do |m| 
          m.should_receive(:tab).and_return nil
          m.should_receive(:active_editor).and_return nil
        end
        @world.should_receive(:active_environment).once.and_return env
        @ow.send(:hints).should == {:new => :new_tab}
      end
      
    end
    
    context 'when the general/tool_open_files setting is :new_tab' do
      
      it 'returns {:new => :new_tab}' do
        @cfg.should_receive(:[]).with(:general, :tool_open_files).and_return(:new_tab)
        @ow.send(:hints).should == {:new => :new_tab}
      end
      
    end
    
    context 'when the general/tool_open_files setting contains an invalid value' do

      it 'returns {:new => :new_tab}' do
        @cfg.should_receive(:[]).with(:general, :tool_open_files).and_return(:xyz)
        @ow.send(:hints).should == {:new => :new_tab}
      end
      
    end
    
  end
    
  
  describe '#find_filename_in_index' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      @mod.append_row Qt::StandardItem.new('')
    end
    
    context 'when the argument is a Qt::ModelIndex' do
      
      it 'calls #find_filename_in_string passing the text associated with the index as argument' do
        @mod.item(0,0).text = __FILE__
        flexmock(@ow).should_receive(:find_filename_in_string).with __FILE__
        @ow.send :find_filename_in_index, @mod.index(0,0)
      end
      
    end
    
    context 'when the argument is a string' do
      
      it 'calls #find_filename_in_string passing the string as argument' do
        @mod.item(0,0).text = __FILE__
        flexmock(@ow).should_receive(:find_filename_in_string).once.with __FILE__
        @ow.send :find_filename_in_index, __FILE__
      end
      
    end
    
    context 'when #find_filename_in_string returns nil' do
      
      it 'returns nil' do
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return nil
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should be_nil
      end
      
    end
    
    context 'when #find_filename_in_string returns a string' do
      
      it 'returns an array with the string as first argument and 0 as second argument' do
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return __FILE__
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
      end
      
    end
    
    context 'when #find_filename_in_string returns an array with one element' do
      
      it 'returns the array after appending a 0 to it' do
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [__FILE__]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
      end
      
    end
    
    context 'when #find_filename_in_string returns an array with two elements' do
      
      it 'returns the array' do
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [__FILE__, 6]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 6]
      end
      
    end

    context 'when the string or first element of the array returned by #find_filename_in_string is an absolute path' do
      
      it 'transforms it in a canonical path' do
        path_parts = __FILE__.split('/')
        orig_path = path_parts[0..-2].join('/') + '/../' + path_parts[-2..-1].join('/')
        flexmock(@ow).should_receive(:find_filename_in_string).once.and_return [orig_path, 0]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        flexmock(@ow).should_receive(:find_filename_in_string).once.and_return orig_path
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
      end
      
    end
    
    context 'when the string or first element of the array returned by #find_filename_in_string is a relative path' do
      
      it 'transforms it into an absolute filename relative to the working directory' do
        @ow.working_dir = File.dirname __FILE__
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [File.basename(__FILE__), 6]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [File.basename(__FILE__)]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return File.basename(__FILE__)
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 6]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
      end
      
      it 'transforms it in a canonical path' do
        @ow.working_dir = File.dirname File.dirname(__FILE__)
        path_parts = __FILE__.split('/')
        orig_path = "spec/../spec/#{File.basename(__FILE__)}"
        
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [orig_path, 6]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [orig_path]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return orig_path
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 6]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
      end

    end
    
    context 'when the string or first element of the array returned by #find_filename_in_string is an URL with the file scheme' do
      
      context 'if the name of the file is an absolute path' do
        
        it 'returns the path corresponding to the URL as first element of the array' do
          url = 'file://' + __FILE__
          flexmock(@ow).should_receive(:find_filename_in_string).once.and_return [url, 0]
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
          flexmock(@ow).should_receive(:find_filename_in_string).once.and_return url
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        end
        
        it 'transforms it in a canonical path' do
          path_parts = __FILE__.split('/')
          url = 'file://' + path_parts[0..-2].join('/') + '/../' + path_parts[-2..-1].join('/')
          flexmock(@ow).should_receive(:find_filename_in_string).once.and_return [url, 0]
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
          flexmock(@ow).should_receive(:find_filename_in_string).once.and_return url
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        end
      
      end
      
      context 'if the name of the file is a relative path' do
        
        it 'transforms it into an absolute filename relative to the working directory' do
          @ow.working_dir = File.dirname __FILE__
          url = 'file://' + File.basename(__FILE__)
          flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url, 6]
          flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url]
          flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return url
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 6]
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        end
        
        it 'transforms it in a canonical path' do
          @ow.working_dir = File.dirname File.dirname(__FILE__)
          url = "file://spec/../spec/#{File.basename(__FILE__)}"
          flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url, 6]
          flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url]
          flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return url
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 6]
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
          @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        end
        
      end
      
    end
    
    context 'when the string or first element of the array returned by #find_filename_in_string is an URL with a scheme different from file' do
    
      it 'returns the URL as it is as the first element of the array' do
        url = 'http://xyz/abc.it'
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url, 6]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return url
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [url, 6]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [url, 0]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [url, 0]
      end
      
    end
    
    it 'removes the first filename from the index text before passing it to find_filename_in_string if the index corresponds to the title and the @skip_first_file_in_title instance variable is true' do
      @mod.clear
      @ow.title = "/usr/bin/ruby #{__FILE__}"
      flexmock(@ow).should_receive(:find_filename_in_string).once.with(" #{__FILE__}").and_return [__FILE__, 0]
      @ow.send :find_filename_in_index, @mod.index(0,0)
    end
    
    it 'doesn\'t alter the item text before passing it to find_filename_in_string if the item is not the title' do
      @mod.item(0,0).text = "/usr/bin/ruby #{__FILE__}"
      flexmock(@ow).should_receive(:find_filename_in_string).once.with("/usr/bin/ruby #{__FILE__}").and_return ['/usr/bin/ruby', 0]
      @ow.send :find_filename_in_index, @mod.index(0,0)
    end
    
    it 'doesn\'t alter the text before passing it to find_filename_in_string if the argument is a string' do
      text = "/usr/bin/ruby #{__FILE__}"
      flexmock(@ow).should_receive(:find_filename_in_string).once.with("/usr/bin/ruby #{__FILE__}").and_return ['/usr/bin/ruby', 0]
      @ow.send :find_filename_in_index, text
    end
    
    it 'doesn\'t alter the title text before passing it to find_filename_in_string if the @skip_first_file_in_title instance variable is false' do
      @mod.clear
      @ow.title = "/usr/bin/ruby #{__FILE__}"
      @ow.skip_first_file_in_title = false
      flexmock(@ow).should_receive(:find_filename_in_string).once.with("/usr/bin/ruby #{__FILE__}").and_return ['/usr/bin/ruby', 0]
      @ow.send :find_filename_in_index, @mod.index(0,0)
    end
    
    describe ', when the string or the first element of the array returned by find_filename_in_string is not an absolute path and not an url' do
      
      it 'considers the path relative to the working_dir and transforms it into an absolute path' do
        @ow.working_dir = File.dirname(__FILE__)
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [File.basename(__FILE__), 6]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [File.basename(__FILE__)]
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return File.basename(__FILE__)
        url = 'http:///xyz/abc.rb'
        flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return [url]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 6]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [__FILE__, 0]
        @ow.send(:find_filename_in_index, @mod.index(0,0)).should == [url, 0]
      end
      
    end
    
    it 'returns nil if the file is a local file which doesn\'t exist' do
      flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return '/' + random_string
      @ow.send(:find_filename_in_index, @mod.index(0,0)).should be_nil
    end
    
    it 'returns the pair [url, line] even if the url doesn\'t exist when it represents a remote file' do
      flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return ['http://xyz/abc', 12]
      @ow.send(:find_filename_in_index, @mod.index(0,0)).should == ['http://xyz/abc', 12]
    end
    
    it 'returns nil if the file is a directory' do
      flexmock(@ow).should_receive(:find_filename_in_string).once.with('').and_return File.dirname(__FILE__)
      @ow.send(:find_filename_in_index, @mod.index(0,0)).should be_nil
    end
    
  end
  
  describe '#find_filename_in_string' do
    
    module FindFilenameInStringMacros
      
      def recognizes_file file, line = nil, exp_file = file, &blk
        
        it "recognizes the file when it is the whole line" do
          instance_eval &blk if blk
          str = line ? "#{file}:#{line}" : file 
          res = @ow.send :find_filename_in_string, str
          res.should == (line ? [exp_file, line] : [exp_file])
        end
        
        it 'recognizes the file at the end of the line' do
          instance_eval &blk if blk
          str = "#{random_string 5} #{line ? "#{file}:#{line}" : file }"
          res = @ow.send :find_filename_in_string, str
          res.should == (line ? [exp_file, line] : [exp_file])
        end
        
        it 'recognizes the file at the beginning of the line' do
          instance_eval &blk if blk
          str = "#{line ? "#{file}:#{line}" : file } #{random_string 5}"
          res = @ow.send :find_filename_in_string, str
          res.should == (line ? [exp_file, line] : [exp_file])
        end
        
        it 'recognizes the file in the middle of the line' do
          instance_eval &blk if blk
          str = "#{random_string 5} #{line ? "#{file}:#{line}" : file } #{random_string 5}"
          res = @ow.send :find_filename_in_string, str
          res.should == (line ? [exp_file, line] : [exp_file])
        end
        
        it 'recognizes the file when it\'s quoted' do
          instance_eval &blk if blk
          str = "#{random_string 5} <#{line ? "#{file}:#{line}" : file }> #{random_string 5}"
          res = @ow.send :find_filename_in_string, str
          res.should == (line ? [exp_file, line] : [exp_file])
        end
        
      end
      
      def does_not_recognize_file cond, file, line = nil
        
        it "doesn't recognize the file if #{cond}" do
          str = line ? "#{file}:#{line}" : file 
          res = @ow.send :find_filename_in_string, str
          res.should be_nil
        end
        
      end
      
    end
    
    before do
      @ow = Ruber::OutputWidget.new
    end
    
    extend FindFilenameInStringMacros
    
    context 'when the line contains an absolute path without line number' do
      recognizes_file '/abc/def/ghi.rb'
    end
      
    context 'when the line contains an absolute path with line number' do
      recognizes_file '/abc/def/ghi.rb', 45
    end
    
    context 'when the line contains an absolute path referring to the user\'s home directory without line numbers' do
      recognizes_file '~/abc/def/ghi.rb', nil, "#{ENV['HOME']}/abc/def/ghi.rb"
    end
    
    context 'when the line contains an absolute path referring to the user\'s home directory with line numbers' do
      recognizes_file '~/abc/def/ghi.rb', 45, "#{ENV['HOME']}/abc/def/ghi.rb"
    end

    context 'when the line contains an absolute path referring to another user\'s home directory and no line numbers' do
      prc = proc{flexmock(File).should_receive(:expand_path).with('~xyz/abc/def/ghi.rb').and_return('/home/xyz/abc/def/ghi.rb')}
      recognizes_file '~xyz/abc/def/ghi.rb', nil, "/home/xyz/abc/def/ghi.rb", &prc
    end
    
    context 'when the line contains an absolute path referring to another user\'s home directory with line numbers' do
      prc = proc{flexmock(File).should_receive(:expand_path).with('~xyz/abc/def/ghi.rb').and_return('/home/xyz/abc/def/ghi.rb')}
      recognizes_file '~xyz/abc/def/ghi.rb', 45, "/home/xyz/abc/def/ghi.rb", &prc
    end

    context 'when the line contains a filename starting with ./ and no line numbers' do
      recognizes_file './abc/def/ghi.rb'
    end
    
    context 'when the line contains a filename starting with ./ and line numbers' do
      recognizes_file './abc/def/ghi.rb', 12
    end
    
    context 'when the line contains a filename starting with ../ and no line numbers' do
      recognizes_file '../abc/def/ghi.rb'
    end
    
    context 'when the line contains a filename starting with ../ and line numbers' do
      recognizes_file '../abc/def/ghi.rb', 12
    end
    
    context 'when the line contains a filename starting with a dot not followed by a slash and no numbers' do
      recognizes_file '.abc/def/ghi.rb'
    end
    
    context 'when the line contains a filename starting with a dot not followed by a slash and line numbers' do
      recognizes_file '.abc/def/ghi.rb', 34
    end
    
    context 'when the line contains a relative path not starting with ./ and containing slashes with no line numbers' do
      recognizes_file 'abc/def/ghi.rb'
    end
    
    context 'when the line contains a relative path not starting with ./ and containing slashes with line numbers' do
      recognizes_file 'abc/def/ghi.rb', 29
    end    

    context 'when the line contains a relative filename without slash or leading dots with line numbers' do
      recognizes_file 'abc.rb', 132
    end
    
    context 'when the line contains an URL representing a relative file with no line numbers' do
      recognizes_file 'http://abc/def/ghi.rb'
    end    
    
    context 'when the line contains an URL representing a relative file with line numbers' do
      recognizes_file 'http://abc/def/ghi.rb', 456
    end    
    

    context 'when the line contains an absolute URL with no line numbers' do
      recognizes_file 'http:///abc/def/ghi.rb'
    end    
    
    context 'when the line contains an absolute URL with line numbers' do
      recognizes_file 'http:///abc/def/ghi.rb', 456
    end    
    
    it 'only considers the first match' do
      str = "#{__FILE__.upcase} #{__FILE__}"
      @ow.send(:find_filename_in_string, str).should == [__FILE__.upcase]
    end

  end
  
#   describe '#keyReleaseEvent' do
# 
#     before do
#       @ow = Ruber::OutputWidget.new
#       @mw = flexmock('main window'){|m| m.should_ignore_missing}
#       @ev = Qt::KeyEvent.new Qt::Event::KeyRelease, Qt::Key_A, Qt::NoModifier, 'a'
#       flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
#     end
#     
#     it 'gives focus to the current editor' do
#       ed = flexmock('editor'){|m| m.should_receive(:set_focus).once}
#       ed.should_ignore_missing
#       @mw.should_receive(:active_editor).once.and_return ed
#       @ow.send :keyReleaseEvent, @ev
#     end
#     
#     it 'inserts the text corresponding to the released key in the editor' do
#       ed = flexmock('editor'){|m| m.should_receive(:insert_text).once.with('a')}
#       ed.should_ignore_missing
#       @mw.should_receive(:active_editor).once.and_return ed
#       @ow.send :keyReleaseEvent, @ev
#     end
    
#     it 'does nothing if there\'s no active editor' do
#       @mw.should_receive(:active_editor).once.and_return nil
#       lambda{@ow.send :keyReleaseEvent, @ev}.should_not raise_error
#     end
#     
#     it 'returns nil' do
#       ed = flexmock('editor'){|m| m.should_receive(:insert_text).once.with('a')}
#       ed = flexmock('editor'){|m| m.should_ignore_missing}
#       @mw.should_receive(:active_editor).once.and_return ed
#       @mw.should_receive(:active_editor).once.and_return nil
#       @ow.send(:keyReleaseEvent, @ev).should be_nil
#       @ow.send(:keyReleaseEvent, @ev).should be_nil
#     end
    
#   end
  
end

describe Ruber::OutputWidget::Model do
  
  before do
    @ow = Ruber::OutputWidget.new
  end
  
  it 'inherits from Qt::StandardItemModel' do
    Ruber::OutputWidget::Model.ancestors.should include(Qt::StandardItemModel)
  end
  
  describe ', when created' do
    
    it 'can take one or two parameters' do
      lambda{Ruber::OutputWidget::Model.new @ow}.should_not raise_error
      lambda{Ruber::OutputWidget::Model.new @ow, Qt::Object.new}.should_not raise_error
    end
    
    it 'stores the first argument in the "@output_widget" instance variable' do
      mod = Ruber::OutputWidget::Model.new @ow
      mod.instance_variable_get(:@output_widget).should be_the_same_as(@ow)
    end
    
    it 'uses the second argument (or nil) as parent' do
      mod = Ruber::OutputWidget::Model.new @ow
      mod.parent.should be_nil
      w = Qt::Widget.new
      mod = Ruber::OutputWidget::Model.new @ow, w
      mod.parent.should be_the_same_as(w)
    end
    
    it 'sets the @global_flags instance variable to Qt::ItemIsEnabled | Qt::ItemIsSelectable converted to an integer' do
      mod = Ruber::OutputWidget::Model.new @ow
      mod.instance_variable_get(:@global_flags).should == (Qt::ItemIsEnabled | Qt::ItemIsSelectable).to_i
    end
    
  end
  
  describe '#global_flags=' do
    
    before do
      @mod = Ruber::OutputWidget::Model.new @ow
    end
    
    it 'sets the @global_flags instance variable to the argument converted to an integer' do
      @mod.global_flags = Qt::ItemIsEnabled | Qt::ItemIsUserCheckable
      @mod.instance_variable_get(:@global_flags).should == (Qt::ItemIsEnabled | Qt::ItemIsUserCheckable).to_i
    end
    
    it 'doesn\'t attempt to convert the value to an integer if it\'s nil' do
      @mod.global_flags = nil
      @mod.instance_variable_get(:@global_flags).should be_nil
    end
    
  end
  
  
  describe '#set' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
    end
    
    it 'takes three or four arguments' do
      lambda{@mod.set 'test', :message, 3}.should_not raise_error
      lambda{@mod.set 'test', :message, 3, {}}.should_not raise_error
    end
    
    it 'creates a new item having the first argument as text and passes it to set_item using the third argument as row and 0 as column if no optional argument are given' do
      @mod.set 'test', :message, 3
      @mod.item(3,0).text.should == 'test'
      flexmock(@mod).should_receive(:set_item).once.with(6, 0, FlexMock.on{|i| i.text == 'test'})
      @mod.set 'test', :message, 6
    end
    
    it 'creates a new item having the first argument as text and passes it to set_item using the third argument as row and the col option as column only the col optional argument is given' do
      @mod.set 'test', :message, 3, :col => 5
      @mod.item(3,5).text.should == 'test'
      flexmock(@mod).should_receive(:set_item).once.with(6, 5, FlexMock.on{|i| i.text == 'test'})
      @mod.set 'test', :message, 6, :col => 5
    end
    
    it 'creates a new item having the first argument as text and passes it to the set_child method of the given parent, using the given row (and column, if given) if the parent option is given' do
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.set 'test', :message, 3, :parent => @mod.item(2)
      @mod.item(2, 0).child(3, 0).text.should == 'test'
      @mod.set 'TEST', :message, 4, :parent => @mod.item(1), :col => 3
      @mod.item(1, 0).child(4, 3).text.should == 'TEST'
      flexmock(@mod.item(4)).should_receive(:set_child).once.with(5, 0, FlexMock.on{|i| i.text == 'Test'})
      flexmock(@mod.item(0)).should_receive(:set_child).once.with(2, 4, FlexMock.on{|i| i.text == 'Test'})
      @mod.set 'Test', :message, 5, :parent => @mod.item(4,0)
      @mod.set 'Test', :message, 2, :col => 4, :parent => @mod.item(0,0)
    end
    
    it 'sets the flags of the new item to the value returned by #global_flags' do
      flags = Qt::ItemIsEnabled | Qt::ItemIsUserCheckable
      @mod.global_flags = flags
      it = @mod.set 'test', :message, 0
      it.flags.should == flags
    end
    
    it 'leaves the default flags for the item if #global_flags returns nil' do
      @mod.global_flags = nil
      it = @mod.set 'test', :message, 0
      it.flags.should == Qt::ItemIsEnabled|Qt::ItemIsSelectable|Qt::ItemIsEditable|Qt::ItemIsDropEnabled|Qt::ItemIsDragEnabled
    end
    
    it 'calls the set_output_type method of the output widget passing it the index of the item and the type argument' do
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      flexmock(@ow).should_receive(:set_output_type).once.with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.row == 3 and i.column == 5}, :message)
      @mod.set 'text', :message, 3, :col => 5
    end
    
    it 'counts rows and columns backwards if negative' do
      flexmock(@mod).should_receive(:row_count).and_return(7)
      flexmock(@mod).should_receive(:column_count).and_return(5)
      flexmock(@mod).should_receive(:set_item).with(2, 0, Qt::StandardItem).once
      flexmock(@mod).should_receive(:set_item).with(1, 3, Qt::StandardItem).once
      @mod.set 'test', :message, -5
      @mod.set 'test', :message, -6, :col => -2
      
      it = Qt::StandardItem.new 'x'
      @mod.append_row it
      flexmock(it).should_receive(:row_count).and_return(7)
      flexmock(it).should_receive(:column_count).and_return(5)
      flexmock(it).should_receive(:set_child).with(2, 0, Qt::StandardItem).once
      flexmock(it).should_receive(:set_child).with(1, 3, Qt::StandardItem).once
      @mod.set 'test', :message, -5, :parent => it
      @mod.set 'test', :message, -6, :col => -2, :parent => it
    end
    
    it 'returns the new item' do
      it = @mod.set('text', :message, 3, :col => 5)
      it.should be_a(Qt::StandardItem)
      it.text.should == 'text'
      it.row.should == 3
      it.column.should == 5
    end
    
  end
  
describe '#insert' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'takes three or four arguments' do
      lambda{@mod.insert ['test'], :message, 3}.should_not raise_error
      lambda{@mod.insert ['test'], :message, 3, {}}.should_not raise_error
    end
    
    describe ', when the first argument is an array' do
      
      it 'creates a row from the array by replacing nil entries with invalid Qt::StandardItem and string entries with Qt::StandardItems with the strings as title and inserts it in the row given as third argument if no optional argument is given' do
        text = ['x', nil, nil, 'y', nil ]
        flexmock(@mod).should_receive(:insert_row).with(3, FlexMock.on{|a| a[0].text == 'x' and a[1].text.nil? and a[2].text.nil? and a[3].text == 'y' and a[4].text.nil?}).once
        @mod.insert text, :message, 3
      end
      
      it 'inserts the items as children of the item given in the :parent option, if given' do
        text = ['x', nil, nil, 'y', nil ]
        it = @mod.item(2,0)
        flexmock(it).should_receive(:insert_row).with(3, FlexMock.on{|a| a[0].text == 'x' and a[1].text.nil? and a[2].text.nil? and a[3].text == 'y' and a[4].text.nil?}).once
        3.times{it.append_row []}
        @mod.insert text, :message, 3, :parent => it
      end
      
      it 'calls the output widget\'s set_output_type for each valid item passing the second argument if the second argument is a symbol' do
        text = ['x', nil, nil, 'y', nil ]
        flexmock(@ow).should_receive(:set_output_type).with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.data.to_string == 'x'}, :error).once
        flexmock(@ow).should_receive(:set_output_type).with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.data.to_string == 'y'}, :error).once
        @mod.insert text, :error, 3
      end
      
      it 'calls the output widget\'s set_output_type for each valid item passing the corresponding item in the second argument if the second argument is an array' do
        text = ['x', nil, nil, 'y', nil ]
        flexmock(@ow).should_receive(:set_output_type).with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.data.to_string == 'x'}, :error).once
        flexmock(@ow).should_receive(:set_output_type).with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.data.to_string == 'y'}, :error1).once
        @mod.insert text, [:error, :error1], 3
      end
      
      it 'returns an array with the items corresponding to the strings in the argument' do
        text = ['x', nil, nil, 'y', nil ]
        res = @mod.insert text, :error, 3
        res.should == [@mod.item(3,0), @mod.item(3,3)]
      end
      
    end
    
    describe ', when the first argument is a string' do
      
      it 'inserts a row having the given text as first column row at the given position if no optional argument is given' do
        flexmock(@mod).should_receive(:insert_row).with(3, FlexMock.on{|a| a.size == 1 and a[0].is_a?(Qt::StandardItem) and a[0].text == 'x'}).once
        @mod.insert 'x', :message, 3
      end
        

      it 'inserts a row having the given text as the given column and all the previous elements empty at the given position if the col optional argument is given' do
        flexmock(@mod).should_receive(:insert_row).with(3, FlexMock.on{|a| a.size == 4 and a[0].text.nil? and a[1].text.nil? and a[2].text.nil? and a[3].is_a?(Qt::StandardItem) and a[3].text == 'x'}).once
        3.times{@mod.append_column []}
        @mod.insert 'x', :message, 3, :col => 3
      end
      
      it 'inserts the new row under the given parent if the :parent optional argument is given' do
        it = @mod.item(2,0)
        flexmock(it).should_receive(:insert_row).with(3, FlexMock.on{|a| a.size == 4 and a[0].text.nil? and a[1].text.nil? and a[2].text.nil? and a[3].is_a?(Qt::StandardItem) and a[3].text == 'x'}).once
        3.times{it.append_row []}
        3.times{it.append_column []}
        @mod.insert 'x', :message, 3, :col => 3, :parent => it
      end
      
      it 'calls the output widget\'s set_output_type for the new item passing the second argument if the second argument is a symbol' do
        flexmock(@ow).should_receive(:set_output_type).with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.data.to_string == 'x'}, :error).once
        @mod.insert 'x', :error, 3
      end
      
      it 'calls the output widget\'s set_output_type for the new item passing the first item in the second argument if the second argument is an array' do
        flexmock(@ow).should_receive(:set_output_type).with(FlexMock.on{|i| i.is_a?(Qt::ModelIndex) and i.data.to_string == 'x'}, :error).once
        @mod.insert 'x', [:error, :error1], 3
      end
      
      it 'returns an array with the items corresponding to the strings in the argument' do
        res = @mod.insert 'x', :error, 3
        res.should == [@mod.item(3,0)]
      end
      
    end
    
    it 'counts rows and columns backwards if negative ' do
      @mod.clear
      10.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.insert 'x', :message, -3
      @mod.item(7,0).text.should == 'x'
      
      @mod.clear
      10.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      4.times{|i| @mod.append_column []}
      @mod.insert 'x', :message, -3, :col => -3
      @mod.item(7,2).text.should == 'x'
      
      @mod.clear
      @mod.append_row [Qt::StandardItem.new('p'), Qt::StandardItem.new('x')]
      it = @mod.item 0,0
      10.times{|i| it.append_row Qt::StandardItem.new(i.to_s)}
      @mod.insert 'x', :message, -3, :parent => it
      it.child(7,0).text.should == 'x'
      
      @mod.clear
      @mod.append_row [Qt::StandardItem.new('p'), Qt::StandardItem.new('x')]
      it = @mod.item 0,0
      10.times{|i| it.append_row Qt::StandardItem.new(i.to_s)}
      4.times{|i| it.append_column []}
      @mod.insert 'x', :message, -3, :parent => it, :col => -3
      it.child(7,2).text.should == 'x'
    end
    
    it 'considers the row to be equal to row_count if the third argument is nil' do
      @mod.insert 'x', :message, nil
      @mod.item(@mod.row_count - 1,0).text.should == 'x'
    end
    
    it 'always inserts a new row and never changes an existing one' do
      rc = @mod.row_count
      @mod.insert 'x', :message, 3
      @mod.row_count.should == rc + 1
      @mod.item(3,0).text.should == 'x'
      @mod.item(4,0).text.should == '3'
    end
    
    it 'raises IndexError if the specified row is greater than the row_count of the parent or is less than the opposite of that number' do
      lambda{@mod.insert 'x', :message, 15}.should raise_error(IndexError, "Row index 15 is out of range. The allowed values are from 0 to 5")
      lambda{@mod.insert 'x', :message, -15}.should raise_error(IndexError, "Row index -10 is out of range. The allowed values are from 0 to 5")
    end
    
    it 'sets the flags of the new item to the value returned by #global_flags' do
      flags = Qt::ItemIsEnabled | Qt::ItemIsUserCheckable
      @mod.global_flags = flags
      row = @mod.insert ['x', 'y'], :message, 0
      row.each{|it| it.flags.should == flags}
    end
    
    it 'leaves the default flags for the item if #global_flags returns nil' do
      @mod.global_flags = nil
      flags = Qt::ItemIsEnabled|Qt::ItemIsSelectable|Qt::ItemIsEditable|Qt::ItemIsDropEnabled|Qt::ItemIsDragEnabled
      row = @mod.insert ['x', 'y'], :message, 0
      row.each{|it| it.flags.should == flags}
    end

    
  end
  
  describe '#insert_lines' do
    
    before do
      @ow = Ruber::OutputWidget.new
      @color = Qt::Color.new(0,0,255)
      @ow.set_color_for :message, @color
      @mod = @ow.model
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
    end
    
    it 'inserts each line of the text as a separate item (one below the other), using the #insert method' do
      text = "a\nb\nc"
      lines = %w[a b c]
      
      @mod.insert_lines text, :message, 2
      lines.each_with_index do |l, i|
        it = @mod.item(2+i)
        it.text.should == l
        it.foreground.color.should == @color
        it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      end
      
      @mod.clear
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.insert_lines text, :message, 2, :col => 3
      lines.each_with_index do |l, i|
        it = @mod.item(2+i, 3)
        it.text.should == l
        it.foreground.color.should == @color
        it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      end
      
      @mod.clear
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.item(1).insert_columns(0,3)
      @mod.item(1).insert_rows(0,2)
      @mod.insert_lines text, :message, 2, :col => 3, :parent => @mod.item(1)
      lines.each_with_index do |l, i|
        it = (@mod.item(1)).child(2+i, 3)
        it.text.should == l
        it.foreground.color.should == @color
        it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
      end
      
    end
    
    it 'counts lines and columns backwards if they\'re negative' do
      text = "a\nb\nc"
      flexmock(@mod).should_receive(:insert).with('a', :message, -5, :col => -2).once
      flexmock(@mod).should_receive(:insert).with('b', :message, -4, :col => -2).once
      flexmock(@mod).should_receive(:insert).with('c', :message, -3, :col => -2).once
      @mod.insert_lines text, :message, -5, :col => -2
      
      it = Qt::StandardItem.new 'x'
      @mod.append_row it
      flexmock(@mod).should_receive(:insert).with('a', :message, -5, :col => -2, :parent => it).once
      flexmock(@mod).should_receive(:insert).with('b', :message, -4, :col => -2, :parent => it).once
      flexmock(@mod).should_receive(:insert).with('c', :message, -3, :col => -2, :parent => it).once
      @mod.insert_lines text, :message, -5, :col => -2, :parent => it
    end
    
    it 'appends the rows at the and if the third argument is nil' do
      text = "a\nb\nc"
      flexmock(@mod).should_receive(:insert).with('a', :message, nil,{}).once
      flexmock(@mod).should_receive(:insert).with('b', :message, nil, {}).once
      flexmock(@mod).should_receive(:insert).with('c', :message, nil, {}).once
      @mod.insert_lines text, :message, nil
      
      it = Qt::StandardItem.new 'x'
      @mod.append_row it
      flexmock(@mod).should_receive(:insert).with('a', :message, nil, :parent => it).once
      flexmock(@mod).should_receive(:insert).with('b', :message, nil, :parent => it).once
      flexmock(@mod).should_receive(:insert).with('c', :message, nil, :parent => it).once
      @mod.insert_lines text, :message, nil, :parent => it
      
    end
    
    describe 'if the first argument is an array' do
      
      it 'inserts each entry as a separate item (one below the other), using the #insert method' do
        text = %w[a b c]
        @mod.insert_lines text, :message, 2
        lines = %w[a b c]
        lines.each_with_index do |l, i|
          it = @mod.item(2+i)
          it.text.should == l
          it.foreground.color.should == @color
          it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
        end
      end
      
      it 'doesn\'t attempt to separate an entry into lines' do
        text = %w[a\n b\n c]
        @mod.insert_lines text, :message, 2
        lines = %w[a\n b\n c]
        lines.each_with_index do |l, i|
          it = @mod.item(2+i)
          it.text.should == l
          it.foreground.color.should == @color
          it.data(Ruber::OutputWidget::OutputTypeRole).to_string.should == 'message'
        end
      end

    end
    
  end
  
end

describe Ruber::OutputWidget::ListView do
  
  describe '#contextMenuEvent' do
    
    it 'emits the "context_menu_requested(QPoint)" signal' do
      e = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Other, Qt::Point.new(1,2)
      flexmock(e).should_receive(:global_pos).once.and_return Qt::Point.new(2,3)
      view = Ruber::OutputWidget::ListView.new
      m = flexmock{|mk| mk.should_receive(:test).once.with(Qt::Point.new(2,3))}
      view.connect(SIGNAL('context_menu_requested(QPoint)')){|pt| m.test pt}
      view.send :contextMenuEvent, e
    end
    
  end
  
end

describe Ruber::OutputWidget::TreeView do
  
  describe '#contextMenuEvent' do
    
    it 'emits the "context_menu_requested(QPoint)" signal' do
      e = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Other, Qt::Point.new(1,2)
      flexmock(e).should_receive(:global_pos).once.and_return Qt::Point.new(2,3)
      view = Ruber::OutputWidget::TreeView.new
      m = flexmock{|mk| mk.should_receive(:test).once.with(Qt::Point.new(2,3))}
      view.connect(SIGNAL('context_menu_requested(QPoint)')){|pt| m.test pt}
      view.send :contextMenuEvent, e
    end
    
  end
  
end

describe Ruber::OutputWidget::TableView do
  
  describe '#contextMenuEvent' do
    
    it 'emits the "context_menu_requested(QPoint)" signal' do
      e = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Other, Qt::Point.new(1,2)
      view = Ruber::OutputWidget::TableView.new
      flexmock(e).should_receive(:global_pos).once.and_return Qt::Point.new(2,3)
      m = flexmock{|mk| mk.should_receive(:test).once.with(Qt::Point.new(2,3))}
      view.connect(SIGNAL('context_menu_requested(QPoint)')){|pt| m.test pt}
      view.send :contextMenuEvent, e
    end
    
  end
  
end