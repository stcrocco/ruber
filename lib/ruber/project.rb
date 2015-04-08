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

require 'pathname'
require 'yaml'

require 'ruber/plugin'
require 'ruber/settings_container'
require 'ruber/project_backend'
require 'ruber/project_dir_scanner'

module Ruber

=begin rdoc

Base class for all projects. It must be sublcassed to be used.

It has two main functionalities
* store configuration options specific to each project (called <i>project options</i>),
  and read/write them to file, allow access to them and provide a way to configure
  them
* store the projects extensions relative to this projects and allow access to them.

Project option management is almost all done by the included SettingsContainer module. The
backend may be choose by subclasses, with the only restriction that it should provide
a +file+ method returning the name of the file associated with it.

Subclasses must reimplement the +:scope+ method, which should return <tt>:global</tt>
if the project is a global one (that is a project managed by the +ProjectList+)
component or <tt>:document</tt> if the project is associated with a single document.

A project can be in two states: _active_ and _inactive_, depending on whether the
user chose it as active project or not. Signals are emitted when the state changes.
<b>Note:</b> there can be at most one active project at any given time.

===Signals
=====<tt>option_changed(QString, QString)</tt>
Signal emitted when the value of an option changes. The two parameters are the
group and the name of the option, converted to strings. You'll have to convert
them back to symbols if you want to use them to access the option's value

=====<tt>closing(QObject*)</tt>
Signal emitted when the project is about to close The argument is the project itself.
This is mostly used by project
extensions which need to do some cleanup. They shouldn't use it to store settings
or similar, as there's the <tt>save_settings</tt> method for that.

=====<tt>saving()</tt>
Signal emitted just before the project is saved to file. This can be used by
extensions to write their options to the project.
=end
  class AbstractProject < Qt::Object
    
=begin rdoc
Exception raised when a project file contains some errors
=end
    class InvalidProjectFile < StandardError
    end
    
    include SettingsContainer
    
    signals 'option_changed(QString, QString)', 'closing(QObject*)', :settings_changed,
        :saving
    
=begin rdoc
A string containing the name of the project
=end
    attr_reader :project_name

=begin rdoc
The absolute path of the project file
=end
    attr_reader :project_file
    
=begin rdoc
Creates a new Project. _parent_ is the projects parent object (derived from <tt>Qt::Object</tt>);
_file_ is the name of the project file, which may already
exist or not, while _name_ is the name of the project. _name_ can only be specified
if the project file doesn't exist, otherwise +ArgumentError+ will be raised.

The project file, if existing, must follow the format described in the documentation for YamlSettingsBackend
and must contain a <tt>:project_name</tt> entry under the <tt>:general</tt> group,
otherwise it will be considered invalid. In this case, InvalidProjectFile will be
raised.

The new project asks each component to register itself with it, so that project
options, project widgets (widgets to be shown in the project's configuration dialog)
and project extensions are added. It also connects to the <tt>component_loaded</tt>
and <tt>unloading_component</tt> signals of the component manager. The first allow
each newly loaded plugin to register itself with the project, while the second allows
any unloading plugin to unregister itself.

When the project is created, it's not active.
=end
    def initialize parent, backend, name = nil
      super(parent)
      @active = false
      @project_file = backend.file
      setup_container backend, project_dir
      @dialog_class = ProjectDialog
      self.dialog_title = 'Configure Project'
      add_option OpenStruct.new(:group => :general, :name => :project_name, :default => nil)
      @project_name = self[:general, :project_name]
      if @project_name and name
        raise ArgumentError, "You can't specify a file name for an already existing project"
      elsif name 
        self[:general, :project_name] = name
        @project_name = name
      elsif !@project_name and File.exist? @project_file
        raise InvalidProjectFile, "The project file #{@project_file} isn't valid because it doesn't contain a project name entry" 
      elsif !name and !File.exist? @project_file
        raise ArgumentError, "You need to specify a project name for a new project"
      end
      @project_extensions = {}
      Ruber[:components].named_connect(SIGNAL('component_loaded(QObject*)'), "register_component_with_project #{object_id}"){|c| c.register_with_project self}
      Ruber[:components].named_connect(SIGNAL('unloading_component(QObject*)'), "remove_component_from_project #{object_id}"){|c| c.remove_from_project self}
    end
    
=begin rdoc
Returns the scope of the project (currently it must be either +:global+ or +document+).

This method must be overridden in derived classes, as it only raises +NoMethodError+
=end
    def scope
      raise NoMethodError, "Undefined method `scope' for #{self}:#{self.class}"
    end
    
=begin rdoc
Tells whether the project matches the rule specified in the object _obj_. _obj_
is an object with at least the following methods:
* +scope+
* +mimetype+
* +file_extension+

This implementation returns *true* if <tt>obj.scope</tt> includes the value returned
by <tt>self.scope</tt> (using this method requires subclassing AbstractProject,
since <tt>AbstractProject#scope</tt> raises an exception). Subclasses may override
this method to introduce other conditions. However, they'll most likely always
want to call the base class implementation.
=end
    def match_rule? obj
      obj.scope.include? self.scope
    end
    
=begin rdoc
Adds the project extension _ext_ to the project, under the name _name_. If an
extension is already stored under that name, +ArgumentError+ is raised.
=end
    def add_extension name, ext
      if @project_extensions[name]
        raise ArgumentError, "An extension called '#{name}' already exists"
      end
      @project_extensions[name] = ext
    end
    
=begin rdoc
Removes the project extension with name _name_. If an extension with that name
doesn't exist, nothing is done.
=end
    def remove_extension name
      ext = @project_extensions[name]
      ext.remove_from_project if ext.respond_to? :remove_from_project
      @project_extensions.delete name
    end

=begin rdoc
Override of SettingsContainer#[]= which after changing the value of the option,
emits the <tt>option_changed(QString, QString)</tt> message if the value of
the option changed (according to eql?).
=end
    def []= group, name, value
      old = @options[[group, name]]
      super
      emit option_changed group.to_s, name.to_s unless old.eql? value
    end
    
=begin rdoc
Returns the project extension with name _name_.
=end
    def extension name
      @project_extensions[name]
    end
    alias_method :project_extension, :extension
    
=begin rdoc
If called with a block, calls it for each extension passing the extension name
and the extension object itself as argument. If called without a block, returns
an +Enumerator+ whose +each+ method works as explained above
=end
    def each_extension
      if block_given?
        @project_extensions.each_pair{|name, ext| yield name, ext}
      else self.to_enum(:each_extension)
      end
    end
    
=begin rdoc
Returns a hash having the extension names as keys and the extension objects as
values.

<b>Note:</b> modifiying the hash doesn't change the internal list of extensions
=end
    def extensions
      @project_extensions.dup
    end
    alias_method :project_extensions, :extensions
    
=begin rdoc
Returns true if the project contains an extension corresponding to the name +:name+
and false otherwise
=end
    def has_extension? name
      @project_extensions.has_key? name
    end

=begin rdoc
Returns the absolute path of project directory, that is the directory where the
project file lies.
=end
    def project_directory
      File.dirname(@project_file)
    end
    alias_method :project_dir, :project_directory
    
=begin rdoc
Returns an array containing the name of the files belonging to the project.

This method should be reimplemented in derived classes to return the actual list
of files. The base class's version always returns an empty array.
=end
    def files
      []
    end
    
=begin rdoc
Returns the project extension with name _name_. If a project extension with that
name doesn't exist, or if _args_ is not empty, +ArgumentError+ is raised.
=end
    def method_missing name, *args, &blk
      begin super
      rescue NoMethodError, NameError, TypeError, ArgumentError => e
        if e.is_a? ArgumentError
          puts e.message
          puts e.backtrace.join("\n")
          puts "Method name: #{name}"
          puts "Arguments: #{args.empty? ? '[]' : args.join( ', ')}"
        end
        raise ArgumentError, "wrong number of arguments (#{args.size} for 0)" unless args.empty?
        @project_extensions[name] || super
      end
    end
    

    def save
      emit saving
      @project_extensions.each_value{|v| v.save_settings}
      begin 
        write
        true
      rescue Exception
        false
      end
    end
    
=begin rdoc
Override of <tt>SettingsContainer#write</tt>

It emits the {#settings_changed} signal after writing the settings to file
@return [nil]
@raise [SystemCallError] if an error occurs while writing to the file
=end
    def write
      super
      emit settings_changed
    end
    
=begin rdoc
Closes the project

According to the _save_ parameter, the project may save itself and its extensions\'
settings or not. In the first case, extensions may stop the project from closing
by having their @query_close@ method return *false*. If _save_ is false, nothing
will be saved and the closing can't be interrupted.
    
Before closing the project, the {#closing} signal is emitted. After that, all extensions
will be removed (calling their @remove_from_project@ method if they have one).

@param [Boolean] save whether or not to save the project and the extensions\'
  settings. If *true*, the extensions will also have a chance to abort closing by
  returning *false* from their @query_close@ method
@return [Boolean] *true* if the project was closed correctly and *false* if the
  project couldn\'t be closed, either because some of the extensions\' @query_close@
  method returned *false* or because the project itself couldn\'t be saved for some
  reason.
=end
    def close save = true
      if save
        return false unless query_close
        return false unless self.save
      end
      emit closing(self)
      @project_extensions.each_key{|k| remove_extension k}
      Ruber[:components].named_disconnect "remove_component_from_project #{object_id}"
      Ruber[:components].named_disconnect "register_component_with_project #{object_id}"
      true
    end
    slots :close
    slots 'close(bool)'
    
    def query_close
      @project_extensions.each_value{|v| return false unless v.query_close}
      true
    end
    
=begin rdoc
Registers each component with the project

This isn't done in {#initialize} because, at least for {DocumentProject}, the extensions
may try to access the project (directly or not) before it has fully been created.

This method should only be called from the object calling {.new}

@note This method has nothing to do with finalizers
@return [nil]
=end
    def finalize
      Ruber[:components].each_component{|c| c.register_with_project self}
      nil
    end
    
  end
  
=begin rdoc
Class representing a global project (one which should be managed by ProjectList).

It uses ProjectBackend as backend and includes the Activable module.

===Signals
=====<tt>activated()</tt>
Signal emitted when the project is activated

=====<tt>deactivated()</tt>
Signal emitted when the project is deactivated

===Slots
* <tt>activate()</tt>
* <tt>deactivate()</tt>
=end
  class Project < AbstractProject
    
    class InvalidProjectFileName < StandardError
    end
    
    include Activable
    
    signals :activated, :deactivated
    
    slots :activate, :deactivate
    
=begin rdoc
Creates a new Project. _file_ is the name of the project file, while _name_ is
the project name. You must specify both arguments if the file _file_ doesn't exist,
while you must not pass the _name_ parameter if the file _file_ already exists (in
this case, the project name is written in the project file and there's no need
to specify it). Note that this method takes care of creating the backend, so you
don't need to do that yourself (unlike with AbstractProject).

If _file_ is a relative path, it's considered relative to the current directory.

If the project file _file_ already exists but it's not a valid project file,
AbstractProject::InvalidProjectFile will be raised.

@param [String] file the path of the project file (it doesn't need to exist)
@param [String,nil] name the name of the project. If the project file already exists,
  then this should be *nil*. If the project file doesn't exist, this should *not*
  be *nil*
=end
    def initialize file, name = nil
      file = File.join(Dir.pwd, file) unless file.start_with? '/'
      back = begin ProjectBackend.new file
      rescue YamlSettingsBackend::InvalidSettingsFile => e
        raise Ruber::AbstractProject::InvalidProjectFile, e.message
      end
      super Ruber[:world], back, name
      finalize
      @dir_scanner = ProjectDirScanner.new self
      @dir_scanner.connect(SIGNAL('file_added(QString)')) do |f|
        @files << f if @files
      end
      @dir_scanner.connect(SIGNAL('file_removed(QString)')) do |f|
        @files.delete f if @files
      end
      @dir_scanner.connect(SIGNAL(:rules_changed)){@files = nil}
      @files = nil
    end
    
=begin rdoc
Override of <tt>AbstractProject#close</tt> which deactivates the project before closing it
and disposes of it after closing. Aside from this, it works as the base class version.
=end
    def close save = true
      deactivate
      res = super
      dispose
      res
    end
    
=begin rdoc
Reimplementation of <tt>AbstractProject#scope</tt> which returns +:global+
=end
    def scope
      :global
    end
    
=begin rdoc
Override of <tt>SettingsContainer#add_option</tt> which sets the type of _opt_
to +:global+ if <tt>opt.type</tt> returns *nil*.

This is necessary because +AbstractProject.new+ adds the +:project_name+ option
without specifying its type.
=end
    def add_option opt
      opt.type ||= :global
      super
    end
    
=begin rdoc
Override of AbstractProject#files which actually returns the list of files belonging
to the project.

<b>Note:</b> this method uses the <tt>project_files</tt> extension
=end
    def files
      @files ||= @dir_scanner.project_files
      ProjectFiles.new project_directory, @files
    end
    alias_method :project_files, :files

    def file_in_project? file
      @dir_scanner.file_in_project? file
    end
  end
  
=begin rdoc
Subclass of SettingsDialog which differs from it only in that it overrides the 
<tt>widget_from_class</tt> method.

<bb>Note:</bb> since the overridden <tt>widget_from_class</tt> method passes
the project as argument to the widget's class <tt>#new</tt> method, the widget's
constructor must explicitly pass *nil* to the superclass method as parent. To
avoid any issues, you can derive your widget from ProjectConfigWidget
rather than from <tt>Qt::Widget</tt>. If, for some reason, you can't do that (for
example because you need to derive from another specialized widget), your widget
constructor must do something like this (assuming that the base class's construcor
take the same argument as Qt::Widget's):
 
  class MyWidget < SomeWidget
  
    def initialize prj
      super()
      # do (if you want) something with prj
    end
    
  end
=end
  class ProjectDialog < SettingsDialog
    
    private
    
=begin rdoc
Override of SettingsDialog#widget_from_class which passes the project as argument
to the class's +#new+ method.
=end
    def widget_from_class cls
      cls.new @container
    end
    
  end
  
=begin rdoc
Small class which can be used instead of <tt>Qt::Widget</tt> for widgets to be
used in the configuration dialog.

The only difference between this class and <tt>Qt::Widget</tt> is in the arguments
taken by the constructor: instead of taking the parent (which is instead set to
*nil*), this class accepts the project the dialog refers to and stores it in
its +project+ attribute.
=end
  class ProjectConfigWidget < Qt::Widget
    
=begin rdoc
The project associated with the dialog containing the widget
=end
    attr_reader :project
    
=begin rdoc
Creates a new instance. _project_ is the Project associated with the dialog the
widget will be put into.
=end
    def initialize project
      super()
      @project = project
    end
    
  end


  module Extension
    
    attr_accessor :plugin
    
    def save_settings
    end
    
    def shutdown
    end
    
    def remove_from_project
    end
    
    def query_close
      true
    end
    
  end
  
end
