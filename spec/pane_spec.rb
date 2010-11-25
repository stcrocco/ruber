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
  
  context 'when created with one view' do
    
    it 'makes the view child of itself' do
      view = @doc.create_view nil
      pane = Ruber::Pane.new view
      view.parent.should == pane
    end
    
    it 'inserts the view in the layout' do
      view = @doc.create_view nil
      pane = Ruber::Pane.new view
      pane.layout.should
    end
    
  end
  
end