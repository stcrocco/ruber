require 'set'
require 'ruber/dependent'

Plugin = Struct.new :name, :features, :deps

class Plugin
  
  def initialize name, features = [], deps = []
    features << (name.to_s + 'F').to_sym
    super    
  end
  
end

describe 'Dependent::Solver#solve' do
  
  before do
    @solver = Dependent::Solver.new
  end
  
  it 'takes a list of objects to load and a list of availlable features' do
    to_load = Array.new(3){|i| Plugin.new i.to_s.to_sym}
    avail = Array.new(5){|i| Plugin.new i.to_s.to_sym}
    lambda{@solver.solve to_load, avail}.should_not raise_error
  end
  
  it 'can accept an optional list of extra objects' do
    to_load = Array.new(3){|i| Plugin.new i.to_s.to_sym}
    avail = Array.new(5){|i| Plugin.new i.to_s.to_sym}
    extra = Array.new(3){|i| Plugin.new (i+10).to_s.to_sym}
    lambda{@solver.solve to_load, avail, extra}.should_not raise_error
  end
  
  it 'returns an array of Dependent::Solution' do
    to_load = Array.new(3){|i| Plugin.new i.to_s.to_sym}
    avail = Array.new(5){|i| Plugin.new i.to_s.to_sym}
    res = @solver.solve to_load, avail
    res.should be_an(Array)
    res.should_not be_empty
    res.each{|x| x.should be_a(Dependent::Solution)}
  end
  
  context 'when the plugins to load have no dependencies' do
    
    before do
      @to_load = [Plugin.new(:x), Plugin.new(:q), Plugin.new(:p)]
      @avail = ('a'..'z').map{|x| Plugin.new x.to_sym}
      @res = @solver.solve @to_load, @avail
    end
    
    it 'returns an array of Dependent::Solution corresponding to the given plugins in alphabetical order' do
      to_load_sorted = @to_load.sort_by{|pl| pl.name.to_s}
      @res.map{|s| s.name}.should == to_load_sorted.map(& :name)
      @res.each_index{|i| @res[i].object.should == to_load_sorted[i]}
    end
    
    it 'leaves the dependencies attribute of the solutions empty' do
      @res.each{|s| s.dependencies.should be_empty}
    end
    
    it 'sets the required_by attribute of the solutions to [nil]' do
      @res.each{|s| s.required_by.should == [nil]}
    end
    
  end
  
  context 'when the plugins to load depend on each other' do
    
    before do
      names = ('a'..'g').map{|l| l.to_sym}
      deps = {
        :d => [:fF],
        :f => [:gF],
        :b => [:cF, :aF, :dF]
      }
      plugins = Hash[names.map{|n| [n, Plugin.new(n, [], (deps[n] || []))]}]
      @to_load = plugins.values
      @to_load_sorted = [
        plugins[:a], plugins[:c], plugins[:e], plugins[:g], plugins[:f], 
        plugins[:d], plugins[:b]
      ]
      @avail = @to_load + ('h'..'z').map{|x| Plugin.new x.to_sym}
      @res = @solver.solve @to_load, @avail
    end
    
    it 'returns the solutions for the plugins so that the solution for a plugin comes after those for the plugins it depends upon' do
      @res.map(&:name).should == @to_load_sorted.map(&:name)
    end
    
    it 'inserts the names of the plugins requiring a given plugin in the required_by attribute of the corresponding solution object' do
      res = Hash[@res.map{|s| [s.name, s.required_by.map{|x| x ? x.name : nil}]}]
      res[:a].should =~ [:b, nil]
      res[:b].should == [nil]
      res[:c].should =~ [:b, nil]
      res[:d].should =~ [:b, nil]
      res[:e].should == [nil]
      res[:f].should =~ [:d, :b, nil]
      res[:g].should =~ [:f, :d, :b, nil]
    end
    
    it 'inserts the names of the plugins each plugin depends upon in the dependencies attribute of the corresponding solution object' do
      res = Hash[@res.map{|s| [s.name, s.dependencies.map(&:name)]}]
      res[:a].should be_empty
      res[:b].should =~ [:a, :c, :d, :f, :g]
      res[:c].should be_empty
      res[:d].should =~ [:f, :g]
      res[:e].should be_empty
      res[:f].should =~ [:g]
      res[:g].should be_empty
    end
    
  end
  
  context 'when the plugins to load depend features provided by other plugins to load' do
    
    before do
      names = ('a'..'g').map{|l| l.to_sym}
      features = {
        :a => [:r],
        :c => [:s],
        :d => [:t],
        :f => [:u],
        :g => [:w]
      }
      deps = {
        :d => [:u],
        :f => [:w],
        :b => [:c, :r, :t]
      }
      plugins = Hash[names.map{|n| [n, Plugin.new(n, [], (deps[n] || []))]}]
      plugins.each_pair{|k, v| v.features.concat ((features[k] || []) + [k])}
      @to_load = plugins.values
      @to_load_sorted = [
        plugins[:a], plugins[:c], plugins[:e], plugins[:g], plugins[:f], 
        plugins[:d], plugins[:b]
      ]
      @avail = @to_load + ('h'..'z').map{|x| Plugin.new x.to_sym}
      @res = @solver.solve @to_load, @avail
    end
    
    it 'returns the solutions for the plugins so that the solution for a plugin comes after those for the plugins it depends upon' do
      @res.map(&:object).should == @to_load_sorted
    end
    
    it 'inserts the names of the plugins requiring a given plugin in the required_by attrobute of the corresponding solution object' do
      res = Hash[@res.map{|s| [s.name, s.required_by.map{|x| x ? x.name : nil}]}]
      res[:a].should =~ [:b, nil]
      res[:b].should == [nil]
      res[:c].should =~ [:b, nil]
      res[:d].should =~ [:b, nil]
      res[:e].should == [nil]
      res[:f].should =~ [:d, :b, nil]
      res[:g].should =~ [:f, :d, :b, nil]
    end
    
    it 'inserts the names of the plugins each plugin depends upon in the dependencies
    attribute of the corresponding solution object' do
      res = Hash[@res.map{|s| [s.name, s.dependencies.map(&:name)]}]
      res[:a].should be_empty
      res[:b].should =~ [:a, :c, :d, :f, :g]
      res[:c].should be_empty
      res[:d].should =~ [:f, :g]
      res[:e].should be_empty
      res[:f].should =~ [:g]
      res[:g].should be_empty
    end
    
  end
  
  context 'when more than one of the plugins to load provides a given feaure' do
    
    before do
      names = ('a'..'g').map{|l| l.to_sym}
      features = {
        :a => [:r],
        :c => [:s],
        :d => [:r],
        :f => [:u],
        :g => [:w]
      }
      @plugins = Hash[names.map{|n| [n, Plugin.new(n)]}]
      @plugins.each_pair{|k, v| v.features.concat (features[k] || [])}
      @to_load = @plugins.values
      @avail = @to_load + ('h'..'z').map{|x| Plugin.new x.to_sym}
    end
    
    it 'raise Solver::DuplicateFeatureError' do
      prc = lambda{@solver.solve @to_load, @avail}
      prc.should raise_error(Dependent::Solver::DuplicateFeatureError)
    end
    
    it 'includes the duplicate features and the plugins providing them in the features attribute of the exception' do
      begin @solver.solve @to_load, @avail
      rescue Dependent::Solver::DuplicateFeatureError => e
        duplicates = e.features
      end
      duplicates.keys.should == [:r]
      duplicates.values.flatten.map(&:name).should =~ [:a, :d]
    end
    
  end

  context 'when the selection process includes uneeded dependencies' do

    before do
      names = ('a'..'g').map{|l| l.to_sym}
      features = {
        :b => [:aF]
      }
      deps = {
        :a => [:cF, :dF],
        :x => [:aF],
        :y => [:bF]
      }
      plugins = ('a'..'z').map do |n|
        n = n.to_sym
        pl = Plugin.new n, features[n] || [], deps[n] || []
        [n, pl]
      end
      plugins = Hash[plugins]
      @avail = plugins.values
      @to_load = [plugins[:x], plugins[:y]]
    end

    it 'doesn\'t include them in the result' do
      res = @solver.solve(@to_load, @avail)
      res.map! &:name
      [:a, :c, :f].each{|n| res.should_not include(n)}
      res.should =~ [:x, :y, :b]
    end

  end
  
  context 'when some plugins depend on features not provided by the plugins to load' do
    
    before do
      names = ('a'..'g').map{|l| l.to_sym}
      deps = Hash.new([])
      deps[:a] = [:zF]
      deps[:f] = [:hF]
      @to_load = names.map{|n| Plugin.new n, [], deps[n]}
      @to_load.each &:freeze
      @avail = @to_load + ('h'..'z').map{|x| Plugin.new x.to_sym}
    end
    
    it 'adds a plugin providing the required feature from the list of availlable plugins' do
      res = @solver.solve @to_load, @avail
      exp = [:b, :c, :d, :e, :g, :h, :z, :a, :f]
      res.map{|s| s.name}.should == exp
    end
    
  end

  context 'when a requried feature isn\'t provided by any plugin' do

    before do
      names = ('a'..'g').map{|l| l.to_sym}
      deps = Hash.new([])
      deps[:a] = [:xxxF]
      deps[:f] = [:yyyF]
      @to_load = names.map{|n| Plugin.new n, [], deps[n]}
      @to_load.each &:freeze
      @avail = @to_load + ('h'..'z').map{|x| Plugin.new x.to_sym}
    end

    it 'raises an UnresolvedDependencies exception' do
      lambda{@solver.solve(@to_load, @avail)}.should raise_error Dependent::Solver::UnresolvedDependencies
    end

    it 'stores a list of failed dependencies in the exception\'s missing_features attribute' do
      begin @solver.solve @to_load, @avail
      rescue Dependent::Solver::UnresolvedDependencies => e
        e.missing_features.should =~ [:xxxF, :yyyF]
      end
    end

  end

  context 'when there are circular dependencies' do

    before do
      names = ('a'..'g').map{|l| l.to_sym}
      deps = Hash.new([])
      deps[:a] = [:bF]
      deps[:b] = [:cF]
      deps[:c] = [:aF]
      deps[:e] = [:dF]
      deps[:d] = [:eF]
      @to_load = names.map{|n| Plugin.new n, [], deps[n]}
      @to_load.each &:freeze
      @avail = @to_load + ('h'..'z').map{|x| Plugin.new x.to_sym}
    end

    it 'raises CircularDependencies exception' do
      lambda{@solver.solve(@to_load, @avail)}.should raise_error Dependent::Solver::CircularDependencies
    end

    it 'stores a list of circular dependencies in the exception\'s dependencies attribute' do
      begin @solver.solve(@to_load, @avail)
      rescue Dependent::Solver::CircularDependencies => e
        deps = e.dependencies.dup
        deps.map!{|a| a.map{|s| s.name}}
        deps.should =~ [[:a, :b, :c, :a], [:d, :e, :d]]
      end
    end

  end
  
end
