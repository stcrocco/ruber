=begin 
    Copyright (C) 2011 by Stefano Crocco   
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

require 'set'
require 'find'
require 'delegate'

require 'kio'

module Ruber
  
  class ProjectDirScanner < Qt::Object
    
    signals :rules_changed
    
    signals 'file_added(QString)'
    
    signals 'file_removed(QString)'
    
    def initialize prj
      super
      @project = prj
      #The /? at the end is there to avoid depending on whether Project#project_directory
      #returns a string ending with / or not
      @regexp = %r[^#{Regexp.quote @project.project_directory}/?]
      make_rules
      @watcher = KDE::DirWatch.new self do
        add_dir prj.project_directory, 
            KDE::DirWatch::WatchFiles | KDE::DirWatch::WatchSubDirs
      end
      @watcher.connect(SIGNAL('created(QString)')) do |f|
        emit file_added(f) if file_in_project? f
      end
      @watcher.connect(SIGNAL('deleted(QString)')) do |f|
        emit file_removed(f) if file_in_project? f
      end
      @project.connect(SIGNAL('option_changed(QString, QString)')) do |g, n|
        if g == 'general' and n == 'project_files'
          if @project[:general, :project_files] != @rules
            make_rules
            emit rules_changed
          end
        end
      end
      @watcher.start_scan false
    end
    
    def file_in_project? file
      if file.start_with? '/'
        file = file.dup
        return false unless file.sub! @regexp, ''
      end
      return nil if file.end_with? '/'
      if file =~ %r{^([\w+-.]+)://(.+)}
        if $1 == 'file' then file = $2
        else return false
        end
      end
      return false if @exclude_regexp =~ file
      return false if @exclude_files.include? file
      return true if @extensions.any?{|e| File.fnmatch?(e, file, File::FNM_DOTMATCH)}
      return true if @include_regexp =~ file or @include_files.include? file
      false
    end
    
    def project_files
      res = Set.new
      dir = @project.project_directory
      Ruber[:app].chdir dir do
        Find.find '.' do |f|
          next if File.directory? f
          #remove the leading './'
          f = f[2..-1]
          res << File.join(dir, f) if file_in_project? f
        end
      end
      res
    end
    
    private
    
    def make_rules
      rules = @project[:general, :project_files]
      @include_regexp = Regexp.union(*(rules[:include].select{|r| r.is_a?(Regexp)}))
      @exclude_regexp = Regexp.union(*(rules[:exclude].select{|r| r.is_a?(Regexp)}))
      @exclude_files = rules[:exclude].select{|rule| rule.is_a? String}.map{|f| f.sub(%r{^\./}, '')}
      @include_files = rules[:include].select{|rule| rule.is_a? String}.map{|f| f.sub(%r{^\./}, '')}
      @include_files-= @exclude_files
      @extensions = rules[:extensions]
      @rules = YAML.load(YAML.dump rules)
    end
    
  end
  
  class ProjectFiles < Delegator
    
    include Enumerable
    
    def initialize project_dir, set
      super set
      @set = set
      @project_dir = project_dir.dup
      @project_dir << '/' unless @project_dir.end_with? '/'
    end
    
    def __getobj__
      @set
    end
    
    def __setobj__ obj
      @set = obj
    end
    
    def dup
      self.class.new @project_dir, @set
    end
    
    def clone
      res = dup
      dup.freeze if frozen?
      res
    end
    
    def to_set
      Set.new self
    end
    
    def each_relative
      if block_given?
        l = @project_dir.size
        @set.each{|f| yield f[l, f.size-l]}
      else self.to_enum :each_relative
      end
    end
    alias_method :rel, :each_relative
    
    def each
      if block_given?
        @set.each{|f| yield f}
      else self.to_enum
      end
    end
    alias_method :abs, :each
    
    [:<<, :add, :clear, :collect!, :delete, :delete_if, :flatten!, :keep_if,
        :map!, :merge, :reject!, :replace, :subtract].each do |m|
      define_method m do |*args|
        raise NoMethodError
      end
    end
        
  end
  
end
