require 'spec/framework'
require 'spec/common'

require 'ruber/editor/document'
require 'ruber/editor/annotation_model'

describe Ruber::AnnotationModel do

  before do
    @doc = Ruber::Document.new Ruber[:world]
    @model = Ruber::AnnotationModel.new @doc
  end

  it 'should inherit KTextEditor::AnnotationModel' do
    @model.should be_kind_of( KTextEditor::AnnotationModel )
  end

  it 'should include the Enumerable module' do
    Ruber::AnnotationModel.ancestors.include?(Enumerable).should be_true
  end

  it 'should allow to add annotation types at class level' do
    b = Qt::Brush.new(Qt.yellow)
    @model.class.register_annotation_type :test, b
    h = @model.class.instance_variable_get(:@annotation_types)
    h.should have_key(:test)
    h[:test][0].value.should == b
    h[:test][1].should be_null
  end

  it 'should raise ArgumentError when registering an already registered annotation type' do
    @model.class.register_annotation_type :test
    lambda{@model.class.register_annotation_type( :test)}.should raise_error( ArgumentError )
  end

  it 'should allow to add an annotation for an existing line using three parameters' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    lambda{ @model.add_annotation :test, 1,  "message", "tool tip"}.should_not raise_error
    @model.data(1, Qt::DisplayRole).to_string.should == 'message'
    @model.data(1, Qt::ToolTipRole).to_string.should == 'tool tip'
  end

  it 'should allow to add an annotation for an existing line using one parameter' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    lambda{ @model.add_annotation Ruber::AnnotationModel::Annotation.new(:test, 1, "message", "tool tip")}.should_not raise_error
    @model.data(1, Qt::DisplayRole).to_string.should == 'message'
    @model.data(1, Qt::ToolTipRole).to_string.should == 'tool tip'
  end

  it 'should raise IndexError when an annotation is added to a nonexisting line' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    pending "There's something weird going on here"
    lambda{ @model.add_annotation :test, 5,  "message", "tool tip"}.should raise_error(IndexError)
    lambda{ @model.add_annotation Ruber::AnnotationModel::Annotation.new(:test, 3, "message", "tool tip")}.should raise_error(IndexError)
  end

  it 'should allow to retreive the annotation for a given line' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\ghi"
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model[1].should == Ruber::AnnotationModel::Annotation.new(:test, 1, "message", "tool tip")
    @model.annotation(1).should == Ruber::AnnotationModel::Annotation.new(:test, 1, "message", "tool tip")
  end

  it 'should tell whether there\'s an annotation for a given line' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.should have_annotation(1)
    @model.should_not have_annotation(2)
  end

  it 'should tell whether there are annotations or not' do
    @model.should_not have_annotations
    @model.should be_empty
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\ghi"
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.should have_annotations
    @model.should_not be_empty
  end

  it 'should allow to remove all annotations' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.add_annotation :test, 2,  "message", "tool tip"
    @model.clear
    @model.should be_empty
  end

  it 'should allow to remove the annotations for one line' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.add_annotation :test, 2,  "message", "tool tip"
    @model.remove_annotation 1
    @model.should_not be_empty
    @model.should_not have_annotation(1)
  end

  it 'should allow to iterate on all annotations in order' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    3.times{|i| @model.add_annotation :test, (i+1)%3,  ((i+1)%3).to_s, "tool tip"}
    m = flexmock('mock')
    m.should_receive(:test).once.globally.ordered.with("0")
    m.should_receive(:test).once.globally.ordered.with("1")
    m.should_receive(:test).once.globally.ordered.with("2")
    @model.each{|a| m.test(a.msg)}
  end

  it 'should emit the "annotations_changed()" signal when an annotation is added or removed or the model is cleared' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    m = flexmock
    m.should_receive(:annotations_changed).times(3)
    @model.connect(SIGNAL('annotations_changed()')){m.annotations_changed}
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.remove_annotation 1
    @model.remove_annotation 0
    @model.block_signals(true)
    @model.add_annotation :test, 2,  "message", "tool tip"
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.block_signals(false)
    @model.clear
  end

  it 'should emit the "annotations_changed(int)" signal when an annotation is added or removed' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    m = flexmock
    m.should_receive(:annotation_changed).once.globally.ordered.with(1)
    m.should_receive(:annotation_changed).once.globally.ordered.with(1)
    @model.connect(SIGNAL('annotation_changed(int)')){|i| m.annotation_changed(i)}
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.remove_annotation 1
    @model.remove_annotation 0
  end

  it 'should emit the "lineChanged(int)" signal when an annotation is added or removed' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    m = flexmock
    m.should_receive(:lineChanged).once.globally.ordered.with(1)
    m.should_receive(:lineChanged).once.globally.ordered.with(1)
    @model.connect(SIGNAL('lineChanged(int)')){|i| m.lineChanged(i)}
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.remove_annotation 1
    @model.remove_annotation 0
  end

  it 'should emit the "reset()" signal when the model is cleared' do
    @model.class.register_annotation_type :test
    @doc.text = "abc\ndef\nghi"
    m = flexmock
    m.should_receive(:reset).once
    @model.connect(SIGNAL('reset()')){m.reset}
    @model.add_annotation :test, 1,  "message", "tool tip"
    @model.clear
  end

  after do
    @model.class.instance_variable_get(:@annotation_types).clear
  end

end