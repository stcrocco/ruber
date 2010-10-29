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

require 'thread'
require 'facets/kernel/deep_copy'
require 'find'

require 'ruber/project'

module Ruber
  
=begin rdoc
Project extension to access the name of the files belonging to the project.

The file belonging to the projects are determined using the contents of the @general/project_files@
project option. This option is a hash which contains rules (in the form of hashes)
telling which files are part of the project and which aren't.

Files are kept up to date, both regarding the contents of the filesystem (using a
KDE::DirWatch) and the rules specified in the project.

To avoid needlessly freezing the application in case projects with a large number of files,
this class only scans the project directory when a list of project files is actually
requested, that is when one of the methods {#each}, {#abs}, {#rel} and {#project_files}
is called. Even in that case, the project directory is only scanned if a file has
been added or removed since the last scan, or if the rules have changed since then.
A scan can be forced by using the {#update} method, but you usually don't need this.

h3. Rules

The @general/project_files@ setting is a hash containing the rules to use to decide
whether a given file belongs to the project or not. There are two groups of rules:
inclusive rules and exclusive rules. Inclusive rules specify files which belong
to the project, while exclusive rules specify files which do not belong to the 
project. Exclusive rules have precedence on inclusive rules, meaning that if a
file matches both an inclusive and an exclusive rule, it's excluded from the project.

There are three kinds of rules:


Project extension which scans the project directory and finds out which files belong
to the project and which don't (according to rules specified by the user in the
project options), returning an array of the former.

It also watches the project directory to update the list of project files when a
file in the project directory is added or removed.

This class provides an {#each} method, which yields all the project files to the
block or, if called without a block, returns an <tt>Enumerable::Enumerator</tt>
which does the same.

<b>Note:</b> the list of project files is created lazily, only when a method
explicitly needs it and a file or directory (or the rules) have changed since
the last time it was generated. A <tt>KDE::DirWatch</tt> object is used to find
out when a file or directory changes. Also, after a file has changed, the watcher
is stopped until the list is updated again (a single change is enough to rebuild
the whole list, so there's no point in keeping watching).

The methods which can cause the list to be rebuild are: +each+, +abs+, +rel+ and 
<tt>project_files</tt>.

===Rules
To decide whether a file belongs to the project or not, ProjectFilesList uses
the general/project_files project option. It is a hash made of three keys, each
specifying a rule telling whether a file is part of the project or not. In application
order, they are
<tt>extensions</tt>::
  an array of shell globs. Any file matching one of them (according to <tt>File.fnmatch</tt>)
  will be considered a project file, unless another rule says otherwise
<tt>include</tt>::
  an array of strings and/or regexps corresponding to files which belong to the
  project. Each string entry is the name (relative to the project directory) of
  a file which belongs to the project. Each regexp is a pattern which should be
  tested against all the names (still relative to the project directory) of the
  files in the project directory (and its subdirectories). Each matching file will
  be a project file (unless another rule says otherwise).
<tt>exclude</tt>::
  as the <tt>include</tt> entry, but the matching files will *not* be project
  files. This entry has the precedence with respect to the other two. This means
  that if a file is a project file according to one of them but also matches a
  rule here, it <i>won't</i> be considered a project file.
=end
  class ProjectFilesList < Qt::Object
    
    include Enumerable
    
    include Extension
    
=begin rdoc
Creates a new ProjectFilesList for the Project _prj_.

The new object will read the <tt>general/project_files</tt> option from the project
and immediately scan the project directory to find the all the project files.
Besides, it will start monitoring the directory for changes, so as to be
able to update the list of project files when a new file is created or a file
is deleted.
=end
    def initialize prj
      super
      @lock = Mutex.new
      @project = prj
      @project_files = nil
      @watcher = KDE::DirWatch.new self
      @watcher.add_dir @project.project_dir, KDE::DirWatch::WatchSubDirs
      @up_to_date = false
      make_rules
      @project_files = []
      @watcher.connect(SIGNAL('dirty(QString)')) do
        @up_to_date = false
        @watcher.stop_scan
      end
      @project.connect(SIGNAL('option_changed(QString, QString)')) do |g, n|
        if g == 'general' and n == 'project_files'
          if @project[:general, :project_files] != @rules
            @up_to_date = false
            make_rules
            scan_project
          end
        end
      end
      @watcher.start_scan false
    end
    
=begin rdoc
Returns an array with the name of the files in the project (in arbitrary order).
If _abs_ is *false*, the file names will be relative to the project directory;
if it is *true* they'll be absolute. It is the same as calling <tt>list.abs.to_a</tt>
or <tt>list.rel.to_a</tt>

<b>Note:</b> if the list isn't up to date, the project will be re-scanned
=end
    def project_files abs = true
      refresh unless @up_to_date
      if abs
        dir = @project.project_dir
        @project_files.map{|f| File.join dir, f}
      else @project_files.deep_copy
      end
    end
    
=begin rdoc
If called with a block, calls the block yielding the names of the files in the
project. If _abs_ is true, absolute file names will be used, otherwise the file
names will be relative to the project directory.

If called without a block, returns an <tt>Enumerable::Enumerator</tt> which does
the same as above.

<b>Note:</b> when called with a block and the list isn't up to date, 
the project will be re-scanned
=end
    def each abs = true
      if block_given?
        refresh unless @up_to_date
        dir = @project.project_dir
        @project_files.each do |f|
          yield abs ? File.join( dir, f) : f
        end
        self
      else
        return self.to_enum(:each, abs)
      end
    end
    
=begin rdoc
Returns an enumerator as that yields the names of the project files relative to
the project directory. It's just a shortcut for <tt>each(false)</tt>.

<b>Note:</b> if the list isn't up to date, the project will be re-scanned when
any enumerable method returned by the object is called
=end
    def rel
      self.each false
    end
    alias_method :relative_paths, :rel

=begin rdoc
Returns an enumerator as that yields the absolute names of the project files.
It's just a shortcut for <tt>each(true)</tt>.

<b>Note:</b> if the list isn't up to date, the project will be re-scanned when
any enumerable method returned by the object is called
=end
    def abs
      self.each true
    end
    alias_method :absolute_paths, :abs
    
=begin rdoc
Updates the list, so that it reflects the current status of the project directory.

Usually you don't need to call this method, as it's automatically called as needed.
=end
    def refresh
      scan_project
      @up_to_date = true
      @watcher.start_scan
    end
    
=begin rdoc
Tells whether the list is up to date or needs to be rebuilt.

Usually you don't need this method, as the list is automatically updated when needed.
=end
    def up_to_date?
      @up_to_date
    end
    
=begin rdoc
Tells whether the given file belongs to the project or not. If _file_ is a relative
path, it is considered relative to the project directory.

Returns *true* if _file_ belongs to the project and *false* otherwise. As this method
doesn't access the filesystem, the behaviour in the case _file_ is a directory will
be undefined. If _file_ ends with a slash (which makes it clear it represents a
directory) then *nil* will be returned
<b>Note:</b> this method doesn't use the file list to tell whether the file is in
the project. Rather, it compares the file name with the include and exclude rules
and the extensions.
=end
    def file_in_project? file
      file = file.sub %r[^#{Regexp.quote(@project.project_directory)}/], ''
      return false if file.start_with? '/'
      return nil if file.end_with? '/'
# I don't know why I added the following line
#       file = File.basename(file)
      
      return false if @exclude_files.include? file
      return true if @include_files.any?{|f| f == file}

      if @exclude_regexp.match(file) then false
      elsif @include_regexp.match file then true
      elsif @extensions.any?{|e| File.fnmatch?(e, file, File::FNM_DOTMATCH)} then true
      else false
      end
    end
    
    private

=begin rdoc
Applies the rules stored in the <tt>general/project_files</tt> project option
to all the files in the project directory and fills the internal cache with the
project files.

---
The <tt>@lock</tt> instance variable is used to (hopefully) avoid issues with
two threads calling this method together, since Dir.chdir doesn't nest inside
threads. This created problems with syntax checker, for example.
=end
    def scan_project
      @lock.synchronize do
        Dir.chdir(@project.project_dir) do
          res = @include_files.select{|f| File.exist?(f) and File.file?(f)}
          # remove the leading ./ from the names of the files
          res.map!{|f| f.sub(%r{^./}, '')}
          Find.find('.') do |f|
          # let's skip the current directory, least it somehow matches one of
          # the exclude rules
          next if f == '.'
            if File.directory?(f)
              f = File.join(f, '')
              Find.prune if f.match @exclude_regexp
            else
              # We remove the leading ./
              f = f[2..-1]
              next if f.match @exclude_regexp or @exclude_files.include?(f)
              res << f if @extensions.any?{|ext| File.fnmatch?(ext, f, File::FNM_DOTMATCH)} or
                  f.match(@include_regexp)
            end
          end
          res.uniq!
          @project_files = res
        end
      end
    end
   
=begin rdoc
Creates an internal version of the rules from the values in the
<tt>general/project_files</tt> project option
=end
    def make_rules
      rules = @project[:general, :project_files]
      @include_regexp = Regexp.union(*(rules[:include].select{|r| r.is_a?(Regexp)}))
      @exclude_regexp = Regexp.union(*(rules[:exclude].select{|r| r.is_a?(Regexp)}))
      @exclude_files = rules[:exclude].select{|rule| rule.is_a? String}.map{|f| f.sub(%r{^\./}, '')}
      @include_files = rules[:include].select{|rule| rule.is_a? String}.map{|f| f.sub(%r{^\./}, '')}
      @include_files-= @exclude_files
      @extensions = rules[:extensions]
      @rules = YAML.load(YAML.dump rules)
# TODO Uncomment the following line and remove the previous when found out why Marshal
# fails
#       @rules = rules.deep_copy
    end
    
  end
  
end
