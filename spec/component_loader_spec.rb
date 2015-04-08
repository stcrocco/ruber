require 'spec/common'
require 'ruber/component_manager/component_loader'
require 'ruber/plugin_specification'
require 'ruber/plugin'

require 'find'

describe Ruber::ComponentLoader do

  def create_plugins
    tree = [
      ['d1', ['p1', 'plugin.yaml'], ['p2', 'plugin.yaml']],
      ['d2', ['p3', 'plugin.yaml'], ['p4', 'plugin.yaml']]
    ]
    contents = {
      'd1/p1/plugin.yaml' => '{name: p1, type: global }',
      'd1/p2/plugin.yaml' => '{name: p2, type: global}',
      'd2/p3/plugin.yaml' => '{name: p3, type: global}',
      'd2/p4/plugin.yaml' => '{name: p4, type: global}',
    }
    @dir = make_dir_tree tree, '/tmp', contents
    @plugins = Find.find(@dir).map do |f|
      if f.end_with? '.yaml' then Ruber::PluginSpecification.full f
      else nil
      end
    end
    @plugins.compact!
#     @dirs = %w[d1 d2].map{|d| File.join @dir, d}
#     exp = {:p1 => 'd1/p1', :p2 => 'd1/p2', :p3 => 'd2/p3', :p4 => 'd2/p4'}
#     @exp = exp.map{|p, d| [p, File.join(@dir, d, 'plugin.yaml')]}.to_h
  end

  context 'When created' do

    before do
      create_plugins
    end

    it 'takes a hash with the keys :library, :global and :project and a list of availlable plugins' do
      hash = {:library => flexmock, :global => flexmock, :project => flexmock}
      lambda{Ruber::ComponentLoader.new @plugins, hash}.should_not raise_error
    end

    it 'raises ArgumentError if the hash doesn\'t have a :library entry' do
      hash = { :global => flexmock, :project => flexmock}
      lambda{Ruber::ComponentLoader.new @plugins, hash}.should raise_error(ArgumentError, "missing library plugins manager")
    end

    it 'raises ArgumentError if the hash doesn\'t contain at least one of the :project or :global entries' do
      hash = {:library => flexmock}
      lambda{Ruber::ComponentLoader.new @plugins, hash}.should raise_error(ArgumentError, "both global and project plugins manager are missing")
    end

    it 'doesn\'t raise errors if only one of the :project or :global entry is missing' do
      hash = { :library => flexmock, :global => flexmock, :project => flexmock}
      lambda{Ruber::ComponentLoader.new @plugins, hash.reject{|k, v| k == :project}}.should_not raise_error
      lambda{Ruber::ComponentLoader.new @plugins, hash.reject{|k, v| k == :global}}.should_not raise_error
    end

  end

  describe '#set_plugins' do

    before do
      create_plugins
      @library_manager = flexmock 'library_manager'
      @project_manager = flexmock 'project_manager'
      @loader = Ruber::ComponentLoader.new @plugins, :library => @library_manager,
          :project => @project_manager
    end

    it 'takes a list of PluginSpecification objects as argument' do
      lambda{@loader.set_plugins @plugins.sample(3)}.should_not raise_error
    end
   
  end

  describe '#load_component' do

    before do
      create_plugins
      @loader = Ruber::ComponentLoader.new :global, @plugins
    end

    it 'takes the name of the component to load as argument' do
      lambda{@loader.load_component @plugins[0].plugin_name}.should_not raise_error
    end



  end


end
