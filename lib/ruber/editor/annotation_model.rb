=begin 
    Copyright (C) 2012 by Stefano Crocco   
    stefano.crocco@alice.it   
  
    This program is free software; you can redistribute it andor modify  
    it under the terms of the GNU General Public License as published by  
    the Free Software Foundation; either version 2 of the License, or     
    (at your option) any later version.                                   
  
    This program is distributed in the hope that it will be useful,       
    but WITHOUT ANY WARRANTY; without even the implied warranty of        
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         
    GNU General Public License for more details.                          
  
    You should have received a copy of the GNU General Public License     
    along with this program; if not, write to the                         
    Free Software Foundation, Inc.,                                       
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             
=end

module Ruber
  
=begin rdoc
Annotation model used by {Ruber::Document}

It provides a friendler interface than @KTextEditor::AnnotationModel@ does
=end
  class AnnotationModel < KTextEditor::AnnotationModel
    
    include Enumerable
    
=begin rdoc
Class describing an annotation
@attr [Symbol] type the type of the annotation. It must be one of the values
  registered with {AnnotationModel.register_annotation_type}
@attr [Integer] line the number of the line where the annotation is
@attr [String] msg the text of the annotation
@attr [String] tool_tip the text to display in the tool tip of the annotation
@attr [Object] data custom data associated with the annotation
=end
    Annotation = Struct.new :type, :line, :msg, :tool_tip, :data
    
=begin rdoc
Signal emitted whenever an annotation is added or removed
=end
    signals :annotations_changed 

=begin rdoc
Signal emitted whenever an annotation is added or removed
@param [Integer] line the line of the changed annotation
=end
    signals 'annotation_changed(int)'
    
    @annotation_types = {}
    
    class << self
=begin rdoc
@return [{Symbol => (Qt::Variant, Qt::Variant)}] the registered annotation types.
  
  The first element in each array is the brush used for the foreground, while
  the second is the brush used for the background
=end
      attr_reader :annotation_types
    end
    
=begin rdoc
Registers a new annotation type

@param [Symbol] type the name of the new type of annotation
@param [Qt::Brush.new, nil] back the brush to use for the background. If *nil*,
  the standard brush will be used
@param [Qt::Brush.new, nil] back the brush to use for the foreground. If *nil*,
  the standard brush will be used
@return [nil]
=end
    def self.register_annotation_type type, back = nil, fore = nil
      raise ArgumentError, "Annotation type #{type} has already been added" if 
      @annotation_types.has_key?(type)
      @annotation_types[type] = [back, fore].map{|i| i ? Qt::Variant.fromValue(i) : Qt::Variant.new}
      nil
    end
    
=begin rdoc
@param [Document] doc the document the annotation model refers to
=end
    def initialize doc
      super()
      @doc = doc
      @annotations = Dictionary.alpha
      connect self, SIGNAL('annotation_changed(int)'), self, SIGNAL('lineChanged(int)')
    end
    
=begin rdoc
Adds an annotation to the model
@return [Annotation]
@overload add_annotation ann
  Adds the given annotation to the model
  @param [Annotation] ann the annotation to add
  @return [Annotation] _ann_
@overload add_annotation type = nil, line = nil, msg = nil, tool_tip = nil, data = nil
  Adds an annotation created passing the arguments to @Annotation.new@
  @param [Symbol] type the type of the annotation. It must be one of the values
    registered with {AnnotationModel.register_annotation_type}
  @param [Integer] line the number of the line where the annotation is
  @param [String] msg the text of the annotation
  @param [String] tool_tip the text to display in the tool tip of the annotation
  @param [Object] data custom data associated with the annotation
  @return [Annotation] the new annotation
=end
    def add_annotation *args
      a = args.size == 1 ? args[0] : Annotation.new( *args )
      # TODO: see why this sometimes gives extremely weird errors
      #The begin/rescue clause is there to find out why sometimes I get a crash saying:
      # `<': comparison of Fixnum with Qt::Variant failed (ArgumentError)
      #       begin
      
      #         raise IndexError, "Invalid line: #{a.line}" unless a.line < @doc.lines
      #       rescue ArgumentError
      #         puts "a.line: #{a.line}(#{a.line.class})"
      #         puts "@doc.lines: #{@doc.lines}(#{@doc.lines.class})"
      #       end
      @annotations[a.line] = a
      emit annotations_changed
      emit annotation_changed( a.line)
      a
    end
    
=begin rdoc
Override of @KTextEditor::AnnotationModel#data@

@param [Integer] line the line of the annotation
@param [Qt::ItemDataRole] role the role to retrieve data for
@return [Qt::Variant] data appropriate with the role
=end
    def data line, role
      a = @annotations[line]
      return Qt::Variant.new unless a
      case role
      when Qt::DisplayRole then Qt::Variant.new a.msg
      when Qt::ToolTipRole then Qt::Variant.new a.tool_tip
      when Qt::ForegroundRole then self.class.annotation_types[a.type][1]
      when Qt::BackgroundRole then self.class.annotation_types[a.type][0]
      else Qt::Variant.new
      end
    end
    
=begin rdoc
The annotation at the given line
@param [Integer] line the line to retrieve the annotation for
@return [Annotation,nil] the annotation at the given line or *nil* if there's
  no annotation for that line
=end
    def annotation line
      @annotations[line]
    end
    alias_method :[], :annotation
    
=begin rdoc
Whether there's an annotation at the given line
@param [Integer] line the line to check for an annotation
@return [Boolean] whether there's an annotation at line _line_
=end
    def has_annotation? line
      @annotations.has_key? line
    end
    
=begin rdoc
@return [Boolean] whether the model contains any annotation
=end
    def has_annotations?
      !@annotations.empty?
    end

=begin rdoc
@return [Boolean] whether the model is empty 
=end
    def empty?
      @annotations.empty?
    end
    
=begin rdoc
Removes all annotations from the model
@return [nil]
=end
    def clear
      @annotations.clear
      emit annotations_changed
      emit reset
      nil
    end
    
=begin rdoc
Removes the annotation from a given line

@param [Integer] line the line to remove the annotation from
@return [Annotation, nil] the removed annotation or *nil* if there wasn't any
  annotation for the given line
=end
    def remove_annotation line
      ann = @annotations.delete line
      if ann
        emit annotations_changed 
        emit annotation_changed( line )
      end
      ann
    end
    
=begin rdoc
Iterates on all the annotations in the model
@return [AnnotationModel,Enumerator]
@overload each_annotation
  Calls the block for each annotation in the model
  @yield [ann] the block to call for each annotation
  @yieldparam [Annotation] ann an annotation contained in the block
  @return [AnnotationModel] self
@overload each_annotation
  @return [Enumerator] an enumerator which iterates on all the annotations in
    the model
=end
    def each_annotation
      if block_given? 
        @annotations.each_pair{|k, v| yield v}
        self
      else to_enum
      end
    end
    alias_method :each, :each_annotation
    
  end  
  
end