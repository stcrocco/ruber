require 'spec/common'

require 'ruber/main_window/workspace'

describe 'Ruber::Workspace, when created' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
  end
  
  it 'should read the sizes of the tool widgets from the configuration manager' do
    exp = {'Tool1' => 30, 'Tool2' => 50}
    @config.should_receive(:[]).with(:workspace, :tools_sizes).once.and_return(exp)
    ws = Ruber::Workspace.new
    ws.instance_variable_get(:@sizes).should == exp
  end
  
  it 'should create three button bars' do
    @ws.layout.item_at_position(0,0).widget.should be_a(KDE::MultiTabBar)
    @ws.layout.item_at_position(0,2).widget.should be_a(KDE::MultiTabBar)
    @ws.layout.item_at_position(1,0).widget.should be_a(KDE::MultiTabBar)
    @ws.layout.item_at_position(1,1).widget.should be_a(KDE::MultiTabBar)
    @ws.layout.item_at_position(1,2).widget.should be_a(KDE::MultiTabBar)
  end
  
  it 'should create a vertical splitter and a horizontal one' do
    vsplit = @ws.layout.item_at_position(0,1).widget
    vsplit.should be_a(Qt::Splitter)
    vsplit.orientation.should == Qt::Vertical
    hsplit = vsplit.widget(0)
    hsplit.should be_a(Qt::Splitter)
    hsplit.orientation.should == Qt::Horizontal
  end
  
  it 'should put a stacked widget in the bottom half of the vertical splitter' do
    vsplit = @ws.layout.item_at_position(0,1).widget
    vsplit.widget(1).should be_a(Qt::StackedWidget)
  end
  
  it 'should put a stacked widget in the first and third part of the horizontal splitter' do
    hsplit = @ws.layout.item_at_position(0,1).widget.widget(0)
    hsplit.widget(0).should be_a(Qt::StackedWidget)
    hsplit.widget(2).should be_a(Qt::StackedWidget)
  end
  
  it 'should put a KDE::TabWidget in the middle of the horizontal splitter' do
    hsplit = @ws.layout.item_at_position(0,1).widget.widget(0)
    hsplit.widget(1).should be_a(KDE::TabWidget)
  end
  
  it 'should have all the stacks hidden' do
    [:left, :bottom, :right].each{|s| @ws.instance_variable_get(:@stacks)[s].should be_hidden}
  end
  
  it 'should enable the document mode for the tab widget' do
    @ws.instance_variable_get(:@views).document_mode.should be_true
  end
  
end

describe 'Ruber::Workspace#add_tool_widget' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
  end
  
  it 'should add a tab to the button bar on the given side' do
    bar = @ws.instance_variable_get(:@button_bars)[:left]
    pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    id = bar.append_tab pix, -1, "Tool"
    flexmock(bar).should_receive(:append_tab).once.and_return id
    @ws.add_tool_widget :left, Qt::Widget.new, pix, "Tool"
  end
  
  it 'should add the given widget to the stacked widget of the correct side' do
    w = Qt::LineEdit.new
    pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    @ws.add_tool_widget :right, w, pix, 'Tool'
    stack = @ws.layout.item_at_position(0,1).widget.widget(0).widget(2)
    stack.index_of(w).should_not == -1
  end
  
  it 'should raise ArgumentError if the widget has already been added' do
    w = Qt::LineEdit.new
    pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    @ws.add_tool_widget :right, w, pix, 'Tool'
    lambda{@ws.add_tool_widget :right, w, pix, 'Tool'}.should raise_error(ArgumentError, "This widget has already been added as tool widget")
  end
  
end

describe 'Ruber::Workspace#remove_tool_widget' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widget = Qt::Label.new
    @bar = @ws.instance_variable_get(:@button_bars)[:bottom]
    @pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    @id = @bar.append_tab @pix, -1, "Tool"
    flexmock(@bar).should_receive(:append_tab).by_default.and_return @id
    @ws.add_tool_widget :bottom, @widget, @pix, 'Tool'
  end
  
  it 'should emit the "removing_tool(QWidget*)" signal' do
    m = flexmock{|mk| mk.should_receive(:removing_tool).once.with(@widget)}
    @ws.connect(SIGNAL('removing_tool(QWidget*)')){|w| m.removing_tool(w)}
    @ws.remove_tool_widget @widget
  end
  
  it 'should remove the tab corresponding to the widget from the tab bar' do
    flexmock(@bar).should_receive(:remove_tab).once.with(@id)
    @ws.remove_tool_widget @widget
  end
  
  it 'should remove the widget from its stack' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    flexmock(stack).should_receive(:remove_widget).with(@widget).once
    #Mocking empty? is needed because otherwise resize_tool is called (because the tool hasn't truly been removed, since we mocked the method)
    flexmock(stack).should_receive(:empty?).and_return true
    @ws.remove_tool_widget @widget
  end
  
  it 'should activate another tool widget on the same side if the removed widget was the raised one' do
    other_widget = Qt::Widget.new
    flexmock(@bar).should_receive(:append_tab).once.and_return @id + 1
    @ws.add_tool_widget :bottom, other_widget, @pix, 'Tool1'
    @widget.parent.current_widget.should equal(@widget)
    flexmock(@ws).should_receive(:raise_tool).once.with(other_widget)
    @ws.remove_tool_widget @widget
  end
  
  it 'should hide the stack if the removed tool was the last' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.visible = true
    @ws.remove_tool_widget @widget
    stack.should be_hidden
  end
  
  it 'should find out the tool to remove from its name if passed a string argument' do
    @widget.object_name = 'tool1'
    flexmock(@bar).should_receive(:remove_tab).once.with(@id)
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    flexmock(stack).should_receive(:remove_widget).with(@widget).once
    #Mocking empty? is needed because otherwise resize_tool is called (because the tool hasn't truly been removed, since we mocked the method)
    flexmock(stack).should_receive(:empty?).and_return true
    @ws.remove_tool_widget 'tool1'
  end
  
  it 'should find out the tool to remove from its name if passed a symbol argument' do
    @widget.object_name = 'tool1'
    flexmock(@bar).should_receive(:remove_tab).once.with(@id)
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    flexmock(stack).should_receive(:remove_widget).with(@widget).once
    #Mocking empty? is needed because otherwise resize_tool is called (because the tool hasn't truly been removed, since we mocked the method)
    flexmock(stack).should_receive(:empty?).and_return true
    @ws.remove_tool_widget :tool1
  end
  
  it 'should do nothing if the widget isn\'t a tool widget' do
    lambda{@ws.remove_tool_widget(Qt::Widget.new)}.should_not raise_error
    lambda{@ws.remove_tool_widget(:xyz)}.should_not raise_error
  end
  
end

describe 'Ruber::Workspace#raise_tool' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::Label.new, Qt::TextEdit.new]
    pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    @ws.add_tool_widget :bottom, @widgets[0], pix, 'Tool1'
    @ws.add_tool_widget :bottom, @widgets[1], pix, 'Tool2'
    @data = @ws.instance_variable_get :@widgets
  end
  
  it 'should lower the tab corresponding to the previously raised tool in the bar' do
    bar = @ws.instance_variable_get(:@button_bars)[:bottom]
    @ws.raise_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    bar.is_tab_raised(@data[@widgets[0]].id).should be_true
    @ws.raise_tool @widgets[1]
    bar.is_tab_raised(@data[@widgets[0]].id).should be_false
  end
  
  it 'should raise the tab corresponding to the widget' do
    bar = @ws.instance_variable_get(:@button_bars)[:bottom]
    bar.is_tab_raised(@data[@widgets[0]].id).should_not be
    @ws.raise_tool @widgets[0]
    bar.is_tab_raised(@data[@widgets[0]].id).should be_true
  end

  it 'should put the widget on top of its stack' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should == @widgets[0]
    @ws.raise_tool @widgets[1]
    stack.current_widget.should == @widgets[1]
  end
  
  it 'should emit the "tool_raised(QWidget*)" signal' do
    m = flexmock{|mk| mk.should_receive(:tool_raised).once.with(@widgets[0])}
    stack = @widgets[0].parent
    stack.current_widget = @widgets[1]
    @ws.connect(SIGNAL('tool_raised(QWidget*)')){|w| m.tool_raised w}
    @ws.raise_tool @widgets[0]
  end
  
  it 'should emit the tool_shown(QWidget*) signal if the stack was visible and the widget wasn\'t' do
    stack = @widgets[0].parent
    flexmock(stack).should_receive(:current_widget).and_return @widgets[1]
    flexmock(stack).should_receive(:visible?).and_return true
    m = flexmock{|mk| mk.should_receive(:tool_shown).once.with(@widgets[0])}
    @ws.connect(SIGNAL('tool_shown(QWidget*)')){|w| m.tool_shown w}
    @ws.raise_tool @widgets[0]
  end
  
  it 'should not emit the tool_shown(QWidget*) signal if the stack and the tool widget were visible' do
    stack = @widgets[0].parent
    flexmock(stack).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:current_widget).and_return @widgets[0]
    m = flexmock{|mk| mk.should_receive(:tool_shown).never.with(@widgets[0])}
    @ws.connect(SIGNAL('tool_shown(QWidget*)')){|w| m.tool_shown w}
    @ws.raise_tool @widgets[0]
  end
  
  it 'should not emit the tool_shown(QWidget*) signal if the stack wasn\'t visible' do
    stack = @widgets[0].parent
    flexmock(stack).should_receive(:visible?).and_return false
    flexmock(stack).should_receive(:current_widget).and_return @widgets[1]
    m = flexmock{|mk| mk.should_receive(:tool_shown).never.with(@widgets[0])}
    @ws.connect(SIGNAL('tool_shown(QWidget*)')){|w| m.tool_shown w}
    @ws.raise_tool @widgets[0]
  end
  
  it 'should call the resize_tool method' do
    @widgets[0].parent.current_widget = @widgets[1]
    flexmock(@ws).should_receive(:resize_tool).once.with(@widgets[0])
    @ws.raise_tool @widgets[0]
  end
  
  it 'should work when passing the widget\'s object name instead of the widget itself' do
    @widgets[1].object_name = 'tool 2'
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should == @widgets[0]
    @ws.raise_tool 'tool 2'
    stack.current_widget.should == @widgets[1]
  end

  it 'should work when passing the widget\'s object name as a symbol instead of the widget itself' do
    @widgets[1].object_name = 'tool2'
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should == @widgets[0]
    @ws.raise_tool :tool2
    stack.current_widget.should == @widgets[1]
  end
  
  it 'should do nothing if the argument isn\'t a valid tool widget' do
    @ws.raise_tool @widgets[0]
    lambda{@ws.raise_tool Qt::Widget.new}.should_not raise_error
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should equal(@widgets[0])
    lambda{@ws.raise_tool 'xyz'}.should_not raise_error
    stack.current_widget.should equal(@widgets[0])
  end
  
  it 'should store the size of the previously current tool widget, if it was visible' do
    @ws.raise_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(@ws).should_receive(:store_tool_size).with(@widgets[0]).once
    @ws.raise_tool @widgets[1]
  end
  
  it 'should not store the size of the previously current tool widget, if it wasn\'t visible' do
    @ws.raise_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:store_tool_size).with(@widgets[0]).never
    @ws.raise_tool @widgets[1]
  end
  
  it 'should not attempt to store the size of the previously current tool widget if there was none' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    flexmock(stack).should_receive(:current_widget).and_return nil
    flexmock(@ws).should_receive(:store_tool_size).never
    @ws.raise_tool @widgets[1]
  end
  
  
end

describe 'Ruber::Workspace#show_tool' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::Label.new, Qt::TextEdit.new]
    pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    @ws.add_tool_widget :bottom, @widgets[0], pix, 'Tool1'
    @ws.add_tool_widget :bottom, @widgets[1], pix, 'Tool2'
    @data = @ws.instance_variable_get :@widgets
  end
  
  it 'should raise the given tool, unless it\'s already raised' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should equal(@widgets[0])
    flexmock(@ws).should_receive(:raise_tool).with(@widgets[1]).once
    @ws.show_tool @widgets[1]
  end
  
  it 'should show the stack where the tool widget is, if it isn\'t already visible' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.should be_hidden
    flexmock(stack).should_receive(:show).once
    @ws.show_tool @widgets[1]
  end
  
  it 'should not show the stack where the tool widget is if it\'s already visible' do
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.visible = true
    flexmock(stack).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:show).never
    @ws.show_tool @widgets[1]
  end
  
  it 'should emit the tool_shown(QWidget*) signal if the widget was previously hidden' do
    flexmock(@widgets[1]).should_receive(:visible?).and_return false
    m = flexmock{|mk| mk.should_receive(:tool_shown).once.with(@widgets[1])}
    @ws.connect(SIGNAL('tool_shown(QWidget*)')){|w| m.tool_shown w}
    @ws.show_tool @widgets[1]
  end
  
  it 'should not emit the tool_shown(QWidget*) signal if the widget was already visible' do
    flexmock(@widgets[1]).should_receive(:visible?).and_return true
    m = flexmock{|mk| mk.should_receive(:tool_shown).never.with(@widgets[1])}
    @ws.connect(SIGNAL('tool_shown(QWidget*)')){|w| m.tool_shown w}
    @ws.show_tool @widgets[1]
  end
  
  it 'should give focus to the tool widget if the previously current widget of its stack had focus' do
    @ws.show_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:has_focus).and_return true
    flexmock(@widgets[1]).should_receive(:has_focus).and_return false
    flexmock(@widgets[1]).should_receive(:set_focus).once
    @ws.show_tool @widgets[1]
  end

  it 'should not give focus to the tool widget if the previously current widget of its stack didn\'t have focus' do
    @ws.show_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:has_focus).and_return false
    flexmock(@widgets[1]).should_receive(:has_focus).and_return false
    flexmock(@widgets[1]).should_receive(:set_focus).never
    @ws.show_tool @widgets[1]
  end

  it 'should work when passing the widget\'s object name instead of the widget itself' do
    @widgets[1].object_name = 'tool 2'
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should == @widgets[0]
    @ws.show_tool 'tool 2'
    stack.current_widget.should == @widgets[1]
  end

  it 'should work when passing the widget\'s object name as a symbol instead of the widget itself' do
    @widgets[1].object_name = 'tool2'
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should == @widgets[0]
    @ws.show_tool :tool2
    stack.current_widget.should == @widgets[1]
  end
  
  it 'should do nothing if the argument isn\'t a valid tool widget' do
    @ws.raise_tool @widgets[0]
    lambda{@ws.show_tool Qt::Widget.new}.should_not raise_error
    stack = @ws.instance_variable_get(:@stacks)[:bottom]
    stack.current_widget.should equal(@widgets[0])
    lambda{@ws.show_tool 'xyz'}.should_not raise_error
    stack.current_widget.should equal(@widgets[0])
  end
    
end

describe 'Ruber::Workspace#activate_tool' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::Label.new, Qt::TextEdit.new]
    pix = KDE::IconLoader.global.load_icon('document-new', KDE::IconLoader::Toolbar)
    @ws.add_tool_widget :bottom, @widgets[0], pix, 'Tool1'
    @ws.add_tool_widget :bottom, @widgets[1], pix, 'Tool2'
    @data = @ws.instance_variable_get :@widgets
  end
  
  it 'should call the show_tool method if the tool is not visible' do
    @widgets[0].should_not be_visible
    flexmock(@ws).should_receive(:show_tool).with(@widgets[0]).once
    @ws.activate_tool @widgets[0]
  end
  
  it 'should not call the show_tool method if the tool is already visible' do
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(@ws).should_receive(:show_tool).with(@widgets[0]).never
    @ws.activate_tool @widgets[0]
  end
  
  it 'should give focus to the tool widget' do
    flexmock(@widgets[0]).should_receive(:set_focus).once
    @ws.activate_tool @widgets[0]
  end
  
  it 'should work when passing the widget\'s object name instead of the widget itself' do
    @widgets[1].object_name = 'tool2'
    flexmock(@widgets[1]).should_receive(:set_focus).once
    @ws.activate_tool 'tool2'
  end

  it 'should work when passing the widget\'s object name as a symbol instead of the widget itself' do
    @widgets[1].object_name = 'tool2'
    flexmock(@widgets[1]).should_receive(:set_focus).once
    @ws.activate_tool :tool2
  end
  
  it 'should do nothing if the argument isn\'t a valid tool widget' do
    @ws.raise_tool @widgets[0]
    lambda{@ws.activate_tool Qt::Widget.new}.should_not raise_error
    lambda{@ws.activate_tool 'xyz'}.should_not raise_error
  end

end

describe 'Ruber::Workspace#hide_tool' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    @mw = flexmock{|m| m.should_receive(:focus_on_editor).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    flexmock(Ruber).should_receive(:[]).with(:main_window).and_return(@mw).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::LineEdit.new, Qt::GraphicsView.new]
    @ws.add_tool_widget :left, @widgets[0], Qt::Pixmap.new, 'Tool1'
    @ws.add_tool_widget :left, @widgets[1], Qt::Pixmap.new, 'Tool2'
  end
  
  it 'should store the size of the tool if it is visible' do
    @ws.show_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(@ws).should_receive(:store_tool_size).with(@widgets[0]).once
    @ws.hide_tool @widgets[0]
  end
  
  it 'should not store the size of the tool if it isn\'t visible' do
    @ws.show_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:store_tool_size).with(@widgets[0]).never
    @ws.hide_tool @widgets[0]
  end
  
  it 'should deactivate the tab corresponding to the raised tool, if the tool is raised' do
    @ws.show_tool @widgets[0]
    bar = @ws.instance_variable_get(:@button_bars)[:left]
    stack = @widgets[0].parent
    id = @ws.instance_variable_get(:@widgets)[@widgets[0]].id
    flexmock(stack).should_receive(:current_widget).and_return @widgets[0]
    flexmock(bar).should_receive(:set_tab).with(id, false).once
    @ws.hide_tool @widgets[0]
  end
  
  it 'shouldn\'t deactivate the tab corresponding to the raised tool, if the tool is not raised' do
    @ws.show_tool @widgets[1]
    bar = @ws.instance_variable_get(:@button_bars)[:left]
    stack = @widgets[0].parent
    id = @ws.instance_variable_get(:@widgets)[@widgets[0]].id
    flexmock(stack).should_receive(:current_widget).and_return @widgets[1]
    flexmock(bar).should_receive(:set_tab).with(id, false).never
    @ws.hide_tool @widgets[0]
  end
  
  it 'should hide the tool\'s stack if it is visible and the tool is raised' do
    @ws.show_tool @widgets[0]
    stack = @widgets[0].parent
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:hide).once
    @ws.hide_tool @widgets[0]
  end
  
  it 'should not hide the tool\'s stack if the tool isn\'t raised' do
    @ws.show_tool @widgets[1]
    stack = @widgets[0].parent
    flexmock(@widgets[0]).should_receive(:visible?).and_return false
    flexmock(stack).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:hide).never
    @ws.hide_tool @widgets[0]
  end
  
  it 'should give focus to the active editor if the stack becomes hidden' do
    @ws.show_tool @widgets[0]
    stack = @widgets[0].parent
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:visible?).and_return true
    @mw.should_receive(:focus_on_editor).once
    @ws.hide_tool @widgets[0]
  end
  
  it 'should not hide the tool\'s stack if it is already hidden' do
    @ws.show_tool @widgets[0]
    stack = @widgets[0].parent
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:visible?).and_return false
    flexmock(stack).should_receive(:hide).never
    @ws.hide_tool @widgets[0]
  end
  
  it 'should give focus to the active editor if the stack doesn\'t become hidden' do
    @ws.show_tool @widgets[0]
    stack = @widgets[0].parent
    flexmock(@widgets[0]).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:visible?).and_return false
    @mw.should_receive(:focus_on_editor).never
    @ws.hide_tool @widgets[0]
  end

  
  it 'should work when passing the widget\'s object name instead of the widget itself' do
    @ws.raise_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return(:true)
    stack = @widgets[0].parent
    flexmock(stack).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:hide).once
    @widgets[0].object_name = 'tool1'
    @ws.hide_tool 'tool1'
  end
  
  it 'should work when passing the widget\'s object name as a symbol instead of the widget itself' do
    @ws.raise_tool @widgets[0]
    flexmock(@widgets[0]).should_receive(:visible?).and_return(:true)
    stack = @widgets[0].parent
    flexmock(stack).should_receive(:visible?).and_return true
    flexmock(stack).should_receive(:hide).once
    @widgets[0].object_name = 'tool1'
    @ws.hide_tool :tool1
  end

  
  it 'should do nothing if the argument isn\'t a valid tool widget' do
    @ws.raise_tool @widgets[0]
    lambda{@ws.hide_tool Qt::Widget.new}.should_not raise_error
    lambda{@ws.hide_tool 'xyz'}.should_not raise_error
  end

  
end

describe 'Ruber::Workspace#toggle_tool' do

  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::LineEdit.new, Qt::GraphicsView.new]
    @ws.add_tool_widget :left, @widgets[0], Qt::Pixmap.new, 'Tool1'
    @ws.add_tool_widget :left, @widgets[1], Qt::Pixmap.new, 'Tool2'
  end
  
  it 'should activate the tool if it is not visible' do
    flexmock(@widgets[1]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:activate_tool).once.with(@widgets[1])
    @ws.toggle_tool @widgets[1]
  end
  
  it 'should hide the tool\'s stack if the tool is visible' do
    flexmock(@widgets[1]).should_receive(:visible?).and_return true
    flexmock(@ws).should_receive(:hide_tool).once
    @ws.toggle_tool @widgets[1]
  end
  
  it 'should work if the argument is the id of the tab associated with the tool' do
    id = @ws.instance_variable_get(:@widgets)[@widgets[1]].id
    flexmock(@widgets[1]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:activate_tool).once.with(@widgets[1])
    @ws.toggle_tool id
  end
  
  it 'should work if the argument is the object_name of the widget as a string' do
    @widgets[1].object_name = 'tool2'
    id = @ws.instance_variable_get(:@widgets)[@widgets[1]].id
    flexmock(@widgets[1]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:activate_tool).once.with(@widgets[1])
    @ws.toggle_tool 'tool2'
  end
  
  it 'should work if the argument is the object_name of the widget as a string' do
    @widgets[1].object_name = 'tool2'
    id = @ws.instance_variable_get(:@widgets)[@widgets[1]].id
    flexmock(@widgets[1]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:activate_tool).once.with(@widgets[1])
    @ws.toggle_tool :tool2
  end
  
  it 'should do nothing if the argument is not a valid tool widget' do
    id = @ws.instance_variable_get(:@widgets)[@widgets[1]].id
    flexmock(@widgets[1]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:activate_tool).with(@widgets[1]).never
    lambda{@ws.toggle_tool Qt::Widget.new}.should_not raise_error
    lambda{@ws.toggle_tool 'xyz'}.should_not raise_error
    lambda{@ws.toggle_tool :xyz}.should_not raise_error
    lambda{@ws.toggle_tool -7}.should_not raise_error
  end

end

describe 'Ruber::Workspace, when a tool widget tab is clicked' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::LineEdit.new, Qt::GraphicsView.new]
    @ws.add_tool_widget :left, @widgets[0], Qt::Pixmap.new, 'Tool1'
    @ws.add_tool_widget :left, @widgets[1], Qt::Pixmap.new, 'Tool2'
  end
  
  it 'should toggle the tool widget corresponding to the tab' do
    id = @ws.instance_variable_get(:@widgets)[@widgets[1]].id
    flexmock(@ws).should_receive(:toggle_tool).once.with(id)
    bar = @ws.instance_variable_get(:@button_bars)[:left]
    bar.tab(id).instance_eval{emit clicked(id)}
  end
    
end

describe 'Ruber::Workspace#resize_tool' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = {:left => Qt::LineEdit.new, :right => Qt::GraphicsView.new, :bottom => Qt::TextEdit.new}
    @widgets.each_pair do |side, w|
      @ws.add_tool_widget side, w, Qt::Pixmap.new, "Tool #{side}"
    end
    @sizes = {'Tool left' => 40, 'Tool right' => 37, 'Tool bottom' => 82}
    @ws.instance_variable_set :@sizes, @sizes
  end
  
  it 'should resize the splitter so that the size corresponding to the tool is the one stored under its caption if the tool is on the bottom' do
    splitter = @ws.instance_variable_get(:@splitters)[:vertical]
    flexmock(splitter).should_receive(:sizes).and_return([100, 30])
    flexmock(splitter).should_receive(:sizes=).with([48, 82]).once
    @ws.send :resize_tool, @widgets[:bottom]
  end
  
  it 'should resize the splitter so that the size corresponding to the tool is the one stored under its caption if the tool is on the left' do
    splitter = @ws.instance_variable_get(:@splitters)[:horizontal]
    flexmock(splitter).should_receive(:sizes).and_return([70, 100, 30])
    flexmock(splitter).should_receive(:sizes=).with([40, 130, 30]).once
    @ws.send :resize_tool, @widgets[:left]
  end
  
  it 'should resize the splitter so that the size corresponding to the tool is the one stored under its caption if the tool is on the right' do
    splitter = @ws.instance_variable_get(:@splitters)[:horizontal]
    flexmock(splitter).should_receive(:sizes).and_return([70, 100, 30])
    flexmock(splitter).should_receive(:sizes=).with([70, 93, 37]).once
    @ws.send :resize_tool, @widgets[:right]
  end
  
  it 'should resize the widget to 150 if there isn\'t an entry for the widget' do
    @sizes.delete 'Tool right'
    splitter = @ws.instance_variable_get(:@splitters)[:horizontal]
    flexmock(splitter).should_receive(:sizes).and_return([70, 300, 30])
    flexmock(splitter).should_receive(:sizes=).with([70, 180, 150]).once
    @ws.send :resize_tool, @widgets[:right]
  end
  
end

describe 'Ruber::Workspace#store_tool_size' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = {:left => Qt::LineEdit.new, :right => Qt::GraphicsView.new, :bottom => Qt::TextEdit.new}
    @widgets.each_pair do |side, w|
      @ws.add_tool_widget side, w, Qt::Pixmap.new, "Tool #{side}"
    end
  end
  
  it 'should store the size of the widget in the @sizes instance variable, using the widget\'s caption as key when the tool is at the bottom' do
    splitter = @ws.instance_variable_get(:@splitters)[:vertical]
    flexmock(splitter).should_receive(:sizes).and_return [100,20]
    @ws.send :store_tool_size, @widgets[:bottom]
    @ws.instance_variable_get(:@sizes)['Tool bottom'].should == 20
  end
  
  it 'should store the size of the widget in the @sizes instance variable, using the widget\'s caption as key when the tool is on the left' do
    splitter = @ws.instance_variable_get(:@splitters)[:horizontal]
    flexmock(splitter).should_receive(:sizes).and_return [30,100,20]
    @ws.send :store_tool_size, @widgets[:left]
    @ws.instance_variable_get(:@sizes)['Tool left'].should == 30
  end
  
  it 'should store the size of the widget in the @sizes instance variable, using the widget\'s caption as key when the tool is on the right' do
    splitter = @ws.instance_variable_get(:@splitters)[:horizontal]
    flexmock(splitter).should_receive(:sizes).and_return [30,100,20]
    @ws.send :store_tool_size, @widgets[:right]
    @ws.instance_variable_get(:@sizes)['Tool right'].should == 20
  end
  
end

describe 'Ruber::Workspace#store_sizes' do
  
  before do
    @config = flexmock do |m| 
      m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default
      m.should_receive(:[]=).by_default
    end
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = {:left => Qt::LineEdit.new, :right => Qt::GraphicsView.new, :bottom => Qt::TextEdit.new}
    @widgets.each_pair do |side, w|
      @ws.add_tool_widget side, w, Qt::Pixmap.new, "Tool #{side}"
    end
  end
  
  it 'should call the store_tool_size method for each visible tool widget' do
    w = Qt::Widget.new
    @ws.add_tool_widget :bottom, w, Qt::Pixmap.new, "New tool"
    flexmock(w).should_receive(:visible?).and_return false
    flexmock(@widgets[:bottom]).should_receive(:visible?).and_return true
    flexmock(@widgets[:right]).should_receive(:visible?).and_return true
    flexmock(@widgets[:left]).should_receive(:visible?).and_return false
    flexmock(@ws).should_receive(:store_tool_size).once.with @widgets[:bottom]
    flexmock(@ws).should_receive(:store_tool_size).once.with @widgets[:right]
    @ws.store_sizes
  end
  
  it 'should store the sizes in the configuration widget in the workspace group under the tools_sizes entry' do
    flexmock(@widgets[:bottom]).should_receive(:visible?).and_return true
    flexmock(@widgets[:right]).should_receive(:visible?).and_return false
    flexmock(@widgets[:left]).should_receive(:visible?).and_return false
    @ws.instance_variable_set :@sizes, {'Tool left' => 90, 'Tool right' => 10, 'Tool bottom' => 60}
    splitter = @ws.instance_variable_get(:@splitters)[:vertical]
    flexmock(splitter).should_receive(:sizes).and_return [100, 89]
    @config.should_receive(:[]=).once.with(:workspace, :tools_sizes, {'Tool left' => 90, 'Tool right' => 10, 'Tool bottom' => 89})
    @ws.store_sizes
  end
  
end

describe 'Ruber::Workspace#tool_widgets' do
  
  before do
    @config = flexmock do |m| 
      m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default
      m.should_receive(:[]=).by_default
    end
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = {:left => Qt::LineEdit.new, :right => Qt::GraphicsView.new, :bottom => Qt::TextEdit.new}
    @widgets.each_pair do |side, w|
      @ws.add_tool_widget side, w, Qt::Pixmap.new, "Tool #{side}"
    end
  end
  
  it 'should return a hash containing all the tool widgets amd their positions' do
    @ws.tool_widgets.should == @widgets.invert
  end
  
end

describe 'Ruber::Workspace#active_tool' do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::LineEdit.new, Qt::TextEdit.new, Qt::CheckBox.new, Qt::Widget.new]
    w = @widgets[-1]
    @inner = [Qt::ListView.new(w), Qt::TreeWidget.new(w)]
    sides = [:left, :right, :bottom, :bottom]
    @widgets.each_with_index do |tool, i|
      @ws.add_tool_widget sides[i], tool, Qt::Pixmap.new, "Tool #{i}"
    end
  end
  
  it 'should return the application\'s focus widget, if it is a tool widget' do
    flexmock(KDE::Application).should_receive(:focus_widget).once.and_return(@widgets[1])
    @ws.active_tool.should equal(@widgets[1])
  end
  
  it 'should return the tool widget which contains the application\'s focus widget, if it is a child of a tool widget' do
    flexmock(KDE::Application).should_receive(:focus_widget).once.and_return(@inner[0])
    @ws.active_tool.should equal(@widgets[-1])
  end
  
  it 'should return nil if the application\'s focus widget is nil' do
    flexmock(KDE::Application).should_receive(:focus_widget).once.and_return nil
    @ws.active_tool.should be_nil
  end
  
  it 'should return nil if the application\'s focus widget is not one of tool widgets nor one of their children' do
    w = Qt::Widget.new
    flexmock(KDE::Application).should_receive(:focus_widget).once.and_return(w)
    @ws.active_tool.should be_nil
  end
  
end

describe Ruber::Workspace do
  
  before do
    @config = flexmock{|m| m.should_receive(:[]).with(:workspace, :tools_sizes).and_return({}).by_default}
    flexmock(Ruber).should_receive(:[]).with(:config).and_return(@config).by_default
    @ws = Ruber::Workspace.new
    @widgets = [Qt::LineEdit.new, Qt::TextEdit.new, Qt::CheckBox.new, Qt::Widget.new]
    w = @widgets[-1]
    @sides = [:left, :right, :bottom, :bottom]
  end
  
  describe '#current_widget' do
    
    it 'returns the current widget on the left side if the argument is left' do
      @sides = [:left, :right, :left, :bottom]
      @widgets.each_with_index do |tool, i|
        @ws.add_tool_widget @sides[i], tool, Qt::Pixmap.new, "Tool #{i}"
      end
      @ws.instance_variable_get(:@stacks)[:left].current_widget = @widgets[2]
      @ws.current_widget(:left).should equal(@widgets[2])
    end
    
    it 'returnd the current widget on the right side if the argument is right' do
      @sides = [:left, :right, :right, :bottom]
      @widgets.each_with_index do |tool, i|
        @ws.add_tool_widget @sides[i], tool, Qt::Pixmap.new, "Tool #{i}"
      end
      @ws.instance_variable_get(:@stacks)[:right].current_widget = @widgets[2]
      @ws.current_widget(:right).should equal(@widgets[2])
    end

    it 'returns the current widget on the bottom side if the argument is bottom' do
      @sides = [:left, :right, :bottom, :bottom]      
      @widgets.each_with_index do |tool, i|
        @ws.add_tool_widget @sides[i], tool, Qt::Pixmap.new, "Tool #{i}"
      end
      @ws.instance_variable_get(:@stacks)[:bottom].current_widget = @widgets[3]
      @ws.current_widget(:bottom).should equal(@widgets[3])
    end

    it 'returns nil if there is no widget on the given side' do
      @ws.instance_variable_get(:@widgets).should be_empty
      @ws.current_widget(:right).should be_nil
      @ws.current_widget(:left).should be_nil
      @ws.current_widget(:bottom).should be_nil
    end
    
  end
   
end