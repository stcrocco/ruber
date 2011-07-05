require 'spec/framework'
require 'spec/common'

require 'tempfile'

require 'plugins/syntax_checker/syntax_checker'

describe Ruber::SyntaxChecker::Plugin do
  
  before do
    Ruber[:world].close_all :documents, :discard
    Ruber[:components].load_plugin 'plugins/syntax_checker/'
    @plug = Ruber[:syntax_checker]
  end

  after do
    Ruber[:components].unload_plugin :syntax_checker
    led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
    led.delete_later
    Qt::Application.send_posted_events led, Qt::Event::DeferredDelete
  end
  
  it 'inherits Ruber::Plugin' do
    Ruber::SyntaxChecker::Plugin.ancestors.should include(Ruber::Plugin)
  end
  
  context 'when created' do
    
    it 'has no registered syntax checkers' do
      @plug.instance_variable_get(:@syntax_checkers).should == {}
    end
    
    it 'inserts a KDE::Led in the status bar' do
      Ruber[:main_window].status_bar.find_children(KDE::Led).should_not be_empty
    end
    
    it 'sets the current status to :unknown' do
      @plug.current_status.should == :unknown
    end
    
  end
  
  context 'when unloaded' do
    
    it 'removes the led from the status bar' do
      led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
      led_id = led.object_id
      flexmock(Ruber[:main_window].status_bar).should_receive(:remove_widget).with(FlexMock.on{|arg| arg.object_id == led_id}).once
      #The plugin will be unloaded in the after block
    end
    
  end

  describe '#set_current_status' do
    
    context 'if the first argument is :correct' do
      
      it 'sets the current_errors attribute to nil' do
        @plug.instance_variable_set :@current_errors, []
        @plug.set_current_status :correct
        @plug.current_errors.should be_nil
      end
      
      it 'sets the led to the color contained in the COLORS hash under the :correct key' do
        led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
        led.color = Qt::Color.new Qt.black
        @plug.set_current_status :correct
        led.color.should == Ruber::SyntaxChecker::Plugin::COLORS[:correct]
      end
      
      it 'sets the tooltip of the led to "No syntax errors"' do
        led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
        @plug.set_current_status :correct
        led.tool_tip.should == "No syntax errors"
      end
      
      it 'sets the current_status attribute to :correct' do
        @plug.set_current_status :correct
        @plug.current_status.should == :correct
      end
    
    end
    
    context 'if the first argument is :unknown' do
      
      it 'sets the current_errors attribute to nil' do
        @plug.instance_variable_set :@current_errors, []
        @plug.set_current_status :unknown
        @plug.current_errors.should be_nil
      end
      
      it 'sets the led to the color contained in the COLORS hash under the :unknown key' do
        led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
        led.color = Qt::Color.new Qt.black
        @plug.set_current_status :unknown
        led.color.should == Ruber::SyntaxChecker::Plugin::COLORS[:unknown]
      end
      
      it 'sets the tooltip of the led to "Unknown document type"' do
        led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
        @plug.set_current_status :unknown
        led.tool_tip.should == "Unknown document type"
      end
      
      it 'sets the current_status attribute to :unknown' do
        @plug.set_current_status :unknown
        @plug.current_status.should == :unknown
      end
    
    end
    
    context 'if the first argument is :incorrect' do
      
      before do
        @errors = [
          Ruber::SyntaxChecker::SyntaxError.new(15, 2, 'xyz', 'XYZ'),
          Ruber::SyntaxChecker::SyntaxError.new(15, 0, 'abc', 'ABC'),
        ]
      end
      
      context 'and the second argument is an array with at least one element' do

        it 'stores the contents of the second argument in the current_errors attribute' do
          @plug.set_current_status :incorrect, @errors
          @plug.current_errors.should == @errors
          @plug.current_errors.should_not equal(@errors)
        end
      
        it 'sets the tooltip of the led to a list of the formatted_message for the errors given as second argument, preceded by lines and columns (increased by 1)' do
          led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
          @plug.set_current_status :incorrect, @errors
          led.tool_tip.should == "Line 16, column 3: XYZ\nLine 16, column 1: ABC"
        end
        
      end
      
      context 'and the second argument is an empty array' do
        
        it 'stores an empty array in the current_errors attribute' do
          @plug.set_current_status :incorrect, []
          @plug.current_errors.should == []
        end
        
        it 'sets the tooltip of the led to "There are syntax errors"' do
          led = Ruber[:main_window].status_bar.find_children(KDE::Led)[-1]
          @plug.set_current_status :incorrect, []
          led.tool_tip.should == "There are syntax errors"
        end
        
      end
      
      it 'sets the led to the color contained in the COLORS hash under the :incorrect key' do
        led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
        led.color = Qt::Color.new Qt.black
        @plug.set_current_status :incorrect, @errors
        led.color.should == Ruber::SyntaxChecker::Plugin::COLORS[:incorrect]
      end
            
      it 'sets the current_status attribute to :incorrect' do
        @plug.set_current_status :incorrect
        @plug.current_status.should == :incorrect
      end
      
    end
    
  end
  
  context 'when the user right-clicks on the led' do
    
    before do
      @led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
    end
   
    context 'if the current_status attribute is :correct' do
      
      it 'displays a menu with the entry "No syntax errors"' do
        @plug.set_current_status :correct
        actions_prc = Proc.new do |list|
          list.count == 1 && list[0].text == 'No syntax errors'
        end
        flexmock(Qt::Menu).should_receive(:exec).once.with(FlexMock.on(&actions_prc), Qt::Point)
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
      end
      
    end
    
    context 'if the current_status attribute is :unknown' do
      
      it 'doesn\'t display any menu' do
        @plug.set_current_status :unknown
        flexmock(Qt::Menu).should_receive(:exec).never
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
      end
      
    end
    
    context 'if the current_status attribute is :incorrect' do
      
      context 'and the current_errors attribute is empty' do
        
        it 'displays a menu with the entry "There are syntax errors"' do
          @plug.set_current_status :incorrect
          actions_prc = Proc.new do |list|
            list.count == 1 && list[0].text == 'There are syntax errors'
          end
          flexmock(Qt::Menu).should_receive(:exec).once.with(FlexMock.on(&actions_prc), Qt::Point)
          ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
          Qt::Application.send_event(@led, ev)
        end
        
      end
      
      context 'and the current_errors attribute is not empty' do
        
        before do
          @errors = [
            Ruber::SyntaxChecker::SyntaxError.new(15, 2, 'xyz', 'XYZ'),
            Ruber::SyntaxChecker::SyntaxError.new(15, nil, 'abc', 'ABC'),
          ]
          @plug.set_current_status :incorrect, @errors
        end
        
        it 'displays a menu with an entry for each error (increasing lines and columns by 1)' do
          exp_texts = ["Line 16, column 3: XYZ", "Line 16: ABC"]
          actions_prc = Proc.new{|list| list.map{|a| a.text} == exp_texts}
          flexmock(Qt::Menu).should_receive(:exec).once.with(FlexMock.on(&actions_prc), Qt::Point)
          ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
          Qt::Application.send_event(@led, ev)
        end
        
      end
      
    end
    
  end
  
  context 'when the user clicks on an entry in the context menu' do
    
    before do
      @led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
      @docs = Array.new(3){Ruber[:world].new_document}
      @views = @docs.map{|d| Ruber[:world].active_environment.editor_for! d}
      Ruber[:world].active_environment.activate_editor @views[0]
    end
    
    context 'and the current_errors attribute contains errors' do
      
      before do
        @errors = [
        Ruber::SyntaxChecker::SyntaxError.new(15, 2, 'xyz', 'XYZ'),
            Ruber::SyntaxChecker::SyntaxError.new(15, nil, 'abc', 'ABC'),
            Ruber::SyntaxChecker::SyntaxError.new(nil, nil, 'fgh', nil),
            ]
        @plug.set_current_status :incorrect, @errors
      end
      
      it 'moves the cursor of the current view to the line and column of the error corresponding to the chosen entry' do
        actions = @errors.map{|e| KDE::Action.new(e.format, nil)}
        actions.each do |a|
          flexmock(KDE::Action).should_receive(:new).once.and_return(a)
        end
        flexmock(Qt::Menu).should_receive(:exec).once.and_return(actions[0])
        flexmock(@views[0]).should_receive(:go_to).with(15, 2).once
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
      end
      
      it 'moves the cursor to column 0 of the appropriate line if the error doesn\'t specify a column number' do
        actions = @errors.map{|e| KDE::Action.new(e.format, nil)}
        actions.each do |a|
          flexmock(KDE::Action).should_receive(:new).once.and_return(a)
        end
        flexmock(Qt::Menu).should_receive(:exec).once.and_return(actions[1])
        flexmock(@views[0]).should_receive(:go_to).with(15, 0).once
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
      end
      
      it 'doesn\'t move the cursor if the error doesn\'t specify a line number' do
        actions = @errors.map{|e| KDE::Action.new(e.format, nil)}
        actions.each do |a|
          flexmock(KDE::Action).should_receive(:new).once.and_return(a)
        end
        flexmock(Qt::Menu).should_receive(:exec).once.and_return(actions[2])
        flexmock(@views[0]).should_receive(:go_to).never
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
      end
      
    end
    
    context 'and the current_errors attribute is nil or empty' do
      
      it 'does nothing' do
        action = KDE::Action.new 'Text', nil
        flexmock(KDE::Action).should_receive(:new).and_return(action)
        flexmock(Qt::Menu).should_receive(:exec).and_return(action)
        flexmock(@views[0]).should_receive(:go_to).never
        @plug.set_current_status :correct
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
        @plug.set_current_status :unknown
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
        @plug.set_current_status :incorrect
        ev = Qt::ContextMenuEvent.new Qt::ContextMenuEvent::Mouse, Qt::Point.new(0,0)
        Qt::Application.send_event(@led, ev)
      end
      
    end
    
  end
  
  context 'when the user clicks on the led' do
    
    before do
      @led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
      @docs = Array.new(3){Ruber[:world].new_document}
      @views = @docs.map{|d| Ruber[:world].active_environment.editor_for! d}
      Ruber[:world].active_environment.activate_editor @views[0]
    end
    
    context 'and the current_errors attribute contains errors' do
      
      before do
        @errors = [
        Ruber::SyntaxChecker::SyntaxError.new(15, 2, 'xyz', 'XYZ'),
            Ruber::SyntaxChecker::SyntaxError.new(15, nil, 'abc', 'ABC'),
            Ruber::SyntaxChecker::SyntaxError.new(nil, nil, 'fgh', nil),
            ]
        @plug.set_current_status :incorrect, @errors
      end
      
      it 'moves the cursor to the line and column associated with the first error' do
        flexmock(@views[0]).should_receive(:go_to).with(15, 2).once
        ev = Qt::MouseEvent.new Qt::Event::MouseButtonRelease, Qt::Point.new(0,0), Qt::LeftButton, Qt::NoButton, Qt::NoModifier
        Qt::Application.send_event(@led, ev)
      end
      
      it 'moves the cursor to column 0 of the appropriate line if the error doesn\'t specify a column number' do
        @errors[0].column = nil
        flexmock(@views[0]).should_receive(:go_to).with(15, 0).once
        ev = Qt::MouseEvent.new Qt::Event::MouseButtonRelease, Qt::Point.new(0,0), Qt::LeftButton, Qt::NoButton, Qt::NoModifier
        Qt::Application.send_event(@led, ev)
      end
      
      it 'does nothing if the first error doesn\'t specify a line number' do
        @errors[0].line = nil
        flexmock(@views[0]).should_receive(:go_to).never
        ev = Qt::MouseEvent.new Qt::Event::MouseButtonRelease, Qt::Point.new(0,0), Qt::LeftButton, Qt::NoButton, Qt::NoModifier
        Qt::Application.send_event(@led, ev)
      end
  
    end
    
    context 'and the current_errors attribute is nil or empty' do
      
      it 'does nothing' do
        flexmock(@views[0]).should_receive(:go_to).never
        @plug.set_current_status :correct
        ev = Qt::MouseEvent.new Qt::Event::MouseButtonRelease, Qt::Point.new(0,0), Qt::LeftButton, Qt::NoButton, Qt::NoModifier
        Qt::Application.send_event(@led, ev)
        @plug.set_current_status :unknown
        ev = Qt::MouseEvent.new Qt::Event::MouseButtonRelease, Qt::Point.new(0,0), Qt::LeftButton, Qt::NoButton, Qt::NoModifier
        Qt::Application.send_event(@led, ev)
        @plug.set_current_status :incorrect
        ev = Qt::MouseEvent.new Qt::Event::MouseButtonRelease, Qt::Point.new(0,0), Qt::LeftButton, Qt::NoButton, Qt::NoModifier
        Qt::Application.send_event(@led, ev)
      end
      
    end
    
  end
  
  describe '#register_syntax_checker' do

    before do
      @cls = Class.new
      @mimetypes = %w[application/x-ruby text/x-python]
      @patterns = %w[*.rb *.py]
    end

    it 'stores the given class with the associated rules' do
      @plug.register_syntax_checker @cls, @mimetypes, @patterns
      @plug.instance_variable_get(:@syntax_checkers)[@cls].should == [@mimetypes, @patterns]
    end
    
    it 'emits the syntax_checker_added signal' do
      mk = flexmock{|m| m.should_receive(:syntax_checker_added).once}
      @plug.connect(SIGNAL(:syntax_checker_added)){mk.syntax_checker_added}
      @plug.register_syntax_checker @cls, @mimetypes, @patterns
    end
    
    it 'raises ArgumentError if the given syntax checker has already been registered' do
      cls = Class.new
      mimetypes = %w[application/x-ruby]
      patterns = %w[*.rb]
      @plug.register_syntax_checker cls, mimetypes, patterns
      lambda{@plug.register_syntax_checker cls, ['text/plain']}.should raise_error(ArgumentError, "#{cls} has already been registered as syntax checker")
    end
    
  end
  
  describe '#syntax_checker_for' do
    
    context 'if a syntax checker for which the document\'s file_type_match? method returns true exists' do
      
      it 'returns the syntax checker class' do
        doc = Ruber[:world].new_document
        checkers = Array.new(2){Class.new}
        @plug.register_syntax_checker checkers[0], ['text/x-python']
        @plug.register_syntax_checker checkers[1], ['application/x-ruby']
        flexmock(doc).should_receive(:file_type_match?).with(['text/x-python'], []).and_return false
        flexmock(doc).should_receive(:file_type_match?).with(['application/x-ruby'], []).and_return true
        checker = @plug.syntax_checker_for doc
        checker.should == checkers[1]
      end
      
      it 'returns the first syntax checker with matches if there are more than one of them' do
        doc = Ruber[:world].new_document
        checkers = Array.new(2){Class.new}
        @plug.register_syntax_checker checkers[0], ['text/x-python']
        @plug.register_syntax_checker checkers[1], ['application/x-ruby']
        flexmock(doc).should_receive(:file_type_match?).with(['text/x-python'], []).and_return true
        flexmock(doc).should_receive(:file_type_match?).with(['application/x-ruby'], []).and_return true
        checker = @plug.syntax_checker_for doc
        checker.should == checkers[0]
      end
      
    end
    
    context 'if the document\'s file_type_match? method returns false for all syntax checkers' do
      
      it 'returns nil' do
        doc = Ruber[:world].new_document
        checkers = Array.new(2){Class.new}
        @plug.register_syntax_checker checkers[0], ['text/x-python']
        @plug.register_syntax_checker checkers[1], ['application/x-ruby']
        flexmock(doc).should_receive(:file_type_match?).with(['text/x-python'], []).and_return false
        flexmock(doc).should_receive(:file_type_match?).with(['application/x-ruby'], []).and_return false
        checker = @plug.syntax_checker_for doc
        checker.should be_nil
      end
      
    end
    
  end
  
  describe '#remove_syntax_checker' do
    
    before do
      @cls = Class.new
      @plug.register_syntax_checker @cls, ['application/x-ruby']
    end
    
    it 'removes the given syntax checker from the list' do
      @plug.remove_syntax_checker @cls
      @plug.instance_variable_get(:@syntax_checkers).should_not include(@cls)
    end
    
    it 'emits the syntax_checker_removed signal' do
      mk = flexmock{|m| m.should_receive(:syntax_checker_removed).once}
      @plug.connect(SIGNAL(:syntax_checker_removed)){mk.syntax_checker_removed}
      @plug.remove_syntax_checker @cls
    end
    
    it 'does nothing if the given syntax checker has not been registered' do
      cls = Class.new
      mk = flexmock{|m| m.should_receive(:syntax_checker_removed).never}
      @plug.connect(SIGNAL(:syntax_checker_removed)){mk.syntax_checker_removed}
      lambda{@plug.remove_syntax_checker cls}.should_not raise_error
    end
    
  end
  
  describe '#load_settings ' do
    
    it 'emits the :settings_changed signal' do
      mk = flexmock{|m| m.should_receive(:settings_changed).once}
      @plug.connect(SIGNAL(:settings_changed)){mk.settings_changed}
      @plug.load_settings
    end
    
  end
  
  context 'when the syntax checker extension complete a syntax check' do
    
    before do
      @doc = Ruber[:world].document __FILE__
      @ext = @doc.extension(:syntax_checker)
    end
    
    after do
      @doc.close false
    end
    
    it 'updates the current state accordingly if the extension is associated with the active document' do
      flexmock(@doc).should_receive(:active?).and_return true
      flexmock(@ext).should_receive(:status).and_return(:incorrect)
      errors = [Ruber::SyntaxChecker::SyntaxError.new(2, 5, 'X', 'x')]
      flexmock(@ext).should_receive(:errors).and_return errors
      flexmock(@plug).should_receive(:set_current_status).once.with(:incorrect, errors)
      @ext.instance_eval{emit syntax_checked(@doc)}
    end
    
    it 'does nothing if the extension is not associated with the active document' do
      flexmock(@doc).should_receive(:active?).and_return false
      flexmock(@ext).should_receive(:status).and_return(:incorrect)
      errors = [Ruber::SyntaxChecker::SyntaxError.new(2, 5, 'X', 'x')]
      flexmock(@ext).should_receive(:errors).and_return errors
      flexmock(@plug).should_receive(:set_current_status).never
      @ext.instance_eval{emit syntax_checked(@doc)}
    end
    
  end
  
end

describe Ruber::SyntaxChecker::Extension do
  
  before do
    Ruber[:world].close_all :documents, :discard
    Ruber[:components].load_plugin 'plugins/syntax_checker/'
    @plug = Ruber[:syntax_checker]
    @file = Tempfile.new ['', '.rb']
    @doc = Ruber[:world].document @file.path
    @ext = @doc.own_project.extension(:syntax_checker)
  end

  after do
    Ruber[:components].unload_plugin :syntax_checker
    led = Ruber[:main_window].status_bar.find_children(KDE::Led)[0]
    led.delete_later
    Qt::Application.send_posted_events led, Qt::Event::DeferredDelete
    @file.close
  end

  it 'inherits Qt::Object' do
    Ruber::SyntaxChecker::Extension.ancestors.should include(Qt::Object)
  end
  
  it 'includes the Ruber::Extension module' do
    Ruber::SyntaxChecker::Extension.ancestors.should include(Ruber::Extension)
  end
    
  context 'when created' do
    
    it 'creates a new syntax checker as appropriate for the document' do
      cls = Class.new{def initialize doc;end; def check_syntax *args;end}
      flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).with(@doc).once.and_return cls
      ext = Ruber::SyntaxChecker::Extension.new @doc.own_project
      ext.instance_variable_get(:@checker).should be_a(cls)
    end
    
    it 'doesn\'t attempt to create a syntax checker if there is none suitable for the document associated with the extension' do
      doc = Ruber[:world].new_document
      cls = Class.new{def check_syntax *args;end}
      flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).with(doc).once.and_return nil
      flexmock(doc.own_project).should_receive(:[]).with(:syntax_checker, :auto_check).and_return true
      ext = Ruber::SyntaxChecker::Extension.new doc.own_project
      ext.instance_variable_get(:@checker).should be_nil
    end
    
    it 'reads the syntax_checker/time_interval option from the config' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:syntax_checker, :time_interval).once.and_return 10
      ext = Ruber::SyntaxChecker::Extension.new @doc.own_project
    end
    
    it 'has the errors attribute set to nil' do
      @ext.errors.should be_nil
    end
    
    it 'has the status attribute set to unknown' do
      @ext.status.should == :unknown
    end
    
    context 'if the document is active' do
      
      before do
        flexmock(@doc).should_receive(:active?).and_return true
      end
      
      it 'creates a single shot timer' do
        ext = Ruber::SyntaxChecker::Extension.new @doc.own_project
        timer = ext.instance_variable_get :@timer
        timer.should be_a Qt::Timer
        timer.singleShot.should be_true
      end
      
    end
    
  end
  
  describe 'when the document\'s URL changes' do
    
    before do
      @cls = Class.new{def check_syntax *args;end}
      flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).by_default.and_return @cls
    end
      
    it 'creates a new syntax checker if needed' do
      @doc.instance_eval{emit document_url_changed(self)}
      @ext.instance_variable_get(:@checker).should be_a(@cls)
    end
    
    it 'removes the old syntax checker if no valid syntax checkers are found' do
      @ext.instance_variable_set :@checker, @cls.new
      flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).once.and_return nil
      @doc.instance_eval{emit document_url_changed(self)}
      @ext.instance_variable_get(:@checker).should be_nil
    end
    
  end
  
  context 'when the plugin emits the syntax_checker_added signal' do
    
    context 'and the extension has no syntax checker' do
      
      it 'creates a syntax checker if possible' do
        cls = Class.new{def check_syntax *args;end}
        flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).with(@doc).once.and_return cls
        @plug.instance_eval{emit syntax_checker_added}
        @ext.instance_variable_get(:@checker).should be_a(cls)
      end
      
    end
    
    context 'and the extension alredy has a syntax checker' do
      
      it 'does nothing' do
        @ext.instance_variable_set :@checker, Object.new
        flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).with(@doc).never
        @plug.instance_eval{emit syntax_checker_added}
      end
        
    end
    
  end
  
  context 'when the plugin emits the syntax_checker_removed signal' do
    
    it 'attempts to create a new syntax checker if possible' do
      cls = Class.new{def check_syntax *args;end}
      flexmock(Ruber[:syntax_checker]).should_receive(:syntax_checker_for).with(@doc).once.and_return cls
      @plug.instance_eval{emit syntax_checker_removed}
      @ext.instance_variable_get(:@checker).should be_a(cls)
    end
    
  end
  
  context 'when the syntax checker is changed' do
    
    context 'and the syntax_checker/auto_check document option is true' do
      
      before do
        @doc.own_project[:syntax_checker, :auto_check] = true
      end
      
      it 'performs a syntax check' do
        cls = Class.new
        flexmock(@plug).should_receive(:syntax_checker_for).and_return cls
        mk = flexmock{|m| m.should_receive(:check_syntax).once}
        flexmock(cls).should_receive(:new).once.and_return mk
        @plug.instance_eval{emit syntax_checker_added}
      end
      
    end
    
    context 'and the syntax_checker/auto_check document option is false' do
      
      before do
        @doc.own_project[:syntax_checker, :auto_check] = false
      end
      
      it 'performs a syntax check' do
        cls = Class.new
        flexmock(@plug).should_receive(:syntax_checker_for).and_return cls
        mk = flexmock{|m| m.should_receive(:check_syntax).never}
        flexmock(cls).should_receive(:new).once.and_return mk
        @plug.instance_eval{emit syntax_checker_added}
      end
      
    end
    
  end
  
  describe '#check_syntax' do
    
    context 'if there\'s a syntax checker' do
      
      before do
        @checker = flexmock{|mk| mk.should_receive(:check_syntax).by_default}
        @ext.instance_variable_set :@checker, @checker
      end
      
      it 'calls the check_syntax method of the checker passing it the text of the document and the value of the :format key' do
        @doc.text = 'xyz'
        @checker.should_receive(:check_syntax).once.with 'xyz', true
        @ext.check_syntax :format => true
      end

      context 'and the #check_syntax method of the syntax checker returns nil' do
        
        it 'returns a hash with the :result entry set to :correct and the :errors entry set to nil' do
          @checker.should_receive(:check_syntax).and_return nil
          @ext.check_syntax.should == {:result => :correct, :errors => nil}
        end
        
      end
      
      context 'and the #check_syntax method of the syntax checker returns an array' do

        it 'returns a hash with the :result entry set to :incorrect and the :errors entry set to the array' do
          errors = [Ruber::SyntaxChecker::SyntaxError.new(0,2)]
          @checker.should_receive(:check_syntax).and_return errors
          @ext.check_syntax.should == {:result => :incorrect, :errors => errors}
        end
        
      end
      
    end
    
    context 'and there isn\'t a syntax checker' do
      
      it 'doesn\'t attempt to call the check_syntax method of the syntax checker' do
        lambda{@ext.check_syntax}.should_not raise_error
      end
      
      it 'returns a hash with the :result entry set to :unknown and the :errors entry set to nil' do
        @ext.check_syntax.should == {:result => :unknown, :errors => nil}
      end
      
    end
    
    context 'if the :format and :update options are true' do
      
      before do
        @checker = flexmock{|mk| mk.should_receive(:check_syntax).by_default}
        @ext.instance_variable_set :@checker, @checker
      end
      
      it 'sets the :status entry to the same value of the :result entry in the returned hash' do
        @checker.should_receive(:check_syntax).once.and_return nil
        @checker.should_receive(:check_syntax).once.and_return []
        @ext.check_syntax :format => true, :update => true
        @ext.status.should == :correct
        @ext.check_syntax :format => true, :update => true
        @ext.status.should == :incorrect
        @ext.instance_variable_set :@checker, nil
        @ext.check_syntax :format => true, :update => true
        @ext.status.should == :unknown
      end
      
      it 'sets the errors attribute to the value returned by the #check_syntax method of the checker' do
        errors = [
          Ruber::SyntaxChecker::SyntaxError.new(0,2),
          Ruber::SyntaxChecker::SyntaxError.new(1,0)
        ]
        flexmock(@checker).should_receive(:check_syntax).once.and_return errors
        flexmock(@checker).should_receive(:check_syntax).once.and_return nil
        @ext.check_syntax
        @ext.errors.should == errors
        @ext.check_syntax
        @ext.errors.should be_nil
      end
      
      it 'sets the errors attribute to nil if there\'s no syntax checker' do
        @ext.instance_variable_set :@checker, nil
        @ext.check_syntax :format => true, :update => true
        @ext.errors.should be_nil
      end
      
      it 'emits the syntax_checked signal passing the document as argument' do
        mk = flexmock{|m| m.should_receive(:syntax_checked).once.with(@doc)}
        @ext.connect(SIGNAL('syntax_checked(QObject*)')){|doc| mk.syntax_checked doc}
        @ext.check_syntax
      end
      
      context 'and the #check_syntax method of the checker returns non-nil' do
        
        it 'adds a mark of a custom type for each found error to the document' do
          pending "Use marks only when KTextEditor::MarkInterface actually works"
          @doc.text = "abc\ncde\nfgh"
          errors = [
            Ruber::SyntaxChecker::SyntaxError.new(0,2),
            Ruber::SyntaxChecker::SyntaxError.new(1,0)
          ]
          flexmock(@checker).should_receive(:check_syntax).and_return errors
          @ext.check_syntax
          iface = @doc.interface('mark_interface')
          (iface.mark(0) & @ext.class::SyntaxErrorMark).should_not == 0
          (iface.mark(1) & @ext.class::SyntaxErrorMark).should_not == 0
          (iface.mark(2) & @ext.class::SyntaxErrorMark).should == 0
        end
        
        it 'doesn\'t add marks for errors without a line number' do
          pending "Use marks only when KTextEditor::MarkInterface#marks actually works"
          @doc.text = "abc\ncde\nfgh"
          checker = Object.new
          @ext.instance_variable_set :@checker, checker
          errors = [
            Ruber::SyntaxChecker::SyntaxError.new(0,2),
            Ruber::SyntaxChecker::SyntaxError.new(nil, 2)
          ]
          flexmock(checker).should_receive(:check_syntax).and_return errors
          @ext.check_syntax
          iface = @doc.interface('mark_interface')
          (iface.mark(0) & @ext.class::SyntaxErrorMark).should_not == 0
          (iface.mark(1) & @ext.class::SyntaxErrorMark).should == 0
          (iface.mark(2) & @ext.class::SyntaxErrorMark).should == 0
        end
        
      end
      
      context 'and the #check_syntax method of the checker returns nil' do
        
        it 'clears all the marks put by the extension' do
          pending "Use marks only when KTextEditor::MarkInterface actually works"
          @doc.text = "abc\ncde\nfgh"
          iface = @doc.interface('mark_interface')
          iface.add_mark 0, @ext.class::SyntaxErrorMark 
          iface.add_mark 2, @ext.class::SyntaxErrorMark
          flexmock(@checker).should_receive(:check_syntax).and_return nil
          iface.marks.should be_empty
        end
        
      end
      
    end
    
    shared_examples_for 'the syntax checker extension when it should not update after a syntax check' do
      
      before do
        @checker = Object.new
        flexmock(@checker).should_receive(:check_syntax).by_default
        @ext.instance_variable_set :@checker, @checker
      end

      it 'doesn\'t change the marks' do
        pending "Use marks only when KTextEditor::MarkInterface actually works"
      end
      
      it 'doesn\'t emit the syntax_checked signal' do
        mk = flexmock{|m| m.should_receive(:syntax_checked).never}
        @ext.connect(SIGNAL('syntax_checked(QObject*)')){|doc| mk.syntax_checked doc}
        @ext.check_syntax @options
      end
      
      it 'doesn\'t change the errors attribute' do
        errors = [
          Ruber::SyntaxChecker::SyntaxError.new(0,2),
          Ruber::SyntaxChecker::SyntaxError.new(nil, 2)
        ]
        @ext.instance_variable_set :@errors, errors
        flexmock(@checker).should_receive(:check_syntax).and_return nil
        @ext.check_syntax @options
        @ext.errors.should == errors
      end
      
    end
    
    context 'when the :format option is false' do
      
      before do
        @options = {:format => false, :update => true}
      end
      
      it_behaves_like 'the syntax checker extension when it should not update after a syntax check'

    end
    
    context 'when the :update option is false' do
      
      before do
        @options = {:format => true, :update => false}
      end
      
      it_behaves_like 'the syntax checker extension when it should not update after a syntax check'

    end
    
  end
  
  shared_examples_for 'the syntax checker extension doing an auto syntax check' do
    
    context 'if the syntax_checker/check document option is true' do
      
      before do
        @doc.own_project[:syntax_checker, :auto_check] = true
      end
      
      it 'checks the document syntax passing no arguments to #check_syntax' do
        flexmock(@ext).should_receive(:check_syntax).once.with_no_args
        @proc.call
      end
      
    end
    
    context 'if the syntax_checker/auto_check document option is false' do
      
      before do
        @doc.own_project[:syntax_checker, :auto_check] = false
      end
      
      it 'doesn\'t check the document syntax' do
        flexmock(@ext).should_receive(:check_syntax).never
        @proc.call
      end
      
    end
    
  end
  
  context 'when the document is saved' do
    
    before do
      @proc = Proc.new{@doc.instance_eval{emit document_saved_or_uploaded(self, false)}}
    end
    
    it_behaves_like 'the syntax checker extension doing an auto syntax check'
    
  end
  
  context 'when the document becomes active' do
    
    before do
      @proc = Proc.new{@doc.activate}
    end

    it_behaves_like 'the syntax checker extension doing an auto syntax check'
    
    it 'creates a single shot timer' do
      @doc.activate
      timer = @ext.instance_variable_get :@timer
      timer.should be_a(Qt::Timer)
      timer.singleShot.should be_true
    end
    
  end
  
  context 'when the document becomes inactive' do
    
    before do
      @doc.activate
    end
    
    it 'stops the timer' do
      flexmock(@ext.instance_variable_get(:@timer)).should_receive(:stop).once
      @doc.deactivate
    end
    
    it 'calls the #delete_later method of the timer' do
      flexmock(@ext.instance_variable_get(:@timer)).should_receive(:delete_later).once
      @doc.deactivate
    end
    
    it 'removes the timer' do
      @doc.deactivate
      @ext.instance_variable_get(:@timer).should be_nil
    end
        
  end
  
  context 'when the plugin emits the settings_changed signal' do
    
    it 'reads the syntax_checker/time_interval option from the config' do
      flexmock(Ruber[:config]).should_receive(:[]).with(:syntax_checker, :time_interval).once.and_return 10
      @plug.instance_eval{emit settings_changed}
    end
    
  end
  
  context 'when the text in the document changes' do
    
    context 'and the document is active' do
      
      before do
        @doc.deactivate
        @doc.activate
      end
      
      context 'and the time interval is greater than 0' do
        
        it 'starts the timer using the given time interval multiplied by 1000' do
          @ext.instance_variable_set :@time_interval, 10
          timer = @ext.instance_variable_get :@timer
          flexmock(timer).should_receive(:start).with(10_000).once
          @doc.text = 'y'
        end
        
      end
      
      context 'and the time interval is 0' do
        
        it 'doesn\'t start the timer' do
          @ext.instance_variable_set :@time_interval, 0
          timer = @ext.instance_variable_get :@timer
          flexmock(timer).should_receive(:start).never
          @doc.text = 'x'
        end
        
        
      end
      
    end
    
    context 'and the document is not active' do
      
      before do
        @doc.deactivate
      end
      
      it 'doesn\'t attempt to start the timer' do
        @ext.instance_variable_set :@time_interval, 10
        timer = @ext.instance_variable_get :@timer
        flexmock(timer).should_receive(:start).never
        @doc.text = 'x'
      end
      
    end
    
  end
  
  context 'when the timer times out' do
    
    it 'calls the auto_check method' do
      @doc.activate
      flexmock(@ext).should_receive(:auto_check).once
      @ext.instance_variable_get(:@timer).instance_eval{emit timeout}
    end
    
  end
  
  describe '#remove_from_project' do
    
    it 'stops the timer' do
      @doc.activate
      flexmock(@ext.instance_variable_get(:@timer)).should_receive(:stop).once
      @ext.remove_from_project
      #needed becouse remove_from_project is called in the after block when 
      #unloading the plugin. Without this, the method is called twice
      flexmock(@ext).should_receive(:remove_from_project)
    end
    
    it 'doesn\'t stop the timer if it doesn\'t exist' do
      @ext.instance_variable_set(:@timer, nil)
      lambda{@ext.remove_from_project}.should_not raise_error
    end
    
  end
  
end