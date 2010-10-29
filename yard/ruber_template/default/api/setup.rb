def init
  super
  sections << :api << :plugin << :config_option_list << [:config_option]
  sections << :project_option_list << [:project_option]
  sections << :extension_list << [:extension] << :tool_widget_list << [:tool_widget]
  sections << :api_method_list << :api_signal_list << :api_slot_list
  sections << :api_class_list << :api_constant_list << :api_misc
end

def api
  tag = object.tag :api
  return unless tag
  read_plugin_spec if tag.api_type == 'feature'
  # Tool widgets have apy_type "tool_widget", so we need to replace the underscore
  # with a space to generate pleasant text
  <<-HTML
    <h2>API for #{tag.api_type.gsub('_', '')} <tt>#{tag.api_name}</tt></h2>
  HTML
end

def plugin
  if object.has_tag?(:plugin)
    cls = object.tag(:plugin).text
    cls = object.plugin_spec[:class] if cls.empty?
    if cls
      link = resolve_links("{#{cls}}")
      <<-HTML
      <h4>Plugin object API</h4>
      <p>See API for #{link}</p>
      HTML
    end
  end
end

def read_plugin_spec
  files = object.files.map{|f, _| File.join(File.dirname(f), 'plugin.yaml')}
  file = files.find{|f| File.exist? f}
  data = SymbolHash.new.merge(YAML.load File.read(file)) rescue SymbolHash.new
  object.plugin_spec = data
end

def read_extension_entry ext_tag, object
  ext_name = ext_tag.name
  tag_data = ext_tag.data
  psf_data = object.plugin_spec[:extensions][ext_name] rescue {}
  data = []
  if psf_data.is_a? Array
    if !tag_data.empty? then data << tag_data
    else
      psf_data.each{|d| data << d}
    end
  else data << SymbolHash.new(false).merge(psf_data).merge(tag_data)
  end
  data
end

def format_extension_api data
  data = data.reject{|i| !(i.has_key? :api or i.has_key :class)}
  return if data.empty?
  list = false
  res = %|<dt style="font-weight: bold;">API</dt>\n<dd>\n|
  if data.size > 1
    res << "<ul>\n"
    list = true
  end
  data.each do |d|
    api = d[:api] ? make_html(d[:api]) : "See API for #{resolve_links '{' + d[:class] + '}' }"
    item = "#{api}\n<dl>\n#{format_rules d}\n</dl>\n"
    item = "<li>\n" + item + "</li>\n" if list 
    res << item
  end
  res << "</ul>\n" if list
  res << "</dd>\n"
  res
end

def format_rules rules
  rules = read_rules rules
  return if rules.empty?
  doc_rules = format_document_rules rules
  res = ''
  if doc_rules or rules[:scope] == 'documents'
    res << "\n<li>documents#{doc_rules}</li>\n"
  end
  if (!res.empty? and !rules[:scope]) or rules[:scope].include? 'projects'
    res << "\n<li>projects</li>\n"
  end
  <<-HTML
  <dt style="font-weight: bold;">Only for:</dt>
  <dd>
    <ul style="margin-top:0;">
    #{res}
    </ul>
  </dd>
  HTML
end

def format_document_rules rules
  return if rules[:scope] and !rules[:scope].include?('documents')
  make_beginning = lambda do |key, sing, plur|
    rules[key].size == 1 ? sing : plur
  end
  res = ''
  if rules.has_key? :file_extension
    beginning = make_beginning.call :file_extension, "matching the shell glob", "matching one of the shell globs"
    res << "<li>#{beginning} #{rules[:file_extension].map{|e| "<tt style=\"font-weight: bold;\">#{e}</tt>"}.join ', '}</li>"
  end
  if rules.has_key? :accept_mimetype
    beginning = make_beginning.call :accept_mimetype, "with mimetype", "with one of the mimetypes"
    res << "<li>#{beginning} #{rules[:accept_mimetype].map{|m| %|<tt style="font-weight: bold;">#{m}</tt>|}.join ', '}</li>"
  end
  if rules.has_key? :reject_mimetype
    res << "<li>with mimetype different from #{rules[:accept_mimetype].map{|m| "<tt style=\"font-weight: bold;\">#{m}</tt>"}.join ', '}</li>"
  end
  res = ":\n<ul>" + res + "</ul>\n" unless res.empty?
  res
end

def read_rules rules
  res = {}
  res[:scope] = read_scope(rules[:scope])
  res.delete :scope if res[:scope].nil?
  res.merge! read_mimetype_rules(rules[:mimetype])
  res[:file_extension] = Array(rules[:file_extension]).compact
  res.delete :file_extension if res[:file_extension].empty?
  res
end

def read_scope scope_rule
  scope = Array(scope_rule).compact.map!(&:to_sym)
  scope = [:global] if scope.empty?
  return if scope.include?(:all)
  return if scope.include? :global and scope.include?(:document)
  if scope.include?(:document) then 'documents'
  else 'projects'
  end
end

def read_mimetype_rules mime
  res = {:accept_mimetype => [], :reject_mimetype => []}
  mime = Array mime
  mime.each do |m|
    m = m.dup
    (m.sub!(/^!/,'') ? res[:reject_mimetype] : res[:accept_mimetype]) << m
  end
  res.delete_if{|k, v| v.empty?}
  res
end

def make_api_list tag, header
  tags = object.tags tag
  return if tags.empty?
  res = tags.inject("<h4>#{header}</h4>\n<ul>\n") do |r, t|
    r << "<li>#{resolve_links '{' + t.text + '}'}</li>\n"
  end
  res + "</ul>\n"
  
end

def api_method_list
  make_api_list :api_method, "Methods API"
end

def api_signal_list
  make_api_list :api_signal, "Signals API"
end

def api_slot_list
  make_api_list :api_slot, "Slots API"
end

def api_class_list
  make_api_list :api_class, "Classes API"
end

def api_constant_list
  make_api_list :api_constant, 'Constants API'
end

def api_misc
  tag = object.tag :api
  return if !tag or tag.text.empty?
  text = tag.text
  <<-HTML
  <h5 style="margin-bottom:0;">Other Information</h5>
  <div>
    #{make_html text}
  </div>
  HTML
end