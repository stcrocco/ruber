require 'spec/common'

require 'ruber/filtered_output_widget'

describe Ruber::FilteredOutputWidget do
  
  it 'inherits from Ruber::OutputWidget' do
    Ruber::FilteredOutputWidget.ancestors.should include(Ruber::OutputWidget)
  end
  
  describe ', when created' do
    
    it 'can take up to two arguments' do
      lambda{Ruber::FilteredOutputWidget.new}.should_not raise_error
      lambda{Ruber::FilteredOutputWidget.new Qt::Widget.new}.should_not raise_error
      lambda{Ruber::FilteredOutputWidget.new Qt::Widget.new, {}}.should_not raise_error
    end
    
    it 'stores the contnet of the :filter optional entry in the @filter_model instance variable, if the :filter entry is given' do
      mod = Qt::SortFilterProxyModel.new
      ow = Ruber::FilteredOutputWidget.new nil, :filter => mod
      ow.instance_variable_get(:@filter_model).should be_the_same_as(mod)
    end
    
    it 'takes ownership of the filter model, if the :filter entry is given' do
      mod = Qt::SortFilterProxyModel.new
      ow = Ruber::FilteredOutputWidget.new nil, :filter => mod
      ow.filter_model.parent.should be_the_same_as(ow)
    end
    
    it 'creates a new instance of Ruber::FilteredOutputWidget::FilterModel and uses it as model, if the :filter entry isn\'t given' do
      ow = Ruber::FilteredOutputWidget.new
      ow.filter.should be_a(Ruber::FilteredOutputWidget::FilterModel)
      ow.filter.parent.should be_the_same_as(ow)
    end
    
    it 'sets the dynamic_sort_filter property of the filter model to true' do
      ow = Ruber::FilteredOutputWidget.new
      ow.filter.dynamic_sort_filter.should be_true
    end
    
    it 'associates the model with the filter model' do
      ow = Ruber::FilteredOutputWidget.new
      ow.filter.source_model.should be_the_same_as(ow.model)
    end
    
    it 'associates the view with the filter model' do
      ow = Ruber::FilteredOutputWidget.new
      ow.view.model.should be_a(Ruber::FilteredOutputWidget::FilterModel)
    end
    
    it 'connects the view\'s selection model\'s selectionChanged signal with its own selection_changed slot' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow).should_receive(:selection_changed).once.with(Qt::ItemSelection, Qt::ItemSelection)
      ow.view.selection_model.instance_eval{emit selectionChanged(Qt::ItemSelection.new, Qt::ItemSelection.new)}
    end

    it 'creates a KDE::LineEdit below the view and hides it' do
      editor = KDE::LineEdit.new
      flexmock(editor).should_receive(:hide).once
      flexmock(KDE::LineEdit).should_receive(:new).once.with(Ruber::FilteredOutputWidget).and_return editor
      ow = Ruber::FilteredOutputWidget.new
      ow.layout.item_at_position(1,0).widget.should be_the_same_as(editor)
    end
    
    it 'overrides the editor\'s keyReleasedEvent method so that it hides the editor itself if the ESC key (without modifiers) is pressed' do
      ow = Ruber::FilteredOutputWidget.new
      ed = ow.instance_variable_get(:@editor)
      flexmock(ed).should_receive(:hide).once
      ev = Qt::KeyEvent.new Qt::KeyEvent::KeyRelease, Qt::Key_Escape, 0
      ed.send :keyReleaseEvent, ev
      ev = Qt::KeyEvent.new Qt::KeyEvent::KeyRelease, Qt::Key_A, 0, 'A'
      ed.send :keyReleaseEvent, ev
      mods = [
        Qt::ControlModifier,
        Qt::ShiftModifier,
        Qt::AltModifier,
        Qt::MetaModifier,
        Qt::ControlModifier | Qt::ShiftModifier
      ]
      mods.each do |m|
        ev = Qt::KeyEvent.new Qt::KeyEvent::KeyRelease, Qt::Key_Escape, m.to_i
        ed.send :keyReleaseEvent, ev
      end
    end
    
    it 'gives a completion object to the editor' do
      ow = Ruber::FilteredOutputWidget.new
      ow.instance_variable_get(:@editor).completion_object.should be_a(KDE::Completion)
    end
    
    it 'connects the editor\'s returnPressed(QString) signal with its own "create_filter_from_editor()" slot' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow).should_receive(:create_filter_from_editor).once
      ow.instance_variable_get(:@editor).instance_eval{emit returnPressed('xyz')}
    end
    
    it 'adds the "Create Filter", "Ignore Filter" and "Clear Filter" entries to the action list, before the last separator' do
      ow = Ruber::FilteredOutputWidget.new
      ow.instance_variable_get(:@action_list).should == ['copy', 'copy_selected', nil, 'create_filter', 'ignore_filter', 'clear_filter', nil, 'clear']
    end
    
    it 'adds the "copy" and "clear_filter" actions to the actions hash' do
      ow = Ruber::FilteredOutputWidget.new
      hash = ow.instance_variable_get :@actions
      hash['create_filter'].should be_a(KDE::Action)
      hash['clear_filter'].should be_a(KDE::Action)
    end
    
    it 'adds a toggle "ignore_filter" action to the actions hash' do
      ow = Ruber::FilteredOutputWidget.new
      hash = ow.instance_variable_get :@actions
      hash['ignore_filter'].should be_a(KDE::ToggleAction)
    end
    
    it 'connects the "create_filter" action with the show_editor slot' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow).should_receive(:show_editor).once
      ow.instance_variable_get(:@actions)['create_filter'].instance_eval{emit triggered}
    end
    
    it 'connects the "clear_filter" action with the clear_filter slot' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow).should_receive(:clear_filter).once
      ow.instance_variable_get(:@actions)['clear_filter'].instance_eval{emit triggered}
    end
    
    it 'connects the "ignore_filter" action\'s toggled(bool) signal with the ignore_filter(bool) slot' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow).should_receive(:ignore_filter).once.with(false)
      ow.instance_variable_get(:@actions)['ignore_filter'].instance_eval{emit toggled(false)}
    end
    
    it 'creates a gui state handler for the clear_filter action which returns true if the no_filter state is false and false if the no_filter state is true' do
      ow = Ruber::FilteredOutputWidget.new
      handlers = ow.instance_variable_get(:@gui_state_handler_handlers)
      handlers['no_filter'].find{|h| h.action.object_name == 'clear_filter'}.handler.call('no_filter' => true).should be_false
      handlers['no_filter'].find{|h| h.action.object_name == 'clear_filter'}.handler.call('no_filter' => false).should be_true
    end
    
    it 'creates a gui state handler for the ignore_filter action which returns true if the no_filter state is false and false if the no_filter state is true' do
      ow = Ruber::FilteredOutputWidget.new
      handlers = ow.instance_variable_get(:@gui_state_handler_handlers)
      handlers['no_filter'].find{|h| h.action.object_name == 'ignore_filter'}.handler.call('no_filter' => true).should be_false
      handlers['no_filter'].find{|h| h.action.object_name == 'ignore_filter'}.handler.call('no_filter' => false).should be_true
    end
    
    it 'sets the "no_filter" gui state to true' do
      ow = Ruber::FilteredOutputWidget.new
      ow.gui_state('no_filter').should be_true
    end
    
    it 'disconnects the do_auto_scroll signal from the model and connects it to the filter model' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow).should_receive(:do_auto_scroll).once
      ow.model.append_row Qt::StandardItem.new('x')
      ow.filter.source_model = nil
      ow.model.append_row Qt::StandardItem.new('y')
    end
    
  end
  
  describe '#show_editor' do
    
    before do
      @ow = Ruber::FilteredOutputWidget.new
      @ed = @ow.instance_variable_get(:@editor)
    end
    
    it 'shows the editor' do
      flexmock(@ed).should_receive(:show).once
      @ow.send :show_editor
    end
    
    it 'gives focus to the editor' do
      flexmock(@ed).should_receive(:set_focus).once
      @ow.send :show_editor
    end
    
  end
  
  describe '#create_filter_from_editor' do
    
    before do
      @ow = Ruber::FilteredOutputWidget.new
      @ed = @ow.instance_variable_get(:@editor)
      @ed.text = 'xyz'
    end
    
    describe ', when the editor is not empty' do
    
      it 'adds the text in the editor widget to the completion object' do
        @ow.send :create_filter_from_editor
        @ed.completion_object.items[0].should == 'xyz'
        @ed.text = 'abc'
        @ow.send :create_filter_from_editor
        @ed.completion_object.items.should == %w[xyz abc]
      end
      
      it 'doesn\'t add an existing item' do
        @ow.send :create_filter_from_editor
        @ow.send :create_filter_from_editor
        @ed.completion_object.items.size.should == 1
      end
      
      it 'passes the text in the editor to the filter_reg_exp= method of the filter model' do
        flexmock(@ow.filter).should_receive(:filter_reg_exp=).once.with('xyz')
        @ow.send :create_filter_from_editor
      end
      
      it 'sets the "no_filter" gui state to false' do
        @ow.send :create_filter_from_editor
        @ow.gui_state('no_filter').should be_false
      end
      
      it 'doesn\'t call the "clear_filter" method' do
        flexmock(@ow).should_receive(:clear_filter).never
        @ow.send :create_filter_from_editor
      end
      
    end
    
    describe ', when the editor is empty' do
      
      before do
        @ed.clear
      end
      
      it 'doesn\'t add entries to the editor\'s completion object' do
        @ed.text = 'xyz'
        @ow.send :create_filter_from_editor
        @ed.clear
        @ow.send :create_filter_from_editor
        @ed.completion_object.items.should == ['xyz']
      end
      
      it 'calls the "clear_filter" method' do
        flexmock(@ow).should_receive(:clear_filter).once
        @ow.send :create_filter_from_editor
      end
      
      it 'doesn\'t call the filter model\'s filter_reg_exp= method' do
        flexmock(@ow).should_receive(:clear_filter)
        flexmock(@ow.filter).should_receive(:filter_reg_exp=).never
        @ow.send :create_filter_from_editor
      end

    end
    
    it 'hides the editor' do
      flexmock(@ed).should_receive(:hide).twice
      @ow.send :create_filter_from_editor
      @ed.clear
      @ow.send :create_filter_from_editor
    end
    
  end
  
  describe '#clear_filter' do
    
   before do
    @ow = Ruber::FilteredOutputWidget.new
   end 
   
   it 'calls the filter model\'s filter_reg_exp= method passing it an empty string' do
     flexmock(@ow.filter).should_receive(:filter_reg_exp=).once.with('')
     @ow.send :clear_filter
   end
   
   it 'sets the "no_filter" gui state to true' do
     @ow.set_state 'no_filter', false
     @ow.send :clear_filter
     @ow.gui_state('no_filter').should be_true
   end
    
  end
  
  describe '#toggle_ignore_filter' do
    
    it 'calls the ignore_filter= method of the filter model passing the argument' do
      ow = Ruber::FilteredOutputWidget.new
      flexmock(ow.filter).should_receive(:ignore_filter=).once.with true
      flexmock(ow.filter).should_receive(:ignore_filter=).once.with false
      ow.send :ignore_filter, true
      ow.send :ignore_filter, false
    end
    
  end
  
describe '#copy' do
    
    before do
      @ow = Ruber::FilteredOutputWidget.new
      @mod = @ow.model
      @filter = @ow.filter
      def @filter.filterAcceptsRow r, parent
        return true if parent.valid?
        idx = source_model.index(r, 0)
        idx.data.to_int < 4
      end
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @filter.invalidate
    end
    
    it 'calls the text_for_clipboard method passing it an array containing all the indexes in the filter model, but referred to the source model' do
      c1 = Qt::StandardItem.new 'c1'
      c2 = Qt::StandardItem.new 'c2'
      c3 = Qt::StandardItem.new 'c3'
      it = @mod.item(3,0)
      # Somehow, autoscrolling messes up the indexes
      @ow.with_auto_scrolling(false) do
        c1.append_row c3
        it.append_row c1
        it.append_row c2
      end
      exp = [@mod.index(0,0), @mod.index(1,0), @mod.index(2,0), it.index, c1.index, c3.index, c2.index]
      flexmock(@ow).should_receive(:text_for_clipboard).once.with(exp)
      @ow.send :copy
    end
    
    it 'inserts the value returned by text_for_clipboard in the clipboard' do
      text = random_string
      flexmock(@ow).should_receive(:text_for_clipboard).once.with(4.times.map{|i| @mod.index(i,0)}).and_return text
      @ow.send :copy
      KDE::Application.clipboard.text.should == text
    end
    
  end
  
  describe '#copy_selected' do
    
    before do
      @ow = Ruber::FilteredOutputWidget.new
      @mod = @ow.model
      @filter = @ow.filter
      5.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @mod.append_column 5.times.map{|i| Qt::StandardItem.new (i+5).to_s}
      def @filter.filterAcceptsRow r, parent
        return true if parent.valid?
        idx = source_model.index(r, 0)
        idx.data.to_int < 4
      end
      @filter.invalidate
      sm = @ow.view.selection_model
      @exp = [[1,0], [2,1], [3,1]].map{|i, j| @mod.index i, j}
      @exp.each{|i| sm.select @filter.map_from_source(i), Qt::ItemSelectionModel::Select}
    end
    
    it 'calls the text_for_clipboard method passing the list of selected items in the source model as argument' do
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
  
  describe '#scroll_to' do
    
    before do
      @ow = Ruber::FilteredOutputWidget.new
      @mod = @ow.model
      @filter = @ow.filter
      def @filter.filterAcceptsRow row, parent
        idx = source_model.index(row, 0)
        idx.data.to_int % 2 != 0
      end
      10.times{|i| @mod.append_row Qt::StandardItem.new(i.to_s)}
      @filter.invalidate
    end
    
    describe ', when called with a positive integer' do
      
      it 'it scrolls the view so that the row with the argument as index (in the filter model) is visible' do
        idx = @filter.index(3, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to 3
      end
      
      it 'scrolls to the last item if the argument is greater than the index of the last row of the filter model' do
        idx = @filter.index(@filter.row_count - 1, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to @filter.row_count + 3
      end
      
    end
    
    describe ', when called with a negative integer' do
      
      it 'scrolls the view so that the row with index the argument (in the filter model), counting from below, is visible' do
        idx = @filter.index(3, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to -2
      end
      
      it 'scrolls to the first item if the absolute value of the argument is greater than the index of the last row - 1 (in the filter model)' do
        idx = @filter.index(0, 0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to -8
      end
      
    end
    
    describe ', when called with a Qt::ModelIndex' do
      
      it 'converts the index to the filter model, if it refers to the source model' do
        src_idx = @mod.index(1,0)
        idx = @filter.map_from_source src_idx
        flexmock(@filter).should_receive(:map_from_source).once.with(src_idx).and_return idx
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to src_idx
      end
      
      it 'doesn\'t attempt to convert the index if it already refers to the filter model' do
        idx = @filter.index(2,0)
        flexmock(@filter).should_receive(:map_from_source).never
        @ow.scroll_to idx
      end
      
      it 'scrolls the view so that the item corresponding to the index is visible' do
        @mod.append_column(5.times.map{|i| Qt::StandardItem.new (2*i).to_s})
        @filter.invalidate
        idx = @filter.map_from_source @mod.index(3,1)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to idx
      end
      
      it 'scrolls to the last element of the filter model if the index is invalid' do
        idx = @filter.index(@filter.row_count - 1,0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to Qt::ModelIndex.new
      end
      
    end
    
    describe ', when called with nil' do
      
      it 'scrolls to the last element of the filter model' do
        idx = @filter.index(@filter.row_count - 1,0)
        flexmock(@ow.view).should_receive(:scroll_to).with(idx).once
        @ow.scroll_to nil
      end
      
    end
    
  end
  
  describe '#maybe_open_file' do
    
    before do
      unless Ruber.constants.include? :Application
        Ruber::Application = flexmock(:keyboard_modifiers => 0)
      end
      @ow = Ruber::FilteredOutputWidget.new
      @mod = @ow.model
      @filter = @ow.filter
      @mod.append_row Qt::StandardItem.new('x')
    end
    
    it 'converts the index from the filter model to the source model before calling super' do
      flexmock(@ow).should_receive(:find_filename_in_index).with(FlexMock.on{|i| i.model.equal?(@mod) and i.data.to_string == 'x'}).once
      @ow.send :maybe_open_file, @filter.index(0,0)
    end
    
    it 'doesn\'t attempt to convert the index if it already refers to the source model' do
      flexmock(@filter).should_receive(:map_to_source).never
      flexmock(@ow).should_receive(:find_filename_in_index).with(FlexMock.on{|i| i.model.equal?(@mod) and i.data.to_string == 'x'}).once
      @ow.send :maybe_open_file, @mod.index(0,0)
    end
    
    after do
      Ruber.send :remove_const, :Application unless Ruber::Application.is_a?(KDE::Application)
    end
    
  end

  
end

describe Ruber::FilteredOutputWidget::FilterModel do
  
  it 'inherits Qt::SortFilterProxyModel' do
    Ruber::FilteredOutputWidget::FilterModel.ancestors.should include(Qt::SortFilterProxyModel)
  end
  
  describe ', when created' do
    
    it 'takes up to two arguments' do
      lambda{Ruber::FilteredOutputWidget::FilterModel.new}.should_not raise_error
      lambda{Ruber::FilteredOutputWidget::FilterModel.new Qt::Widget.new}.should_not raise_error
      lambda{Ruber::FilteredOutputWidget::FilterModel.new nil, :top_level}.should_not raise_error
    end
    
    it 'stores the second argument passed to the constructor in the @exclude instance variable' do
      mod = Ruber::FilteredOutputWidget::FilterModel.new nil, :top_level
      mod.exclude.should == :top_level
    end
    
    it 'doesn\'t ignore the filter' do
      mod = Ruber::FilteredOutputWidget::FilterModel.new nil, :top_level
      mod.filter_ignored?.should  be_false
    end
    
  end
  
  describe '#ignore_filter=' do
    
    before do
      @mod = Ruber::FilteredOutputWidget::FilterModel.new
    end
    
    it 'sets the @ignore_filter instance variable to the argument' do
      @mod.ignore_filter = true
      @mod.filter_ignored?.should be_true
    end
    
    it 'invalidates the model' do
      flexmock(@mod).should_receive(:invalidate).once
      @mod.ignore_filter = true
    end
    
  end
  
  describe '#filter_reg_exp=' do

    before do
      @mod = Ruber::FilteredOutputWidget::FilterModel.new
    end
    
    it 'sets the filter reg exp to the argument' do
      @mod.filter_reg_exp = 'a.*'
      @mod.filter_reg_exp.should == Qt::RegExp.new('a.*')
    end
    
    it 'emits the filter_changed(QString) signal' do
      m = flexmock{|mk| mk.should_receive(:test).once.with('a.*')}
      @mod.connect(SIGNAL('filter_changed(QString)')){|s| m.test s}
      @mod.filter_reg_exp = 'a.*'
    end
    
  end
  
  describe '#filterAcceptsRow' do
    
    before do
      @source = Qt::StandardItemModel.new
      5.times{|i| @source.append_row Qt::StandardItem.new(i.to_s)}
      @mod = Ruber::FilteredOutputWidget::FilterModel.new
      @mod.source_model = @source
    end
    
    it 'always returns true if the filter is ignored' do
      @mod.ignore_filter = true
      @mod.filter_reg_exp = '[12]'
      5.times do |i|
        @mod.send(:filterAcceptsRow, i, Qt::ModelIndex.new).should be_true 
      end
    end
    
    it 'always returns true if calling the exclude_from_filtering? method with the given row and parent returns true' do
      5.times{|i| flexmock(@mod).should_receive(:exclude_from_filtering?).once.with(i, Qt::ModelIndex).and_return(true)}
      @mod.filter_reg_exp = '[12]'
      5.times do |i|
        @mod.send(:filterAcceptsRow, i, Qt::ModelIndex.new).should be_true 
      end
    end
    
    it 'filters any row for which exclude_from_filtering? returns false according to the regexp' do
      @mod.filter_reg_exp = '[12]'
      flexmock(@mod).should_receive(:exclude_from_filtering?).once.with(0, Qt::ModelIndex).and_return(true)
      flexmock(@mod).should_receive(:exclude_from_filtering?).and_return(false)
      @mod.send(:filterAcceptsRow, 0, Qt::ModelIndex.new).should be_true
      @mod.send(:filterAcceptsRow, 1, Qt::ModelIndex.new).should be_true 
      @mod.send(:filterAcceptsRow, 2, Qt::ModelIndex.new).should be_true 
      @mod.send(:filterAcceptsRow, 3, Qt::ModelIndex.new).should be_false
      @mod.send(:filterAcceptsRow, 4, Qt::ModelIndex.new).should be_false
    end
    
  end
  
  describe '#exclude=' do

    before do
      @source = Qt::StandardItemModel.new
      5.times{|i| @source.append_row Qt::StandardItem.new(i.to_s)}
      @source.item(0,0).append_row Qt::StandardItem.new('c')
      @mod = Ruber::FilteredOutputWidget::FilterModel.new
      @mod.source_model = @source
    end
    
    it 'replaces the @exclude instance variable with the argument' do
      @mod.instance_variable_set :@exclude, :children
      @mod.exclude = :toplevel
      @mod.instance_variable_get(:@exclude).should == :toplevel
    end
    
    it 'invalidates the filter' do
      flexmock(@mod).should_receive(:invalidate_filter).once
      @mod.exclude = :toplevel
    end
    
  end
  
  describe '#exclude_from_filtering?' do
    
    before do
      @source = Qt::StandardItemModel.new
      5.times{|i| @source.append_row Qt::StandardItem.new(i.to_s)}
      @source.item(0,0).append_row Qt::StandardItem.new('c')
      @mod = Ruber::FilteredOutputWidget::FilterModel.new
      @mod.source_model = @source
    end
    
    it 'returns false for child items and true for toplevel items if the @exclude instance variable is :toplevel' do
      @mod.exclude = :toplevel
      @mod.send(:exclude_from_filtering?, 0, Qt::ModelIndex.new).should be_true
      @mod.send(:exclude_from_filtering?, 0, @source.index(0,0)).should be_false
    end
    
    it 'returns true for child items and false for toplevel items if the @exclude instance variable is :children' do
      @mod.exclude = :children
      @mod.send(:exclude_from_filtering?, 0, Qt::ModelIndex.new).should be_false
      @mod.send(:exclude_from_filtering?, 0, @source.index(0,0)).should be_true
    end

    it 'always returns false for other values of the @exclude instance variable' do
      @mod.exclude = :nil
      @mod.send(:exclude_from_filtering?, 0, Qt::ModelIndex.new).should be_false
      @mod.send(:exclude_from_filtering?, 0, @source.index(0,0)).should be_false
      @mod.exclude = :x
      @mod.send(:exclude_from_filtering?, 0, Qt::ModelIndex.new).should be_false
      @mod.send(:exclude_from_filtering?, 0, @source.index(0,0)).should be_false
    end
    
  end
  
end