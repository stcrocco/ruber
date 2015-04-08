require 'spec/framework'
require './spec/common'

require 'tempfile'
require 'fileutils'
require 'flexmock/argument_types'
require 'facets/string/camelcase'

require 'ruber/editor/editor_view'
require 'ruber/editor/document'

describe Ruber::EditorView do
  
  def self.test_auto_signal s, signal_args = [], pending_info = nil
    signal_args = [signal_args] unless signal_args.is_a? Array
    sig = s.sub('@', 'QWidget*')
    s_args = s.match(/\((.*)\)/)[0].split(/\s*,\s*/)
    s_args.map! do |a|
      case a
      when 'QString' then String
      when 'QList' then Array
      when 'QHash' then Hash
      when /^Q/ then Qt.const_get(a[1..-1])
      when /^KTextEditor/ then KTextEditor.const_get(a.sub(/^KTextEditor::/,''))
      when /u?int/ then Integer
      when 'double' then Double
      else nil
      end
    end
    has_view_arg = s.match(/@/)
    o_sig = s.camelcase(false).sub(/\((.*?)(?:,\s+)?(@)\)/) do |s|
      res = '('
      res += 'KTextEditor::View*' + (!$1.empty? ? ', ' : '') if $2
      res += ($1 || '')+')'
      res
    end
    it "emits the \"#{sig}\" signal in response to the underlying KTextEditor::View #{o_sig} signal" do
      prc = lambda do 
        mock = flexmock('mock')
        if has_view_arg
          mock.should_receive(:test).once.with(@view.object_id) 
        else mock.should_receive(:test).once.with_no_args
        end
        signal_args.unshift 'self' if has_view_arg
        @view.connect(SIGNAL(sig)) do |*args|
          v = args.pop if has_view_arg
          s_args.each_with_index do |a, i|
            args[i].should be_kind_of a if a 
          end
          has_view_arg ? mock.test(@view.object_id) : mock.test
        end
        v = @view.instance_variable_get :@view
        code = "b = binding; emit #{o_sig[/[^(]*/]}(#{signal_args.map{|a| "eval( '#{a}', b)"}.join(',')})"
        v.instance_eval code
      end
      if pending_info and pending_info[:no_block]
        pending pending_info[:msg]
        prc.call
      elsif pending_info
        pending(pending_info[:msg]){prc.call}
      else prc.call
      end
    end
  end

  before do
#     @app = KDE::Application.instance
#     @w = Qt::Widget.new
#     @comp = Qt::Object.new
#     flexmock(@comp).should_receive(:each_component)
#     flexmock(Ruber).should_receive(:[]).with(:components).and_return @comp
    @parent = Qt::Widget.new
    @doc = Ruber::Document.new Ruber[:world]
    @view = @doc.create_view @parent 
  end
  
  after do
    @view.disconnect
  end
  
  describe 'when created' do
    
    it 'has the Qt::WA_DeleteOnClose attribute' do
      @view.test_attribute(Qt::WA_DeleteOnClose).should be_true
    end
    
  end

  test_auto_signal 'context_menu_about_to_show(QMenu*, @)', 'Qt::Menu.new'
  test_auto_signal 'focus_in(@)'
  test_auto_signal 'focus_out(@)'
  test_auto_signal 'horizontal_scroll_position_changed(@)'
  test_auto_signal 'information_message(QString, @)', '"test_string"' 
  test_auto_signal 'cursor_position_changed(KTextEditor::Cursor, @)', 'KTextEditor::Cursor.new()'
  test_auto_signal 'mouse_position_changed(KTextEditor::Cursor, @)', 'KTextEditor::Cursor.new()'
  test_auto_signal 'selection_changed(@)'
  test_auto_signal 'text_inserted(KTextEditor::Cursor, QString, @)', ['KTextEditor::Cursor.new(0,0)', '"test text"']
  test_auto_signal 'vertical_scroll_position_changed(KTextEditor::Cursor, @)', 'KTextEditor::Cursor.new()'
    
  it "emits the \"selection_mode_changed(bool, QWidget*)\" signal when the selection mode changes" do
    mock = flexmock('mock')
    mock.should_receive(:block_mode_on).globally.ordered.once.with(@view.object_id)
    mock.should_receive(:block_mode_off).globally.ordered.once.with(@view.object_id)
    @view.connect(SIGNAL('selection_mode_changed(bool, QWidget*)')) do |m, v|
      mock.send( (m ? :block_mode_on : :block_mode_off), v.object_id)
    end
    @view.block_selection = true
    @view.block_selection = false
  end

  it "emits the \"edit_mode_changed(KTextEditor::View::EditoMode, QWidget*)\" signal in response to the underlying KTextEditor::View viewEditModeChanged(KTextEditor::View, KTextEditor::View::EditMode) signal" do
    mock = flexmock('mock')
    mock.should_receive(:test).globally.ordered.once.with(1, @view.object_id)
    mock.should_receive(:test).globally.ordered.once.with(0, @view.object_id)
    @view.connect(SIGNAL('edit_mode_changed(KTextEditor::View::EditMode, QWidget*)')) do |m, v|
      mock.test m, v.object_id
    end
    v = @view.instance_variable_get(:@view)
    v.instance_eval{emit viewEditModeChanged(self, KTextEditor::View::EditOverwrite)}
    v.instance_eval{emit viewEditModeChanged(self, KTextEditor::View::EditInsert)}
  end

  it "emits the \"view_mode_changed(QString, QWidget*)\" signal in response to the underlying KTextEditor::View viewModeChanged(KTextEditor::View*) signal" do
    mock = flexmock('mock')
    mock.should_receive(:test).once.with("INS", @view.object_id)
    @view.connect(SIGNAL('view_mode_changed(QString, QWidget*)')) do |m, v|
      mock.test m, v.object_id
    end
    v = @view.instance_variable_get(:@view)
    v.instance_eval{emit viewModeChanged(self)}
  end
  
  describe '#internal' do
    
    it 'returns the underlying KTextEditor::View object' do
      @view.send(:internal).should be_a(KTextEditor::View)
    end
    
  end
  
  describe '#close' do
    
    it 'emits the closing(QWidget*) signal passing self as argument when the close method is called' do
      mock = flexmock('mock')
      mock.should_receive(:test).once.with(@view)
      @view.connect(SIGNAL('closing(QWidget*)')) do |v|
        mock.test v
      end
      @view.close
    end
    
  end
  
  describe '#move_cursor_by' do
    
    before do
      @doc.text = 20.times.map{'x'*20}.join("\n")
      @view.go_to 10, 8
    end
    
    it 'moves the cursor by the specified amount from the current position' do
      exp = KTextEditor::Cursor.new 14, 9
      @view.move_cursor_by 4, 1
      res = @view.cursor_position
      res.line.should == exp.line
      res.column.should == exp.column
    end
    
    it 'moves the cursor upwards if the row argument is negative' do
      exp = KTextEditor::Cursor.new 6, 9
      @view.move_cursor_by -4, 1
      res = @view.cursor_position
      res.line.should == exp.line
      res.column.should == exp.column
    end
    
    it 'moves the cursor to the left if the column argument is negative' do
      exp = KTextEditor::Cursor.new 14, 5
      @view.move_cursor_by 4, -3
      res = @view.cursor_position
      res.line.should == exp.line
      res.column.should == exp.column
    end
    
    it 'doesn\'t move the cursor and returns false if the new cursor position is out of range' do
      exp = KTextEditor::Cursor.new 10, 8
      @view.move_cursor_by(100, -300).should be_false
      res = @view.cursor_position
      res.line.should == exp.line
      res.column.should == exp.column
    end

  end

end

describe 'Ruber::EditorView#execute_action' do
  
  before do
    @parent = Qt::Widget.new
    @doc = Ruber::Document.new Ruber[:world]
    @view = @doc.create_view @parent
  end
  
  it 'should make the action emit the "triggered()" signal' do
    a = @view.action_collection.action 'edit_select_all'
    mk = flexmock('test'){|m| m.should_receive(:triggered).once}
    a.connect(SIGNAL(:triggered)){mk.triggered}
    @view.execute_action 'edit_select_all'
  end
  
  it 'should make the action emit the "toggled(bool)" signal if it is a KDE::ToggleAction' do
    a = @view.action_collection.action 'view_vi_input_mode'
    mk = flexmock('test'){|m| m.should_receive(:toggled).once.with true}
    a.connect(SIGNAL('toggled(bool)')){|b| mk.toggled b}
    @view.execute_action 'view_vi_input_mode', true
  end
  
  it 'should return true if the action is found' do
    @view.execute_action('edit_select_all').should be_true
  end
  
  it 'should do nothing and return false if the action doesn\'t exist' do
    lambda{@view.execute_action( 'inexistant_action').should be_false}.should_not raise_error
  end
  
end