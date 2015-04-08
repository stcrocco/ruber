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

require 'ruber/plugin_like'
require 'ruber/world/document_factory'
require 'ruber/world/project_factory'
require 'ruber/world/environment'
require 'ruber/world/project_list'
require 'ruber/world/document_list'
require_relative 'ui/workspace_settings_widget'

module Ruber

  module World

=begin rdoc
The world class (and component) is where everything in Ruber lives. It contains
* a list of the open documents
* a list of the open projects
* a list of the open environments

It also keeps track of which project, document, environment and editor is active
and provides methods to change the active one (except for the editor which should
be changed using {Environment#activate_editor}).

For all this to work, documents and projects should never be created using
@Document.new@ or @Project.new@; instead, use {#new_document}, {#document},
{#new_project} and {#project}.

h3. The default environment

Environments are usually associated with a project. The world, however, contains
a single document which is not associated with a project. This environment is
called the _default environment_. This is the active environment if there is
no open project (and thus, no other environment which can be activated).

h3. Active environment, project, editor and document

In Ruber there can be a single document, a single editor, a single project and
a single environment which are active:
* the active environment is the environment which is visible. All the other
  environments are hidden. There's always an active environment
* the active project is the project associated with the active environment. If
  the active environment is the default environment, then there's no active
  project ({#active_project} returns *nil*)
* the active editor is the editor whose GUI is merged with the main window's.
  If the active environment contains any views, at least one of them is active.
  If the active environment contains no views, then there's no active view.
* the active document is the document associated with the active editor. If
  there isn't an active view, then there isn't an active document either.
=end

    class World < Qt::Object

=begin rdoc
Exception raised from {Ruber::World::World#new_project} when the given file already
  exists
=end
      class ExistingProjectFileError < StandardError
      end

      include PluginLike
      
=begin rdoc
@return [Environment] the default environment
=end
      attr_reader :default_environment
      
=begin rdoc
@return [Environment] the active environment
=end
      attr_reader :active_environment
      
=begin rdoc
@return [Document] the active document
=end
      attr_reader :active_document
      
=begin rdoc
Signal emitted whenever the active environment changes

When this signal is emitted, {#active_environment} already returns the new
active environment
@param [Environment] env the active environment
=end
      signals 'active_environment_changed(QObject*)'
      
=begin rdoc
Signal emitted whenever the active environment changes

When this signal is emitted, {#active_environment} already returns the new
active environment
@param [Environment] new_env the active environment
@param [Environment] old_env the previously active environment
=end
      signals 'active_environment_changed_2(QObject*, QObject*)'
      
=begin rdoc
Signal emitted whenever the active project changes

When this signal is emitted, {#active_project} already returns the new active
project.
@param [Project,nil] prj the new active project. It's *nil* if the default
  environment just become active
=end
      signals 'active_project_changed(QObject*)'

=begin rdoc
Signal emitted whenever the active project changes

When this signal is emitted, {#active_project} already returns the new active
project.
@param [Project,nil] new_prj the new active project. It's *nil* if the default
  environment just become active
@param [Project,nil] old_prj the previously active project. It's *nil* if the
  previously active environment was the default one
=end
      signals 'active_project_changed_2(QObject*, QObject*)'
      
=begin rdoc
Signal emitted whenever a document is added to the list of open documents
@param [Document] doc the new document
=end
      signals 'document_created(QObject*)'
      
=begin rdoc
Signal emitted whenever a project is added to the list of open projects
@param [Project] prj the new project
=end
      signals 'project_created(QObject*)'
      
=begin rdoc
Signal emitted when a project is being closed

This signal is emitted in response to the project's {AbstractProject#closing #closing}
signal
@param [Project] prj the project being closed
=end 
      signals 'closing_project(QObject*)'
      
=begin rdoc
Signal emitted when a document is being closed

This signal is emitted in resposne to the document's {Document#closing} signal
@param [Document] doc the document being closed
=end
      signals 'closing_document(QObject*)'
      
=begin rdoc
Signal emitted whenever the active document changes

When this signal is emitted, {#active_document} already returns the new document
@param [Document,nil] doc the new active document or *nil* if there is no acitve
  document
=end
      signals 'active_document_changed(QObject*)'
      
=begin rdoc
Signal emitted whenever the active editor changes

This signal is not the same as {#active_document_changed} because switching
between two editors referring to the same document would emit @#active_editor_changed@
but not {#active_document_changed}
@param [EditorView] view the new active editor view
=end
      signals 'active_editor_changed(QWidget*)'
      

=begin rdoc
@param [ComponentManager] manager the component manager (unused)
@param [PluginSpecification] psf the plugin specification object associated with
  the component
=end
      def initialize _, psf
        super Ruber[:app]
        @documents = MutableDocumentList.new []
        @projects = MutableProjectList.new []
        @environments = {}
        initialize_plugin psf
        @active_environment = nil
        @active_document = nil
        @document_factory = DocumentFactory.new self, self
        connect @document_factory, SIGNAL('document_created(QObject*)'), self, SLOT('slot_document_created(QObject*)')
        @project_factory = ProjectFactory.new self
        connect @project_factory, SIGNAL('project_created(QObject*)'), self, SLOT('slot_project_created(QObject*)')
        @default_environment = Environment.new(nil, self)
        add_environment @default_environment, nil
      end
      
=begin rdoc
The environment associated with the given project

If called with a project as argument, it does the same as @prj.environment@.

@param [Project,nil] prj the project to retrieve the environment for, or *nil*
  to retrieve the default environment
@return [Environment] the environment associated with _prj_ or the default environment
  if _prj_ is *nil*
=end
      def environment prj
        @environments[prj] 
      end
      
=begin rdoc
Changes the active environment

@param [Environment,nil] env the environment to activate.
@note You should never call this method with *nil*: doing so is for internal
  use only
=end
      def active_environment= env
        return if @active_environment == env
        old = @active_environment
        old.deactivate if old
        @active_environment = env
        @active_environment.activate if @active_environment
        emit active_environment_changed(env)
        emit active_environment_changed_2(env, old)
      end

=begin rdoc
@return [<Environment>] a list of all existing environments (including the default one)
=end
      def environments
        @environments.values
      end
      
=begin rdoc
Iterates on existing environments
@return [Enumerator, World]
@overload each_environment{}
  Calls the block for each existing environment (including the default one)
  @yield the block to call for each existing environment
  @yieldparam [Environment] env an environment
  @return [World] *self*
@overload each_environment
  Returns an @Enumerator@ which iterates on the existing environments 
  @return [Enumerator] an enumerator which iterates on the existing environments
=end
      def each_environment
        if block_given? 
          @environments.each_value{|e| yield e}
          self
        else to_enum(:each_environment)
        end
      end

=begin rdoc
Changes the active project

Changing the active project also means activating the environment associated
with that project.

@param [Project,nil] prj the project to make active. If *nil* is given, the
  default environment is activated
@return [Project,nil] the new active project
=end
      def active_project= prj
        old = @active_environment.project if @active_environment
        return old if old == prj
        old.deactivate if old
        self.active_environment = @environments[prj]
        prj.activate if prj
        emit active_project_changed prj
        emit active_project_changed_2 prj, old
      end
      
=begin rdoc
The project associated with the active environment
@return [Project,nil] the project associated with the active environment or
  *nil* if the default environment is active
=end
      def active_project
        @active_environment.project if @active_environment
      end
      
=begin rdoc
@return [ProjectList] a list of the existing projects
=end
      def projects
        ProjectList.new @environments.keys.compact
      end
      
=begin rdoc
Iterates on existing projects
@return [Enumerator, World]
@overload each_project{}
  Calls the block for each existing project
  @yield the block to call for each existing project
  @yieldparam [Project] prj a project
  @return [World] *self*
@overload each_project
  Returns an @Enumerator@ which iterates on the existing projects
  @return [Enumerator] an enumerator which iterates on the existing projects
=end
      def each_project
        if block_given?
          @environments.each_key{|prj| yield prj if prj}
          self
        else self.to_enum(:each_project)
        end
      end
      
=begin rdoc
Creates a pristine document
@return [Document] the new document. It will be a child of *self*
=end
      def new_document
        doc = @document_factory.document nil, self
        doc
      end
      
=begin rdoc
The document associated with the given file or URL

If a document for the given file or URL already exists, that document will be
returned, otherwise a new one will be created.

@param [String,KDE::Url] file the absolute name or the URL of the
  file to retrieve the document for
@return [Document,nil] a document associated with _file_ and having *self* as parent.
  If _file_ represents a local file and that file doesn't exist, *nil* is returned
=end
      def document file
        @document_factory.document file, self
      end
      
=begin rdoc
@return [DocumentList] a list of existing documents
=end
      def documents
        DocumentList.new @documents
      end
      
=begin rdoc
Iterates on existing documents
@return [Enumerator, World]
@overload each_document{}
  Calls the block for each existing document
  @yield the block to call for each existing document
  @yieldparam [Document] doc a document
  @return [World] *self*
@overload each_document
  Returns an @Enumerator@ which iterates on the existing document
  @return [Enumerator] an enumerator which iterates on the existing document
=end
      def each_document
        if block_given?
          @documents.each{|doc| yield doc}
          self
        else self.to_enum :each_document
        end
      end
      
=begin rdoc
Creates a new project
@param [String] file the absolute path of the project file
@param [String] name the name of the project
@return [Project] a new project having _file_ as project file and _name_ as project
  name
@raise [ExistingProjectFileError] if a file called _file_ already exists (regardless
  of whether it's a valid project file or not)
=end
      def new_project file, name
        raise ExistingProjectFileError, "#{file} already exists" if File.exist?(file)
        @project_factory.project file, name
      end
   
=begin rdoc
Retrieves the project associated with a given project file

If a project associated with the project file _file_ already exists, that project
is returned. Otherwise, a new project object is created.

@param [String] file the absolute path of the project file. Note that this file
  *must* already exist and be a valid project file
@return [Project] a project associated with _file_
@raise [AbstractProject::InvalidProjectFile] if the project file is not a valid
  project file or doesn't exist
=end
      def project file
        @project_factory.project file
      end
      
=begin rdoc
Closes all open documents and/or projects

Depending on the first argument, this method can close all the open projects,
all the open documents or both.

Note that the @#query_close@ method of documents and projects won't be called.

If, for any reason, one of the document or projects can't be closed, the others
will be closed all the same
@param [Symbol] what what to close. If @:documents@, only documents will be
  closed; if @:projects@ only projects will be closed; if @:all@ both documents
  and projects will be closed. If any other value is given, nothing will be
  done
@param [Symbol] save_behaviour if this is @:save@, {Document#close} and
  {Project#close} will be passed *true* as argument, otherwise they'll be
  passed *false*
@return [nil]
=end
      def close_all what, save_behaviour = :save
        close_docs = (what == :all || what == :documents)
        close_prjs = (what == :all || what == :projects)
        save = save_behaviour == :save
        @projects.dup.each{|prj| prj.close save} if close_prjs
        @documents.dup.each{|doc| doc.close save} if close_docs
        nil
      end
      
=begin rdoc
Saves the settings associated with this component

It calls the {Document#save_settings #save_settings} method of all the documents
and the {AbstractProject#save #save} method of all the projects
@return [nil]
=end
      def save_settings
        @documents.each{|doc| doc.save_settings}
        @projects.each{|prj| prj.save}
        nil
      end
      
=begin rdoc
Override of {PluginLike#query_close}

It calls the {Document#can_close? can_close?} method of each document and the
{AbstractProject#query_close #query_close} method of each project and returns *false*
if one of those methods return *false*.

For the user's convenience, {MainWindow#save_documents} is used to ask which
documents should be saved, rather than letting each document's {Document#can_close? can_close?}
method do it
@return [Boolean] *true* if Ruber can be closed and *false* otherwise
=end
      def query_close
        @documents.each{|doc| return false unless doc.can_close? false}
        return false unless Ruber[:main_window].save_documents @documents.to_a
        @projects.each{|prj| return false unless prj.query_close}
        true
      end
      
      private
      
=begin rdoc
Adds an environment associated with a project
@param [Environment] env the environment to add
@param [Project,nil] prj the project the environment is associated with or *nil*
    when adding the default environment
@return [Environment] _env_
=end
      def add_environment env, prj
        @environments[prj] = env
        connect env, SIGNAL('closing(QObject*)'), self, SLOT('environment_closing(QObject*)')
        connect env, SIGNAL('active_editor_changed(QWidget*)'), self, SLOT('slot_active_editor_changed(QWidget*)')
        env
      end
      
=begin rdoc
Slot called whenever an environment is closed

It deactivates the environment if it was active
@param [Environment] env the environment which is being closed
@return [nil]
=end
      def environment_closing env
        @environments.delete env.project
        self.active_environment = nil if @active_environment == env
        nil
      end
      slots 'environment_closing(QObject*)'
      
=begin rdoc
Slot called whenever a new document is created

@param [Document] doc the new document
@return [nil]
=end      
      def slot_document_created doc
        @documents.add doc
        connect doc, SIGNAL('closing(QObject*)'), self, SLOT('slot_document_closing(QObject*)')
        emit document_created(doc)
      end
      slots 'slot_document_created(QObject*)'

=begin rdoc
Slot called whenever a new project is created

@param [Project] prj the project document
@return [nil]
=end      
      def slot_project_created prj
        @projects.add prj
        connect prj, SIGNAL('closing(QObject*)'), self, SLOT('slot_closing_project(QObject*)')
        add_environment prj.extension(:environment), prj
        emit project_created(prj)
      end
      slots 'slot_project_created(QObject*)'

=begin rdoc
Slot called whenever a document is closed

@param [Document] doc the environment which is being closed
@return [nil]
=end

      def slot_document_closing doc
        emit closing_document(doc)
        @documents.remove doc
        nil
      end
      slots 'slot_document_closing(QObject*)'
      
=begin rdoc
Slot called whenever a project is closed

@param [Project] prj the project which is being closed
@return [nil]
=end

      def slot_closing_project prj
        emit closing_project(prj)
        @projects.remove prj
        nil
      end
      slots 'slot_closing_project(QObject*)'
      
=begin rdoc
Override of {PluginLike#load_settings}
@return [nil]
=end
      def load_settings
        tabs_closable = Ruber[:config][:workspace, :close_buttons]
        @environments.each_value{|e| e.tab_widget.tabs_closable = tabs_closable}
        nil
      end
      slots :load_settings
      
=begin rdoc
Slot called whenever the active editor changes
@param [EditorView] editor the new active editor
=end
      def slot_active_editor_changed editor
        doc = editor ? editor.document : nil
        if doc != @active_document
          @active_document = doc
          emit active_document_changed(@active_document)
        end
        emit active_editor_changed(editor)
      end
      slots 'slot_active_editor_changed(QWidget*)'
      
    end
    
    class WorkspaceSettingsWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::WorkspaceSettingsWidgetBase.new
        @ui.setup_ui self
      end
      
    end
    
  end
  
end