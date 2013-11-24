require 'yard'
YARD::Templates::Engine.register_template_path 'yard/ruber_template'

# Substitute of htmlify when you don't want the extra <p>...</p> that RedCloth
# introduces. It strips the resulting html string removing the extra <p>...</p>
# except when the text started with <p> or p. (or variants) or with spaces (it
# seems that RedCloth doesn't introduce the extra <p> if the string starts with
# a space)
module YARD::Templates::Helpers::HtmlHelper

  def make_html text, remove_extra_par = true
    html = htmlify text
    if remove_extra_par
      unless text.match(/\A\s+|<p>|p(?:\([^)]+\))?\./)
        html.sub!(/\A<p>/,'')
        html.sub!(%r|</p>\Z|, '')
      end
    end
    html
  end
  
end

class RuberTagsFactory < YARD::Tags::DefaultFactory
  
  def parse_tag name, text
    case name
    when :api then ApiTag.new text
    when :extension then PSFObjectTag.new :extension, text
    when :tool_widget then PSFObjectTag.new :tool_widget, text
    else super
    end
  end
  
  def parse_tag_with_types_and_name name, text
    if name == :config_option or name == :project_option
      cls = name == :config_option ? ConfigOptionTag : ProjectOptionTag
      group, opt_name, rest = text.split(/\s+/,3)
      temp_tag = parse_tag_with_types name, rest
      cls.new group, opt_name, temp_tag.types, temp_tag.text
    else super
    end
  end
  
end

class ApiTag < YARD::Tags::Tag
  
  attr_reader :api_type, :api_name
  
  def initialize text
    @api_type, @api_name, text = text.split %r{\s+}, 3
    super :api, text || ''
  end
  
end

class PSFObjectTag < YARD::Tags::Tag
  
  attr_reader :name, :description, :data
  def initialize type, text, types = nil
    super type, '', types
    text = text.strip
    @name, desc = text.split(/\s+/, 2)
    return unless @name
    @data = SymbolHash.new false
    if desc and desc.match(/^\{/)
      @data.merge! YAML.load(desc)
      @description = @data['description']
    else @description = desc
    end
  end
  
end

class ConfigOptionTag < YARD::Tags::Tag
  
  attr_reader :name, :group
  
  def initialize group, name, types, text
    super :config_option, text, types
    @name = name
    @group = group
  end
  
end

class ProjectOptionTag < PSFObjectTag
  
  attr_reader :group
  
  def initialize group, name, types, text
    super :project_option, name + ' ' + text, types
    @group = group
  end
  
end

YARD::Tags::Library.default_factory = RuberTagsFactory

YARD::Tags::Library.define_tag '', :api

YARD::Tags::Library.define_tag '', :plugin

YARD::Tags::Library.define_tag '', :extension

YARD::Tags::Library.define_tag '', :config_option, :with_types_and_name

YARD::Tags::Library.define_tag '', :project_option, :with_types_and_name

YARD::Tags::Library.define_tag '', :tool_widget

YARD::Tags::Library.define_tag '', :api_method

YARD::Tags::Library.define_tag '', :api_signal

YARD::Tags::Library.define_tag '', :api_slot

YARD::Tags::Library.define_tag '', :api_class

YARD::Tags::Library.define_tag '', :api_constant

class SignalCodeObject < YARD::CodeObjects::Base
  
  attr_reader :qt_signature, :scope, :attr_info, :visibility
  
  def initialize namespace, name, signature
    super namespace, name
    @qt_signature = signature
    @scope = :instance
    @attr_info = nil
    @visibility = :public
  end
  
  def sep
    '#'
  end

  def parameters
    # We need to remove the deliminting brackets
    types = @qt_signature[1...-1].split(/\s*,\s*/)
    params = tags(:param)
    types.each_with_index.map do |par, i|
      par_tag = params[i]
      name = par_tag ? par_tag.name : "arg#{i + 1}"
      par + " #{name}"
    end
  end
  
#   def signature
#     arg_number = @qt_signature == '()' ? 0 : @qt_signature.count(',') + 1
#     params = tags(:param)
#     res = params[0...arg_number].inject(''){|r, t| r << t.name << ', '}
#   end
  
end

class SignalsHandler < YARD::Handlers::Ruby::Base
  
  handles method_call(:signals)
  
  def process
    signals = {}
    statement.parameters(false).each do |s|
      case s.type
      when :string_literal
        text_node = s.jump(:tstring_content)
        if text_node
          code = text_node[0]
          begin
            name, args = code.match(/^([^(]+)(.*)/).to_a[1..-1]
            signals[name] = args
          rescue NoMethodError
          end
        end
      when :symbol_literal
        text_node = s.jump(:ident)
        signals[text_node[0]] = '()' if text_node
      end
    end
    signals.each_pair do |name, args|
      sig = SignalCodeObject.new namespace, name, args
      register sig
    end
  end
  
end

class SlotsHandler < YARD::Handlers::Ruby::Base
  
  handles method_call(:slots)
  
  def process
    namespace[:slots] ||= {}
    statement.parameters(false).each do |s|
      case s.type
      when :string_literal
        text_node = s.jump(:tstring_content)
        if text_node
          code = text_node[0]
          begin
            name, args = code.match(/^([^(]+)(.*)/).to_a[1..-1]
            namespace[:slots][name] = args
          rescue NoMethodError
          end
        end
      when :symbol_literal
        text_node = s.jump(:ident)
        namespace[:slots][text_node[0]] = '()' if text_node
      end
    end
  end
  
end