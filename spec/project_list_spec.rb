require './spec/framework'
require './spec/common'
require 'ruber/world/project_list'
require 'ruber/project'

require 'tmpdir'

describe Ruber::World::ProjectList do
  
  def create_project file, name = nil
    name ||= file.sub(/[_-]/, ' ').sub('.ruprj','').capitalize
    file = File.join Dir.tmpdir, file unless file.start_with? '/'
    file += '.ruprj' unless file.end_with?('ruprj')
    Ruber::Project.new file, name
  end
  
  before do
    @projects = 3.times.map{|i| create_project "project-#{i}"}
    @list = Ruber::World::ProjectList.new @projects
  end
  
  it 'includes the Enumerable module' do
    Ruber::World::ProjectList.ancestors.should include(Enumerable)
  end
  
  describe '.new' do
    
    it 'takes a hash or a DocumentList as argument' do
      list = Ruber::World::ProjectList.new @projects
      list.to_a.map(&:project_file).sort == @projects.map(&:project_file).sort
      other_list = Ruber::World::ProjectList.new @projects
      list = Ruber::World::ProjectList.new other_list
      list.to_a.map(&:project_file).sort == @projects.map(&:project_file).sort
    end
    
    it 'creates a duplicate of the argument if it is a hash' do
      list = Ruber::World::ProjectList.new @projects
      new_project = create_project 'project-3'
      @projects <<  new_project
      list.count.should == 3
    end
    
    it 'doesn\'t create a duplicate of the argument if it is a ProjectList' do
      other_list = Ruber::World::ProjectList.new @projects
      list = Ruber::World::ProjectList.new other_list
      list.send(:project_hash).should equal(other_list.send(:project_hash))
    end
    
    it 'keeps a single copy of projects with the same project file' do
      @projects << create_project('project-1')
      @list = Ruber::World::ProjectList.new @projects
      @list.to_a.select{|prj| prj.project_name == "Project 1"}.count.should == 1
    end
    
  end
  
  describe '#each' do
    
    context 'when called with a block' do
      
      it 'calls the block once for each project' do
        res = []
        @list.each{|prj| res << prj}
        res.should == @projects
      end
      
      it 'returns self' do
        @list.each{}.should equal(@list)
      end
      
    end
    
    context 'when called without a block' do
      
      it 'returns an Enumerator which iterates on the projects' do
        res = []
        enum = @list.each
        enum.should be_an(Enumerator)
        enum.each{|prj| res << prj}
        res.should == @projects
        
      end
      
    end
    
  end
  
  describe '#empty?' do
    
    it 'returns true if the list doesn\'t contain any element' do
      list = Ruber::World::ProjectList.new({})
      list.should be_empty
    end
    
    it 'returns false if the list contains at least one element' do
      @list.should_not be_empty
    end
    
  end
  
  describe '#size' do
    
    it 'returns the number of elements in the list' do
      list = Ruber::World::ProjectList.new({})
      list.size.should == 0
      list = Ruber::World::ProjectList.new @projects
      list.size.should == 3
    end
    
  end
  
  describe '#==' do
    
    context 'when the argument is a ProjectList' do
          
      it 'returns true if the argument contains the same projects' do
        other = Ruber::World::ProjectList.new @projects
        @list.should == other
      end
      
      it 'returns false if the argument contains different projects' do
        new_prj = create_project 'project-3'
        @projects << new_prj
        other = Ruber::World::ProjectList.new @projects
        @list.should_not == other
      end
      
    end
    
    context 'when the argument is an Array' do
      
      it 'returns true if the argument contains the same projects' do
        @list.should == @projects.reverse
      end
      
      it 'returns false if the argument contains different projects' do
        @list.should_not == [@projects[0], 'x']
      end
      
    end
    
    context 'when the argument is neither a ProjectList nor an array' do
      
      it 'returns false' do
        @list.should_not == {}
        @list.should_not == 'x'
      end
      
    end
    
  end
  
  describe '#eql?' do
    
    context 'when the argument is a ProjectList' do
      
      it 'returns true if the argument contains the same projects' do
        other = Ruber::World::ProjectList.new @projects
        @list.should eql(other)
      end
      
      it 'returns false if the argument contains different projects' do
        new_prj = create_project 'project-3'
        @projects << new_prj
        other = Ruber::World::ProjectList.new @projects
        @list.should_not eql(other)
      end
      
    end
    
    context 'when the argument is not a ProjectList' do
      
      it 'returns false' do
        @list.should_not eql({})
        @list.should_not eql('x')
        @list.should_not eql(@projects)
      end
      
    end
    
  end
  
  describe '#hash' do
    
    it 'returns the same value as an hash contining the same arguments' do
      @list.hash.should == Hash[@projects.map{|prj| [prj.project_file, prj]}].hash
    end
    
  end

  describe "#[]" do
    
    context 'if the argument starts with a slash' do
      
      it 'retuns the project associated witt the given file' do
        @list[@projects[0].project_file].should == @projects[0]
      end
      
      it 'returns nil if there\'s no project in the list associated with the given file' do
        @list['/xyz.ruprj'].should be_nil
      end
      
    end
    
    context 'if the argument doesn\'t start with a slash' do
      
      it 'returns the project having the argument as project name' do
        name = 'Project 1'
        @list[name].project_name.should == 'Project 1'
      end
      
      it 'returns nil if there\'s no project with the given name in the list' do
        @list['xyz'].should be_nil
      end
      
    end
    
  end
  
end

describe Ruber::World::MutableProjectList do
  
  def create_project file, name = nil
    name ||= file.sub(/[_-]/, ' ').sub('.ruprj','').capitalize
    file = File.join Dir.tmpdir, file unless file.start_with? '/'
    file += '.ruprj' unless file.end_with?('ruprj')
    Ruber::Project.new file, name
  end
  
  before do
    @projects = 3.times.map{|i| create_project "project-#{i}"}
    @list = Ruber::World::MutableProjectList.new
  end
  
  it 'inherits from Ruber::World::ProjectList' do
    Ruber::World::MutableProjectList.ancestors.should include(Ruber::World::ProjectList)
  end
  
  describe '#initialize' do
    
    context 'when called with no arguments' do
      
      it 'creates an empty list' do
        @list.should be_empty
      end
      
    end
    
    context 'when called with an array as argument' do
      
      it 'creates a list containing the same projects as the argument' do
        @list = Ruber::World::MutableProjectList.new @projects
        @list.to_a.sort_by{|prj| prj.object_id}.should == @projects.sort_by{|prj| prj.object_id}
      end
      
      it 'creates a duplicate of the argument' do
        @list = Ruber::World::MutableProjectList.new @projects
        new_prj = create_project 'project-4'
        @projects << new_prj
        @list.size.should == 3
      end
      
    end
    
    context 'when called with a ProjectList as argument' do
      
      it 'creates a list containing the same documents as the argument' do
        orig = Ruber::World::ProjectList.new @projects
        @list = Ruber::World::MutableProjectList.new orig
        @list.to_a.should == @projects
      end
      
      it 'creates a duplicate of the argument' do
        orig = Ruber::World::ProjectList.new @projects
        @list = Ruber::World::MutableProjectList.new orig
        new_prj = create_project 'project-4'
        orig.send(:project_hash)[new_prj.project_file] = new_prj
        @list.size.should == 3
      end
      
    end
    
  end
  
  describe '#dup' do
    
    it 'duplicates the document list' do
      @list.add @projects
      new_list = @list.dup
      new_list.remove @projects[1]
      @list.should == @projects
    end
    
  end
  
  describe '#clone' do
    
    it 'duplicates the document list' do
      @list.add @projects
      new_list = @list.clone
      new_list.remove @projects[1]
      @list.should == @projects
    end
    
    it 'copies the frozen status of the project list' do
      @list.freeze
      new_list = @list.clone
      new_list.should be_frozen
      lambda{new_list.add create_project('project-4')}.should raise_error(RuntimeError)
    end
    
  end
  
  describe '#add' do
    
    it 'appends the given projects to the list' do
      @list.add @projects[0]
      @list.to_a.should == [@projects[0]]
      @list.add *@projects[1..-1]
      @list.to_a.should == @projects
    end
    
    it 'treats arrays of projects as if each project was an argument by itself' do
      @list.add @projects
      @list.to_a.should == @projects
    end
    
    it 'returns self' do
      @list.add(@projects).should equal(@list)
    end
    
  end
  
  describe '#merge!' do
    
    before do
      @projects = 5.times.map{|i| create_project "project-#{i}"}
      @list.add @projects[3..4]
    end
    
    it 'adds the contents of the argument to self' do
      other = Ruber::World::MutableProjectList.new @projects[0..2]
      @list.merge!(other)
      @list.should == @projects[3..4]+@projects[0..2]
    end
    
    it 'also works with an array argument' do
      @list.merge!(@projects[0..2])
      @list.should == @projects[3..4]+@projects[0..2]
    end
    
    it 'returns self' do
      @list.merge!(@projects[0..2]).should equal(@list)
    end
    
  end
  
  describe '#remove' do
    
    before do
      @list.add @projects
    end
    
    it 'removes the project from the list' do
      @list.remove @projects[1]
      @list.to_a.should == [@projects[0], @projects[2]]
    end
    
    it 'does nothing if the project is not in the list' do
      @list.remove create_project('project-4')
      @list.to_a.should == @projects
    end
    
    it 'returns the removed document, if any' do
      @list.remove(@projects[1]).should == @projects[1]
    end
    
    it 'returns nil if no document was removed' do
      @list.remove(create_project('project-4')).should be_nil
    end
    
  end
  
  describe '#clear' do
    
    it 'removes all elements from the list' do
      @list.add @projects
      @list.clear
      @list.should be_empty
    end
    
    it 'returns self' do
      @list.clear.should equal(@list)
    end
    
  end
  
  describe '#delete_if' do
    
    before do
      @list.add @projects
    end
    
    it 'removes all the elements for which the block returns true' do
      @list.delete_if{|prj| prj.project_name == 'Project 1'}
      @list.should == [@projects[0], @projects[2]]
    end
    
    it 'returns self' do
      @list.delete_if{|prj| prj.project_name == 'Project 1'}.should equal(@list)
    end
    
  end
  
end