=begin 
    Copyright (C) 2010 by Stefano Crocco   
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

require 'facets/ostruct'

module Ruber

  class PluginSpecificationReader

=begin rdoc
Class used to contain the information about an option. It behaves as a regular
@OpenStruct@, except it has a {#default} and a {#to_os} method.
=end
    class Option < OpenStruct
      
=begin rdoc
The default value of the option

The default value is computed basing on the value stored in the @default@ entry
in the option description in the PSF, according to the following algorithm:
* if the value is not a string, it is returned unchanged
* if the value is a string and the @eval_default@ attribute has been set
  to *false* in the PSF, it is returned unchanged
* if it is a string and the @eval_default@ flag is *true*, the string is
  evaluated using @eval@ and the corresponding value is returned. If @eval@
  raises @SyntaxError@, @NoMethodError@ or @NameError@ then the string is
  returned unchanged (of course, the exception isn't propagated).
  
@param [Binding] bind the bindings to pass to @eval@
@return [Object] the default value for the option 
=end
      def default bind = TOPLEVEL_BINDING
        val = super()
        if val.is_a? String and self.eval_default
          begin eval val, bind
          rescue NoMethodError, SyntaxError, NameError, ArgumentError
            val
          end
        else val
        end
      end
  
# This seems to be unused
#       def compute_default bind = TOPLEVEL_BINDING
#         val = super()
#         if val.is_a? String and self.eval_default
#           begin eval val, bind
#           rescue NoMethodError, SyntaxError, NameError, ArgumentError
#             val
#           end
#         else val
#         end
#       end
      
=begin rdoc
The option object with the default computed as an @OpenStruct@
@param [Binding] bind the bindings to pass to {#default}
@return [OpenStruct] an OpenStruct with the same contents as *self* but with an
  added @default@ entry, set to the value returned by {#default}
=end
      def to_os bind = TOPLEVEL_BINDING
        hash = to_h
        hash[:default] = default bind
        OpenStruct.new hash
      end
      
    end
    
=begin rdoc
A list of valid licences
=end
    LICENSES = [:unknown, :gpl, :gpl2, :lgpl, :lgpl2, :bsd, :artistic, :qpl, :qpl1, :gpl3, :lgpl3]
    
=begin rdoc
@param [OpenStruct] info the object where to store the information read from
  the PSF
=end
    def initialize info
      @plugin_info = info
    end
  
=begin rdoc
Reads all information from the PSF

This method causes the whole PSF to be read. This causes a number of side effects
(for example, all files under the @require@ entry of the PSF will be required)

@param [Hash] the hash with the contents of the PSF as they are. Keys can be
  either strings or symbols
@return [OpenStruct] the object containing a completely parsed form of the
  contents of the PSF 
=end    
    def process_pdf hash
      @plugin_info.type = read_type hash
      @plugin_info.name = read_name hash
      @plugin_info.about = read_about hash
      @plugin_info.version = read_version hash
      @plugin_info.required = read_required hash
      @plugin_info.required.each do |f| 
        file = File.join @plugin_info.directory, f
        if file.end_with?('.rb') then load file
        else require file
        end
      end
      @plugin_info.class_obj = read_class hash
      @plugin_info.features = read_features hash
      @plugin_info.deps = read_deps hash
      @plugin_info.runtime_deps = read_runtime_deps hash
      @plugin_info.ui_file = read_ui_file hash
      @plugin_info.tool_widgets = read_tool_widgets hash
      @plugin_info.config_widgets = read_config_widgets hash
      @plugin_info.config_options = read_config_options hash
      @plugin_info.project_options = read_project_options hash
      @plugin_info.project_widgets = read_project_widgets hash
      @plugin_info.extensions = read_extensions hash
      @plugin_info.actions = read_actions hash
      @plugin_info
    end
  
=begin rdoc
Reads all the information from the introduction of the PSF

The introduction of the PSF contains the following fields:
* name
* about
* version
* type
* required
* features
* deps
* runtime_deps

Reading the PSF introduction is warranted not to have side effects
@param [Hash] the hash with the contents of the PSF introduction as they are.
  Keys can be either strings or symbols
@param [Boolean] component whether the PSF is for a core component or not (meaning
  it's for a plugin). The PSF for a core component doesn't need to have a @name@
  entry
@return [OpenStruct] the object containing a completely parsed form of the
  contents of the PSF introduction
=end
    def process_pdf_intro hash, component = false
      @plugin_info.name = read_name hash, component
      @plugin_info.about = read_about hash
      @plugin_info.version = read_version hash
      @plugin_info.type = read_type hash
      @plugin_info.required = read_required hash
      @plugin_info.features = read_features hash
      @plugin_info.deps = read_deps hash
      @plugin_info.runtime_deps = read_runtime_deps hash
      @plugin_info
    end
    
    private
    
=begin rdoc
Whether the given hash contains an entry

It checks for both the string and symbol version of the key
@param [Hash] hash the hash to look for the key in
@param [String] key the key to look for
@return [Boolean] *true* if _hash_ contains either _key_ or the symbol form of
  _key_ (@key.to_sym@) and *false* otherwise
=end
    def has_key? hash, key
      hash.has_key?(key) or hash.has_key?(key.to_sym)
    end
    
=begin rdoc
Retrieves a value from a hash

This is a convenience method, which checks for both the symbol and string form
of the key. If neither exists in the hash an exception can be raised or a default
value can be returned. If both symbol and string form of the key exists, the
symbol form is used

@param [Hash] hash the hash to look for the key in
@param [Symbol] key the key to look for
@param [Object] default the default value to use if the key doesn't exist in
  the hash. It's not used if _required_ is *true*
@param [Boolean] required whether the entry *must* exist in the hash or it has
  a default value. In the former case, an exception will be raised if the key
  doesn't exist in either symbol or string form
@return [Object] the entry associated with _key_ in _hash_. If no entry is associated
  with _key_, _key_ is converted to a string and the value associated with the
  string is returned. If the string key doesn't exist either, then _default_
  value is returned, unless _required_ is *true*
@raise [PluginSpecification::PSFError] if _hash_ doesn't contain either the
  symbol nor the string form of _key_ and _required_ is *true*
=end
    def get_value hash, key, default, required = false
      hash.fetch(key) do |k|
        if required
          hash.fetch(key.to_s){raise PluginSpecification::PSFError, 
                              "The required '#{key}' entry is missing from the PDF"}
        else hash.fetch(key.to_s, default)
        end
      end
    end
    
=begin rdoc
Reads an entry from a hash and converts it to an array

It works similarly to {#get_value}, but, if the value is not an array, it is
inserted into one.

If _conversion_ is not *nil*, it is used to transform the elements of the array
before returing it
@param hash (see #get_value)
@param key (see #get_value)
@param [Symbol, nil] conversion if not *nil*, the returned array won't be the
  one contained in _hash_, but one obtained from that by calling @map@ on it
  with a block which calls the method _convertion_ on each element
@param required (see #get_value)
@return [Array] the entry in _hash_ corresponding to _key_, wrapped in an array
  if it's not an array. If _key_ doesn't exist in _hash_, an empty array is
  returned, unless _required_ is *true*. If _conversion_ is not *nil*, the array
  is mapped using that method
@raise (see #get_value)
=end    
    def get_maybe_array hash, key, conversion = nil, required = false
      res = get_value( hash, key, [], required).to_array
      res = res.map{|i| i.send conversion} if conversion
      res
    end

=begin rdoc
Reads the @name@ entry from the PSF

@param [Hahs] the contents of the PSF
@param [Boolean] component whether or not the PSF is for a core component
@return [Symbol] the content of the @name@ entry converted to a symbol
@raise [PluginSpecification::PSFError] if _hash_ doesn't have a @name@ entry
  and _component_ is *true* (a core component doesn't have to have a name, but
  a plugin does)
=end    
    def read_name hash, component = false
      res = get_value(hash, :name, nil, !component)
      res ? res.to_sym : res
    end

=begin rdoc
Reads the @description@ entry from the PSF

@param [Hash] the contents of the PSF
@return [String] the @description@ entry of _hash_ converted to a string or
  an empty string if the entry doesn't exist
=end    
    def read_description hash
      get_value(hash, :description, '').to_s
    end

=begin rdoc
Reads the @class@ entry from the PSF

@param [Hash] the contents of the PSF
@param [Boolean] component *unused*
@return [Class,nil] the class object corresponding to @class@ entry of _hash_ or
  *nil* if that entry is set to *nil*. If The @class@ entry doesn't exist,
  the @Ruber::Plugin@ class is returned
@note for this method to work correctly, the file containing the definition of
  the class must already have been required, otherwise an exception will be raised
=end
    def read_class hash, component = false
      res = get_value(hash, :class, 'Ruber::Plugin')
      res ? constant(res.to_s) : nil
    end
    
=begin rdoc
Reads the @required@ entry from the PSF

@param [Hash] the contents of the PSF
@return [<String>] an array with all the files listed in the @required@ entry
  of the PSF. If the entry contained a string, it's wrapped in an array. If
  the entry doesn't exist, an empty array is returned
=end
    def read_required hash
      get_maybe_array hash, :require, :to_s
    end

=begin rdoc
Reads the @type@ entry from the PSF

@param [Hash] the contents of the PSF
@return [Symbol] the @type@ entry of the PSF converted to a symbol. It must
  have one of the following values: @:global@, @:library@, @:project@
@raise [PluginSpecification::PSFError] if the @type@ entry is missing or it
  doesn't contain an allowed value
=end
    def read_type hash
      val = get_value( hash, :type, nil, true).to_sym
      unless [:core, :library, :project, :global].include? val
        raise PluginSpecification::PSFError, "#{val} is not a valid value for the 'type' entry"
      end
      val
    end

=begin rdoc
Reads the @features@ entry from the PSF

@param [Hash] the contents of the PSF
@return [<Symbol>] an array with all the features listed in the @features@ entry
  of the PSF, plus an additional entry equal to the @name@ entry. If the @features@
  entry doesn't exist, the returned array only contains the additional entry.
  All entries are converted to symbols
=end
    def read_features hash
      res = get_maybe_array hash, :features, :to_sym
      name = get_value(hash, :name, nil)
      res.unshift name.to_sym if name
      res
    end
    
=begin rdoc
Reads the @deps@ entry from the PSF

@param [Hash] the contents of the PSF
@return [<Symbol>] an array with all the dependencies listed in the @deps@ entry
  of the PSF. It the entry contains a single string or symbol, it's wrapped in
  an array. If the @deps@ entry doesn't exist, an empty array is returned
  All entries are converted to symbols
=end
    def read_deps hash
      get_maybe_array hash, :deps, :to_sym
    end
    
=begin rdoc
@note Currently, runtime deps aren't implemented
Reads the @runtime_deps@ entry from the PSF

@param [Hash] the contents of the PSF
@return [<Symbol>] an array with all the dependencies listed in the @runtime_deps@ entry
  of the PSF. It the entry contains a single string or symbol, it's wrapped in
  an array. If the @runtime_deps@ entry doesn't exist, an empty array is returned
  All entries are converted to symbols
=end
    def read_runtime_deps hash
      get_maybe_array hash, :runtime_deps, :to_sym
    end

=begin rdoc
Reads the @ui_file@ entry from the PSF

@param [Hash] the contents of the PSF
@return [String] the name of the ui file specified in the @ui_file@ entry or
an empty string if the entry is missing.
=end
    def read_ui_file hash
      get_value( hash, :ui_file, '').to_s
    end

=begin rdoc
Reads the content of a PSF entry describing a widget

This method reads the following entries: @caption@, @pixmap@, @class_obj@,
@code@, @required@. The @pixmap@ and @caption@ can be marked as required, meaning
that if they aren't included in the hash, an exception will be raised. Exactly
one of the @code@ and @class_obj@ entries must always be specified.

@param [Hash] hash the hash containing the data for the widget
@param [<Symbol>] required the required entries. It can contain @:caption@
  and @:pixmap@
@return [Hash] a hash describing the widget
@raise [PluginSpecification::PSFError] if one of the entries contained in
  _required_ is missing or if both the @code@ and @class_obj@ exist or both are
  missing
=end
    def read_widget hash, required = []
      res = {}
      res[:caption] = get_value(hash, :caption, nil)
      pixmap = get_value(hash, :pixmap, @plugin_info.about.icon)
      if required.include? :pixmap and pixmap.empty?
        raise PluginSpecification::PSFError, "The :pixmap entry must be present in the widget description"
      end
      res[:pixmap] = pixmap_file pixmap
      cls = get_value(hash, :class, nil)
      res[:class_obj] = cls ? constant(cls) : nil
      res[:code] = get_value(hash, :code, nil)
      res[:required] = get_maybe_array hash, :required
      raise PluginSpecification::PSFError, "A widget description can't contain both the :class and "\
          "the :code entries" if res[:class_obj] and res[:code]
      raise PluginSpecification::PSFError, "Either the :class or the :code entry must be present in "\
          "the widget description" unless res[:class_obj] or res[:code]
      if required.include? :caption and !res[:caption]
        raise PluginSpecification::PSFError, "The :caption entry must be present in the widget description"
      elsif !res[:caption] then res[:caption] = ''
      end
      OpenStruct.new(res)
    end

=begin rdoc
Reads the @tool_widgets@ entry from the PSF

@param [Hash] the contents of the PSF
@return [<OpenStruct>] an array contaning the information about the tool widgets.
  If the PSF entry only contains a tool widget, it's inserted in an array. If
  the entry is missing, an empty array is returned.
=end    
    def read_tool_widgets hash
      res = get_value(hash, :tool_widgets, [])
      res.to_array.map do |a|
        o = read_widget a, [:pixmap, :caption]
        o.position = get_value(a, :position, :bottom).to_sym
        o.name = get_value(a, :name, o.caption).to_s
        o.var_name = get_value(a, :var_name, 'widget')
        o.var_name = o.var_name.to_s if o.var_name
        o
      end
    end

=begin rdoc
Reads the @config_widgets@ entry from the PSF

@param [Hash] the contents of the PSF
@return [<OpenStruct>] an array contaning the information about the config widgets.
  If the PSF entry only contains a tool widget, it's inserted in an array. If
  the entry is missing, an empty array is returned.
=end    
    def read_config_widgets hash
      res = get_value(hash, :config_widgets, [])
      res = res.to_array
      res.map{|h| read_widget h, [:caption]}
    end

=begin rdoc
Reads the @config_options@ entry from the PSF

@param [Hash] the contents of the PSF
@return [{[Symbol, Symbol] => Option}] a hash contaning the information about the config options.
  The keys of the hash are arrays containing the group and the name of the option,
  while values are {Option}s object. If the @config_options@ entry is missing
  from the PSF, an empty hash is returned.
=end
    def read_config_options hash
      hash = get_value(hash, :config_options, {})
      hash.inject({}) do |res, i|
        g, h = i
        g = g.to_sym
        h.each_pair{ |n, o| res[[g, n.to_sym]] = read_option g, n.to_sym, o}
        res
      end
    end
          
=begin rdoc
Reads the @project_options@ entry from the PSF

@param [Hash] the contents of the PSF
@return [{[Symbol, Symbol] => Option}] a hash contaning the information about the project options.
  The keys of the hash are arrays containing the group and the name of the option,
  while values are {Option}s object. If the @project_options@ entry is missing
  from the PSF, an empty hash is returned.
=end
    def read_project_options hash
      hash = get_value(hash, :project_options, {})
      hash.inject({}) do |res, i|
        g, h = i
        g = g.to_sym
        h.each_pair do |n, o| 
          op = read_option g, n.to_sym, o
          rules = read_rules o
          op = Option.new op.instance_variable_get(:@table).merge(rules)
          op.type = get_value(o, :type, :global).to_sym
          res[[g, n.to_sym]] = op
        end
        res
      end
    end
    
=begin rdoc
Reads the @config_options@ entry from the PSF

@param [Hash] the contents of the PSF
@return [{[Symbol, Symbol] => Option}] a hash contaning the information about the config options.
  The keys of the hash are arrays containing the group and the name of the option,
  while values are {Option}s object. If the @config_options@ entry is missing
  from the PSF, an empty hash is returned.
=end
    def read_option group, name, hash
      res = {:name => name.to_sym, :group => group.to_sym}
      default = get_value(hash, :default, nil)
      res[:relative_path] = get_value(hash, :relative_path, false)
      res[:eval_default] = get_value(hash, :eval_default, true)
      res[:default] = get_value(hash, :default, '')
      res[:order] = get_value(hash, :order, nil)
      d res if res.keys.any?{|k| k.nil?}
      Option.new res
    end


    def read_project_widgets hash
      res = get_value(hash, :project_widgets, []).to_array
      res = res.map do |h| 
        w = read_widget h, [:caption]
        rules = read_rules h
        w = Option.new w.instance_variable_get(:@table).merge(rules)
        w
      end
      res
    end


    def read_extensions hash
      hash = get_value(hash, :extensions, {})
      hash.inject({}) do |res, i|
        name, h= i[0].to_sym, i[1]
        ext = read_extension name, h
#         ext.scope = Array(get_value(h, :scope, [:global, :document])).map{|i| i.to_sym}
        res[name] = ext
        res
      end
    end

    def read_extension name, data
      if data.is_a? Array
        data.inject([]){|res, i| res << read_extension(name, i)}
      else
        res = {:name => name}
        res[:class_obj] = eval get_value(data, :class, nil, true)
        res.merge! read_rules(data)
        OpenStruct.new res
      end
    end
    
    def read_actions hash
      res = {}
      hash = get_value(hash, :actions, {})
      hash.each_pair do |name, data|
        name = name.to_s
        res[name] = read_action name.to_s, data
      end
      res
    end
    
    def read_action name, hash
      res = {}
      res[:name] = name
      unless res[:name]
        raise PluginSpecification::PSFError, "The required 'name' entry is missing from the PDF" 
      end
      res[:text] = get_value hash, :text, ''
      short = get_value hash, :shortcut, nil
      res[:shortcut] = short ? KDE::Shortcut.new(short) : nil
      res[:help] = get_value hash, :help, ''
      res[:icon] = pixmap_file get_value(hash, :icon, nil)
      cls = get_value(hash, :class, nil)
      std_action = get_value hash, :standard_action, nil
      if !cls and std_action
        res[:standard_action] = std_action.to_sym
      else res[:action_class] = constant(cls || 'KDE::Action')
      end
#       res[:delayed] = get_value hash, :delayed, false
      res[:receiver] = get_value hash, :receiver, 'self'
      res[:signal] = get_value hash, :signal, 'triggered(bool)'
      res[:slot] = get_value hash, :slot, nil
      res[:states] = get_value hash, :states, []
      res[:state] = get_value hash, :state, nil if res[:states].empty?
      OpenStruct.new res
    end

=begin rdoc
Finds the absolute file for the pixmap file _pixmap_. In particular, if a file 
called _pixmap_ exists in the plugin directory, the full path of that file is returned.
If such a file doesn't exist, then <tt>KDE::IconLoader</tt> is used to find the
path. If <tt>KDE::IconLoader</tt> also fails, an empty string is returned.

If the application hasn't been created yet, this method always returns the absolute path
of the file as if it were in the plugin directory (this happens because <tt>KDE::IconLoader</tt>
can't be used if the application hasn't been created)
=end
    def pixmap_file pixmap
      if pixmap
        pix_file = File.join( @plugin_info.directory || Dir.pwd, pixmap)
        if File.exist?( pix_file ) or !KDE::Application.instance then pix_file
        else KDE::IconLoader.pixmap_path(pixmap) || ''
        end
      else ''
      end
    end
      
    def read_human_name hash
      res = get_value hash, :human_name, nil
      res || @plugin_info.name.to_s.sub('_', ' ').capitalize
    end
    
    def read_authors hash
      res = get_value hash, :authors, []
      res = if res.is_a? Array and (res.empty? or res[0].is_a? Array) then res
      elsif res.is_a? Array then [res]
      else raise PluginSpecification::PSFError, 'The "authors" entry in the PDF should be an array'
      end
      res.each{|a| a << '' if a.size == 1}
      res
    end
    
    def read_license hash
      res = get_value hash, :license, :unknown
      if LICENSES.include? res.to_sym then res.to_sym
      elsif res.is_a? String then res
      else raise PluginSpecification::PSFError, "Invalid licese type :#{res}" 
      end
    end
    
    def read_version hash
      get_value hash, :version, '0.0.0'
    end
    
    def read_bug_address hash
      get_value hash, :bug_address, ''
    end
    
    def read_copyright hash
      get_value hash, :copyright, ''
    end
    
    def read_homepage hash
      res = get_value hash, :homepage, ''
      unless res.empty? or res.match(%r{^http://})
        res = 'http://'+res
      end
      res
    end
    
    def read_icon hash
      res = get_value(hash, :icon, nil)
      res ? pixmap_file(res) : ''
    end
    
    def read_rules hash
      res = {}
      scope = Array(get_value hash, :scope, [:global]).map &:to_sym
      scope = [:global, :document] if scope == [:all]
      res[:scope] = scope
      place = Array(get_value hash, :place, [:local]).map &:to_sym
      res[:place] = (place.include?(:all) ? [:local, :remote] : place)
      res[:mimetype] = Array(get_value(hash, :mimetype, []))
      res[:file_extension] = Array(get_value(hash, :file_extension, []))
      res
    end
    
    def read_about hash
      res = {}
      hash = get_value hash, :about, {}
      res[:human_name] = read_human_name hash
      res[:authors] = read_authors hash
      res[:license] = read_license hash
      res[:bug_address] = read_bug_address hash
      res[:copyright] = read_copyright hash
      res[:homepage] = read_homepage hash
      res[:description] = read_description hash
      res[:icon] = read_icon hash
      # Sometimes, an exception is raised because sometimes, when loading plugins,
      # I get an exception where OpenStruct complains because of a nil key. It
      # happens randomly, however. Let's see whether this removes the error and
      # makes clearer why it's happening
      if res.has_key? nil
        deleted_value = res.delete nil
      msg = <<-EOS 
This is information for Ruber developers only. Unless you aren't one of them, you can close and ignore this message box.

One of the entries of the about hash in the PSF was nil. The corresponding value was: #{deleted_value.inspect}"
        EOS
        KDE::MessageBox.information nil, deleted_value.inspect
      end
      begin OpenStruct.new res
      rescue Exception
        puts "The following exception occurred while reading the About data for #{@plugin_info.plugin_name}.\nThe contents of the hash was: #{res.inspect}"
        raise
      end
    end
    
  end
    
end
