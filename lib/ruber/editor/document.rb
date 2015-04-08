=begin 
    Copyright (C) 2010, 2011, 2012 by Stefano Crocco   
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

require 'ktexteditor'
require 'forwardable'
require 'dictionary'

require 'ruber/editor/ktexteditor_wrapper'
require 'ruber/editor/editor_view'
require 'ruber/utils'
require 'ruber/document_project'
require 'ruber/editor/projected_document'
require 'ruber/editor/annotation_model'

module Ruber
  
=begin rdoc
A class which represents a text document in Ruber

It wraps a @KTextEditor::Document@ object (in particular, a @Kate::Document@)
and uses it for most of its functionality.

This class allows plugins to associate settings with a specific document, using
{DocumentProject}s. Each document may have more than one document project associated
with it, each living in a different environment. This allows to have different
settings for a given document for each environment.

Note that document projects are only created when one of the methods {#own_project},
{#project} and {#extension} is called. A newly created document has no document
project.

All methods of @KTextEditor::Document@ which are not listed here can be accessed
all the same (they're called using {KTextEditorWrapper#method_missing #method_missing}).

To obtain an interface for the document, use {KTextEditorWrapper#interface interface}

@note Some interfaces don't play too well with this class: for example, all of
  the @Moving*@ classes, since they're tied to the underlying @KTextEditor::Document@,
  rather than with the @Ruber::Document@. You can still use them, however, and
  access the document calling the @KTextEditor::Document@'s @#parent@ method.
=end
  class Document < Qt::Object
    
    extend Forwardable
    
    include Activable
    
    include KTextEditorWrapper
    
=begin rdoc
A hash associating icon roles used by Document with icon names. It is used by
{ICONS}
=end
    ICON_NAMES = { 
      :modified => 'document-save',
      :modified_on_disk => 'dialog-warning'
    }
    
=begin rdoc
Hash containing a list of predefined icons, each associated with a role (usually
a symbol describing the icon's use).

At the beginning, this hash is empty. It is automatically filled by loading icons
according with the associations specified in {ICON_NAMES} as they're requested.
This is necessary because the hash is created when this file is read, which may
happen before the application is created.
=end
    ICONS = Hash.new do |h, k|
      icon = KDE::IconLoader.load_icon ICON_NAMES[k]
      h[k] = icon
    end

    def_delegator :@doc, :documentSave, :save_document
    
    signal_data = { 
      'text_changed' => ['KTextEditor::Document*', [nil]],
      'about_to_close' => ['KTextEditor::Document*', [nil]],
      'about_to_reload' => ['KTextEditor::Document*', [nil]],
      'highlighting_mode_changed' => ['KTextEditor::Document*', [nil]],
      'mode_changed' => ['KTextEditor::Document*', [nil]],
      'sig_query_close' => ['bool*, bool*', [0,1]],
      'canceled' => ['QString', [0]],
      'started' => ['KIO::Job*', [0]],
      'set_status_bar_text' => ['QString', [0]],
      'setWindowCaption' => ['QString', [0]]
    }
    
    @signal_table = KTextEditorWrapper.prepare_wrapper_connections self, signal_data
    
=begin rdoc
Signal emitted when the document status of the document changes
@param [Boolean] status whether the document is modified or not
@param [Document] doc *self*
=end
signals 'modified_changed(bool, QObject*)'
    
=begin rdoc
Signal emitted whenever the document name changes
@param [String] the new name of the document
@param [Document] doc *self*
=end
signals 'document_name_changed(QString, QObject*)'

=begin rdoc
Signal emitted whenever the text of the document changes
@param [Document] doc *self*
=end
signals 'text_changed(QObject*)'

=begin rdoc
Signal emitted when the internal @KTextEditor::Document@ is about to be closed

All information about the document is still availlable, but changes to the document
will be lost. Extensions and settings relative to the document may no longer
be availlable when this signal is emitted.
@note You usually don't want to connect to this signal, but to {#closing}, since
  it is called when settings and extensions are still availlable
@param [Document] doc *self*
=end
signals 'about_to_close(QObject*)'

=begin rdoc
Signal emitted before the document is reloaded

All information about the document is still availlable, but changes to the document
will be lost
@param [Document] doc *self*
=end
signals 'about_to_reload(QObject*)'
    
=begin rdoc
Signal emitted whenever the URL of the document changes
@param [Document] doc *self*
=end
signals 'document_url_changed(QObject*)'

=begin rdoc
Signal emitted whenever the highlighting mode of the document changes
@param [Document] doc *self*
=end
signals 'highlighting_mode_changed(QObject*)'

=begin rdoc
Signal emitted whenever the document mode changes
@param [Document] doc *self*
=end
signals 'mode_changed(QObject*)'

=begin rdoc
Signal emitted when the text of the document changes

It is emitted at the same time as {#text_changed}, but takes different arguments
@param [KTextEditor::Range] old_range the range the text previously occupied
@param [KTextEditor::Range] new_range the range the changed text now occupies
@param [Document] doc *self*
=end
signals 'text_modified(KTextEditor::Range, KTextEditor::Range, QObject*)'

=begin rdoc
Signal emitted whenever text is inserted
@param [KTextEditor::Range] the range the newly inserted text occupies
@param [Document] doc *self*
=end
signals 'text_inserted(KTextEditor::Range, QObject*)'

=begin rdoc
Signal emitted whenever some text is removed from the document
@param [KTextEditor::Range] the range that the removed text previously occupied
@param [Document] doc *self*
=end
signals 'text_removed(KTextEditor::Range, QObject*)'

=begin rdoc
Signal emitted whenever a view is created

@param [EditorView] view the newly creaed view
@param [Document] doc *self*
=end
signals 'view_created(QObject*, QObject*)'

=begin rdoc
Signal emitted when the document is being closed. 

Document projects, extensions and settings are still availlable when this signal
is emitted
@param [Document] doc *self*
=end
signals 'closing(QObject*)'

=begin rdoc
Signal emitted whenever the document becomes active
=end
signals :activated

=begin rdoc
Signal emitted whenever the document is deactivated
=end
signals :deactivated
    
=begin rdoc
Signal emitted whenever the modified-on-disk status of the document changes

See {#modified_on_disk?} for what being modified on disk means
@param [Document] doc *self*
@param [Boolean] mod whether the document become modified on disk or not
@param [KTextEditor::ModificationInterface::ModifiedOnDiskReason] the reason of
  the change of state
=end
signals 'modified_on_disk(QObject*, bool, KTextEditor::ModificationInterface::ModifiedOnDiskReason)'

=begin rdoc
See the C++ documentation for @KParts::ReadWritePart::sigQueryClose@
@param [Qt::Boolean] handled
@param [Qt::Boolean] abort_closing
=end
signals 'sig_query_close(bool*, bool*)'

=begin rdoc
Signal emitted whenever loading is cancelled by the user or by an error
@param [String] reason the error message. If the user cancelled the loading,
  it is empty
=end
signals 'canceled(QString)'

=begin rdoc
Signal emitted when loading has finished
=end
signals 'completed()'
    
=begin rdoc
Signal emitted when loading has finished

@param [Boolean] pending whether there is a pending action to be executed on
  a delay timer
=end
signals  'completed1(bool)'

=begin rdoc
Signal emitted when starting data
@param [KIO::Job,nil] job the job used by the part or *nil* if the part isn't
  using a @KIO::Job@
=end
signals 'started(KIO::Job*)'

=begin rdoc
Signal emitted when the part wants a certain text set in the status bar
@param [String] text the text to set in the statusbar
=end
signals 'set_status_bar_text(QString)'

=begin rdoc
Signal emitted when the part wants a certain caption set in the main window
@param [String] caption the caption to set in the main window
=end
signals 'setWindowCaption(QString)'

=begin rdoc
Signal emitted when a document has been saved to disk or uploaded
@param [Document] doc *self*
@param [Boolean] save_as whether the operation is a save operation
=end
signals 'document_saved_or_uploaded(QObject*, bool)' 
    
=begin rdoc
Signal emitted before a view associated with the document is closed

When this signal is emitted, the view is still associated with the document, and
it is still included in the array returned by {#views}
@param [EditorView] view the view which is being closed
@param [Document] doc *self*
=end
    signals 'closing_view(QWidget*, QObject*)'
    
=begin rdoc
Creates a new instance of Document

The new document doesn't have any document projects associated with it.
    
The new document is inactive and has an annotation model of class {AnnotationModel}.

@param [Ruber::World] world the world Ruber lives in. Usually, it'll be @Ruber[:world]@
@param [String,KDE::Url,nil] file the file or url to open. If *nil*, the document
  won't be associated with any file
@param [Qt::Object] parent the document's parent
=end
    def initialize world, file = nil, parent = nil
      super parent
      @closing = false
      @active = false
      @doc = KTextEditor::EditorChooser.editor('katepart').create_document( self)
      initialize_wrapper @doc, self.class.instance_variable_get(:@signal_table)
      @views = []
      @doc.openUrl(file.is_a?(String) ? KDE::Url.new(file) : file) if file
      @annotation_model = AnnotationModel.new self
      interface('annotation_interface').annotation_model = @annotation_model
      interface('modification_interface').modified_on_disk_warning = true
      @modified_on_disk = false
      @projects = {}
      @world = world
      @doc.connect(SIGNAL('modifiedChanged(KTextEditor::Document*)')) do |doc|
        emit modified_changed(@doc.modified?, self)
      end
      @doc.connect(SIGNAL('documentUrlChanged(KTextEditor::Document*)')) do |doc|
        if !doc.url.remote_file?
          Ruber[:components].each_component do |c|
            @projects.each_value{|pr| c.update_project pr}
          end
        end
        emit document_url_changed self
      end
      
      @doc.connect SIGNAL(:completed) do
        if @doc.url.remote_file?
          Ruber[:components].each_component{|c|c.update_project @project}
        end
        emit completed
      end
      
      @doc.connect SIGNAL('documentNameChanged(KTextEditor::Document*)') do |doc|
        emit document_name_changed doc.document_name, self
      end
      
      @doc.connect(SIGNAL('textChanged(KTextEditor::Document*, KTextEditor::Range, KTextEditor::Range)')){|_, o, n| emit text_modified(o, n, self)}
      
      @doc.connect(SIGNAL('textInserted(KTextEditor::Document*, KTextEditor::Range)')) do |_, r| 
        begin
          emit text_inserted(r, self)
        rescue ArgumentError => e
          ExceptionDialog.new e, nil, true, "An exception was raised from emit text_inserted. See issue number 6 at http://github.com/stcrocco/ruber/issues"
        end
      end
      
      @doc.connect(SIGNAL('textRemoved(KTextEditor::Document*, KTextEditor::Range)')){|_, r| emit text_removed(r, self)}
      @doc.connect(SIGNAL('modifiedOnDisk(KTextEditor::Document*, bool, KTextEditor::ModificationInterface::ModifiedOnDiskReason)')) do |_, mod, reason|
        @modified_on_disk = (reason != KTextEditor::ModificationInterface::OnDiskUnmodified)
        emit modified_on_disk(self, mod, reason)
      end
      connect @doc, SIGNAL('completed(bool)'), self, SIGNAL('completed1(bool)')
    end

=begin rdoc
Override of @Qt::Object#inspect@

It works as the base class but doesn't crash if @#dispose@ has been called on
the object. In that case, it returns a string with the class name, the object
id and the @DISPOSED@ tag.
@return [String] a string describing the state of the object
=end
    def inspect
      if disposed? then "< #{self.class} #{object_id} DISPOSED >"
      else super
      end
    end
    
=begin rdoc
Projects the document on an environment
@param [World::Environment] env the environment to project the document on
@return [ProjectedDocument] a {ProjectedDocument} associated with the document
  and the given environment
=end
    def project_on env
      ProjectedDocument.new self, env
    end
    
=begin rdoc
@return [<EditorView>] a list of all the views associated with the document
=end
    def views
      @views.dup
    end
    
=begin rdoc
@return [Boolean] whether the document has at least one view associated with it
=end
    def has_view?
      !@views.empty?
    end
    
=begin rdoc
The view which currently has user focus, if any
@return [EditorView,nil] the view associated with the document which currently has
  user focus or *nil* if none of the views associated with the document has user
  focus
=end
    def active_view
      @doc.active_view.parent rescue nil
    end

=begin rdoc
Whether the document matches a list of mime types and/or file patterns.

The mimetypes are compared using {KDE::MimeType#=~}, while the document path
is matched agains the given file pattens using @File.fnmatch@ (note that only
the base part of the file path will be compared, not the full path).

@param [<String>,String] mimetypes a string or list of strings each representing
  one of the mimetypes you want to compare the document mimetype with. Empty
  strings are ignored. Passing a string is the same as passing an array containing
  only that string
@param [<String>,String] patterns a string or list of strings each representing
  one of the file patterns you want to cmpare the document mimetype with. Empty
  strings are ignored. Passing a string is the same as passing an array containing
  only that string.
  
  Note that specifying a pattern containing a directory part will always cause
  that match to fail, since only the base part of the file name (the part after
  the last slash) is taken into account
@return [Boolean] *true* if there is at least a mimetype or a file pattern that
  matches and *false* if no mimetype and no file pattern matches. If either
  _mimetypes_ or _patterns_ is empty, it will be ignored. If both are empty,
  this method always returns *true*.
    
  If the document is not associated with a file, it'll only match the @text/plain@
  mimetype and won't match any file pattern
@see KDE::MimeType#=~
=end
    def file_type_match? mimetypes = [], patterns = []
      mime = KDE::MimeType.mime_type @doc.mime_type
      mimetypes = Array(mimetypes).reject{|i| i.empty?}
      patterns = Array(patterns).reject{|i| i.empty?}
      base = File.basename path
      if mimetypes.empty? and patterns.empty? then true
      elsif mimetypes.any? {|m| mime =~ m} then true
      elsif patterns.any? {|pat| File.fnmatch? pat, base, File::FNM_DOTMATCH} then true
      else false
      end
    end

=begin rdoc
Retrieves a document extension

@param [Symbol] name the name of the extension to retrieve
@param [World::Environment,nil] env the environment the extension should live
  in. If *nil*, the active environment is used
@return [Object,nil] the document extension with the given name living in the
  environment _env_ or *nil* if no extension with that name lives in the given
  environment
=end
    def extension name, env = nil
      env ||= @world.active_environment
      (@projects[env] || create_project(env)).extension name
    end
    
=begin rdoc
The icon associated with the document in its current state

Which icon is returned depends on the document's mimetype, on whether the
document is modified or not and possibly on other factors.
@return [Qt::Icon] the appropriate icon for the document
=end
    def icon
      if @modified_on_disk then ICONS[:modified_on_disk]
      elsif @doc.modified? then ICONS[:modified]
      else
        if has_file? :remote
          mime = KDE::MimeType.find_by_content Qt::ByteArray.new(@doc.text)
        else mime = KDE::MimeType.mime_type(@doc.mime_type)
        end
        icon_name = mime.icon_name
        Qt::Icon.new(KDE::IconLoader.load_mime_type_pixmap icon_name)
      end
    end

=begin rdoc
Whether the document is associated with a file

Depending on the argument, this method can also distinguish between local and
remote files
@param [Symbol] kind the file kind(s) which should be accepted. It can be one
  of @:local@, @:remote@ or @:any@
@return [Boolean] if _kind_ is @:any@ returns *true* if the document is associated
  with a file and *false* otherwise. If _kind_ is @:local@, returns *true*
  if the document is associated with a local file and *false* otherwise. If
  _kind_ is @:remote@, returns *true* if the document is associated with a
  remote file and *false* otherwise.
=end
    def has_file? kind = :any
      u = url
      return false if u.empty?
      case kind
      when :local then url.local_file?
      when :remote then !url.local_file?
      else true
      end
    end

=begin rdoc
Whether or not the document is pristine

A document is pristine if it is empty, unmodified and not associated with a
file. For example, {Ruber::Document.new} returns a pristine file only if the second argument
is *nil* (otherwise, the document has a file associated with it and so it isn\'t
pristine).
@return [Boolean] *true* if the document is pristine and *false* otherwise
=end
    def pristine?
      @doc.url.empty? and !@doc.modified? and @doc.text.nil?
    end
    
=begin rdoc
Whether the document is modified on disk

A document is modified on disk if the file associated with it has been changed
outside the editor, that is if its contents are different from what they were
when the document was opened or last saved.
@return [Boolean] *true* if the document has been modified outside the editor
  and *false* otherwise. If the document isn't associated with a file, this
  will always return *false*
=end
    def modified_on_disk?
      @modified_on_disk
    end

=begin rdoc
Saves the document

If the document is associated with a file, its contents will be written in that
file. If there's no file associated with it, or if the document is read only,
a Save As dialog will be shown, allowing the user to choose the file where to
save it.

After the documents contents have been saved, all the document projects associated
with the document are also saved

This method is associated with the Save menu entry

@return [Boolean] *true* if the document was saved and *false* otherwise (maybe
  because an error occurred or because the user canceled the Save As dialog)
=end
    def save
      if path.empty? || !is_read_write then document_save_as
      else 
        res = @doc.save
        save_projects
        res
      end
    end
    slots :save

=begin rdoc
Creates a view for the document
@param [World::Environment,nil] env the environment the new view will live in. 
  If *nil*, the active environment will be used
@param [Qt::Widget,nil] parent the parent of the new view
@return [EditorView] the new view
=end
    def create_view env = nil, parent = nil
      env ||= @world.active_environment
      inner_view = @doc.create_view nil
      view = EditorView.new self, inner_view, parent
      @views << view
      view.environment = env
      gui = view.send(:internal)
      action = gui.action_collection.action('file_save_as')
      disconnect action, SIGNAL(:triggered), @doc, SLOT('documentSaveAs()')
      connect action, SIGNAL(:triggered), self, SLOT(:document_save_as)
      action = gui.action_collection.action('file_save')
      disconnect action, SIGNAL(:triggered), @doc, SLOT('documentSave()')
      connect action, SIGNAL(:triggered), self, SLOT(:save)
      connect view, SIGNAL('closing(QWidget*)'), self, SLOT('close_view(QWidget*)')
      emit view_created(view, self)
      view
    end
    
=begin rdoc
The wider project the document belongs to in an environment

If the file associated with the document belongs to the global project living
in the given environment, that global project is the wider project associated
the document belongs to; otherwise the document's own project living in the
given environment is the wider one the document belongs to

If there's no project associated with the given environment, the document's own
project living in that environment will always be used

@param [World::Environment,nil] env the environment whose project to consider.
  If *nil*, the active environment will be used
@return [AbstractProject] the wider project the document belongs to in the
  environment _env_
=end
    def project env = nil
      env ||= Ruber[:world].active_environment
      prj = env.project
      if prj and prj.file_in_project?(url.to_encoded.to_s) then prj
      else @projects[env] || create_project(env)
      end
    end
    
=begin rdoc
The document project associated with the document in a given environment

@param [World::Environment,nil] env the environment the document project should
  live in. If not given, the active environment is used
@return [DocumentProject] a document project living in the environment _env_.
  If no such a document project exists, one will be created
=end
    def own_project env = nil
      env ||= Ruber[:world].active_environment
      @projects[env] || create_project(env)
    end
    
=begin rdoc
Saves all the document projects associated with the document
@return [nil]
=end
    def save_settings
      save_projects
      nil
    end

=begin rdoc
The path of the file associated with the document
@return [String] the path of the file associated with the document or an empty
  string if the document is not associated with a file
=end
    def path
      @doc.url.path || ''
    end

=begin rdoc
The document's text

@return [String]

@overload text
  The text in the whole document
  @return [String] the text in the whole document
@overload text range, block = false
  The text contained in the given range
  @param [KTextEditor::Range] range the range of text to retrieve
  @param [Boolean] block whether or not to consider the range as a visual block
  @return [String] the text inside the range. An empty string is returned if
    the range is invalid
@note We can't just delegate this method to the internal @KTextEditor::Document@
because its @text@ method returns nil if there's no text in the document, instead
of an empty string.
=end
    def text *args
      @doc.text(*args) || ''
    end
    
=begin rdoc
Override of @KTextEditor::Document#line@

@param [Integer] n the line number
@return [String] the text in the given line or an empty string if the line is out
  of range
@note We can't just delegate this method to the internal @KTextEditor::Document@
because its @line@ method returns nil if there's no text in the line, instead
of an empty string.
=end
    def line n
      @doc.line(n) || ''
    end
    
=begin rdoc
Executes a block between a call to @#start_editing@ and @#end_editing@

@yield the block to call between @#start_editing@ and @#end_editing@
@return [Object] the value returned by the block
=end
    def editing
      begin
        @doc.start_editing
        yield
      ensure @doc.end_editing
      end
    end
    
=begin rdoc
Closes the document, possibly asking the user about unsaved changes

When closing the document, the following actions are performed:
* the {#closing} signal is emitted
* all the document projects associated with the document are saved
* all the views associated with the document are closed
* the @#close_url@ method of the @KTextEditor::Document@ used by the document
  is called
* all the document projects associated with the document are closed
* the document is scheduled for disposing (using @#delete_later@)

If _ask_ is true, the user will be asked whether to close the document if there
are unsaved changes. Also, each document project's {AbstractProject#query_close #query_close}
method will be called
@param [Boolean] ask whether to ask the user what to do if there are unsaved
  changes
@return [Boolean] *true* if the document was closed and *false* if the user
  chose to abort closing or one of the document projects' {AbstractProject#query_close #query_close}
  method returned false.
    
  If _ask_ is false, always returns *true*
=end
    def close ask = true
      if !ask || can_close?
        emit closing(self)
        save_projects
        @views.dup.each{|v| v.close}
        close_url false
        @projects.each_value{|prj| prj.close false}
        delete_later
        self.disconnect
        @projects.clear
        true
      else false
      end
    end
  
=begin rdoc
Whether the document can be closed or not

To decide whether the document can be closed, the {AbstractProject#query_close #query_close}
method of all document projects associated with the document are called. Also,
if the argument is *true*, also  the document's @query_close@ method is called.

@param [Boolean] call_query_close whether or not @#query_close@ should be called
  to check whether the document can be closed
@return [Boolean] whether or not the document can be closed
=end
    def can_close? call_query_close = true
      if call_query_close
        return false unless query_close
      end
      @projects.each_value{|pr| return false unless pr.query_close}
      true
    end
        
=begin rdoc
@return [KTextEditor::Document] The @KTextEditor::Document@ associated with the document
=end
    def part
      internal
    end
    
    private
    
=begin rdoc
Override of @KTextEditor::Document#documentSave@

It works as the base class version, but uses either the document's directory
or the active project's directory as starting directories.

There's another small difference with @KTextEditor::Document#documentSave@:
in that method, the encoding initially selected in the combo box is read from the
configuration. Since I couldn't figure how to access that, instead, the default
encoding here is set to UTF-8 if using ruby 1.9 and to ISO-8859-1 if using ruby
1.8
@return [Boolean] *true* if the file was successfully saved and *false* otherwise
=end
    def document_save_as
      enc = RUBY_VERSION.match(/1\.9/) ? 'UTF-8' : 'ISO-8859-1'
      prj = Ruber[:world].active_project
      path = if !self.path.empty? then self.path
      elsif prj then prj.project_directory
      else ''
      end
      
      res = KDE::EncodingFileDialog.get_save_file_name_and_encoding enc, path, '', 
          Ruber[:main_window], KDE.i18n('Save File')
      return false if res.file_names.empty? or res.file_names.first.empty?
      u = KDE::Url.new res.file_names.first
      if u.is_local_file and File.exist?(u.path)
        ans = KDE::MessageBox.warning_continue_cancel Ruber[:main_window],
            KDE.i18n(format("A file named \"%s\" already exists. \nAre you sure you want to overwrite it?", u.path)),
            i18n( "Overwrite File?" ), KDE::StandardGuiItem.overwrite,
            KDE::StandardGuiItem.cancel, '', KDE::MessageBox::Notify | KDE::MessageBox::Dangerous
        return false if ans == KDE::MessageBox::Cancel
      end
      @doc.encoding = res.encoding
      save_projects
      @doc.saveAs u
    end
    slots :document_save_as

=begin rdoc
Saves all the document projects associated with the project
@return [nil]
=end
    def save_projects
      @projects.each_value{|prj| prj.save}
      nil
    end
    
=begin rdoc
Creates a document project living in the given environment
@param [World::Environment] env the environment the new document project should
  live in
@return [DocumentProject] the new document project
@note This method won't check if a document project living in the existing environment
  already exists
=end
    def create_project env
      prj = DocumentProject.new self, env
      @projects[env] = prj
      prj.finalize
      connect env, SIGNAL('closing(QObject*)'), self, SLOT('environment_closing(QObject*)')
      prj
    end
    
=begin rdoc
Slot called whenever an environment with a document project living in it is
  closed
@param [World::Environment] env the closing environment
@return [nil]
=end
    def environment_closing env
      prj = @projects[env]
      if prj
        prj.close true
        @projects.delete env
      end
      nil
    end
    slots 'environment_closing(QObject*)'
    
=begin rdoc
Slot called whenever one of the views associated with the document is closed
@param [EditorView] view the closing view
@return [nil]
=end
    def close_view view
      emit closing_view view, self
      @views.delete view
      nil
    end
    slots 'close_view(QWidget*)'

  end
  
end