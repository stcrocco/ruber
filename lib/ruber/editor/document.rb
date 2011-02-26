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

require 'ktexteditor'
require 'forwardable'
require 'dictionary'

require 'ruber/editor/ktexteditor_wrapper'
require 'ruber/editor/editor_view'
require 'ruber/utils'
require 'ruber/document_project'

module Ruber
  
  class Document < Qt::Object
        
    extend Forwardable
    
    include Activable
    
    include KTextEditorWrapper

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
    
    signals 'modified_changed(bool, QObject*)', 'document_name_changed(QString, QObject*)',
'text_changed(QObject*)', 'about_to_close(QObject*)', 'about_to_reload(QObject*)', 
'document_url_changed(QObject*)', 'highlighting_mode_changed(QObject*)',
'mode_changed(QObject*)', 'text_modified(KTextEditor::Range, KTextEditor::Range, QObject*)',
'text_inserted(KTextEditor::Range, QObject*)', 'text_removed(KTextEditor::Range, QObject*)',
'view_created(QObject*, QObject*)', 'closing(QObject*)', :activated, :deactivated,
'modified_on_disk(QObject*, bool, KTextEditor::ModificationInterface::ModifiedOnDiskReason)',
'sig_query_close(bool*, bool*)', 'canceled(QString)', 'completed()', 'completed1(bool)',
'started(KIO::Job*)', 'set_status_bar_text(QString)', 'setWindowCaption(QString)'
    
=begin rdoc
Signal emitted before a view associated with the document is closed

When this signal is emitted, the view is still associated with the document, and
it is still included in the array returned by {#views}
@param [EditorView] view the view which is being closed
@param [Document] doc *self*
=end
    signals 'closing_view(QWidget*, QObject*)'
    
    slots :document_save_as, :save
    
    def inspect
      if disposed? then "< #{self.class} #{object_id} DISPOSED >"
      else super
      end
    end

=begin rdoc
Creates a new Ruber::Document.
=end
    def initialize parent = nil, file = nil
      super parent
      @active = false
      @doc = KTextEditor::EditorChooser.editor('katepart').create_document( self)
      initialize_wrapper @doc, self.class.instance_variable_get(:@signal_table)
      @views = []
      @all_views = []
      @doc.openUrl(file.is_a?(String) ? KDE::Url.from_path(file) : file) if file
      @annotation_model = AnnotationModel.new self
      interface('annotation_interface').annotation_model = @annotation_model
      interface('modification_interface').modified_on_disk_warning = true
      @modified_on_disk = false
      @project = DocumentProject.new self
      
      @doc.connect(SIGNAL('modifiedChanged(KTextEditor::Document*)')) do |doc|
        emit modified_changed(@doc.modified?, self)
      end
      @doc.connect(SIGNAL('documentUrlChanged(KTextEditor::Document*)')) do |doc|
        if !doc.url.remote_file?
          Ruber[:components].each_component{|c| c.update_project @project}
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
          ExceptionDialog.new e, nil, true, "An exception was raised when writing text. See issue number 6 at http://github.com/stcrocco/ruber/issues"
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
@overload views
  @return [Array<EditorView>] a list of all the views associated with the document
    which are currently visible when Ruber is visible
@overload views :all
  @return [Array<EditorView>] a list of all the views associated with the document,
    including the hidden ones
@return [Array<EditorView>] a list of the views assciated with the document
=end
    def views which = :visible
      (which == :all ? @all_views : @views).dup
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
Executes the action with name _name_ contained in document's view's action
collection. This is made by having the action emit the <tt>triggered()</tt> or
<tt>toggled(bool)</tt> signal (depending on whether it's a standard action or a
<tt>KDE::ToggleAction</tt>). In the second case, _arg_ is the argument passed to
the signal.

Returns *true* if _name_ is the name of an action and *false* otherwise.

<b>Note:</b> for this method to work, a view should have been created for the
document, otherwise this method will always return *false.
=end
    def execute_action name, arg = nil
      @view ? @view.execute_action( name, arg) : false
    end
    
=begin rdoc
Compares the mimetype and file name of the document with a list of mimetypes (
using <tt>KDE::MimeType#=~</tt>) and/or patterns (using <tt>File.fnmatch</tt>),
returning *true* if any of the comparisons is successful and
*false* if all fails. Both _mimetypes_ and _patterns_ can be either a string or
an array of strings (a single string will be treated as an array containing a
single string).

====Notes:
* if both _mimetypes_ and _patterns_ are empty, the comparison always returns *true*.
* if the document is not associated with a file (that is, if +path+ returns an
  empty string) it won't match any pattern. It will match the <tt>text/plain</tt>
  mimetype, however.
* only the basename of the file will be taken into account for pattern matching.
  For example, the pattern <tt>abc/xyz.jkl</tt> will match the pattern <tt>xyz.jkl</tt>,
  which wouldn't be the case if the whole filename was included.
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
Returns the document extension with name _name_ or *nil* if such an extension
doesn't exist
=end
    def extension name
      @project.extension name
    end
    
=begin rdoc
Returns an appropriate <tt>Qt::Icon</tt> for the document, depending on the mimetype and the 
status of the document.
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

Depending on the value of _which_ this method can also return *true* only if the
document is associated with a local file or with a remote file. In particular:
* if it's @:local@ this method will return *true* only if the document is associated
  with a local file
* if it's @:remote@, this method will return *true* only if the document is associated
  with a remote file
* with any other value, this method will return *true* if the document is associated
  with any file

@param [Symbol, Object] which the kind of files which are acceptable
@return [Boolean] *true* if the document is associated with a file of the kind
  matching _which_ and *false* otherwise
=end
    def has_file? which = :any
      u = url
      return false if u.empty?
      case which
      when :local then url.local_file?
      when :remote then !url.local_file?
      else true
      end
    end

=begin rdoc
Tells whether the document is _pristine_ or not. A pristine document is an empty,
unmodified document which hasn't a file associated with it. The document returned
by <tt>Document.new</tt> is pristine is the second argument is *nil*, but it's 
not pristine if a non-*nil* second argument was given (because in  that case the 
document has a file associated with it).
=end
    def pristine?
      @doc.url.empty? and !@doc.modified? and @doc.text.nil?
    end
    
=begin rdoc
Tells whether the document is modified on disk or not
=end
    def modified_on_disk?
      @modified_on_disk
    end

=begin rdoc
Saves the document. If the document is already associated with a file, it's saved
in that file; otherwise, a Save As dialog is displayed for the user to choose a
file name. Returns *true* if the document was saved and *false* if it wasn't for
some reason (for example, if the user doesn't have write perimission on the file
or if he pressed the Cancel button in the Save As dialog).

This method is associated with the Save menu entry
=end
    def save
      if path.empty? || !is_read_write then document_save_as
      else 
        res = @doc.save
        @project.save
        res
      end
    end

=begin rdoc
Creats a view for the document. _parent_ is the view's parent widget. Raises
+RuntimeError+ if the document already has a view.
=end
    def create_view parent = nil
      inner_view = @doc.create_view nil
      view = EditorView.new self, inner_view, parent
      @views << view
      @all_views << view
      gui = view.send(:internal)
      action = gui.action_collection.action('file_save_as')
      disconnect action, SIGNAL(:triggered), @doc, SLOT('documentSaveAs()')
      connect action, SIGNAL(:triggered), self, SLOT(:document_save_as)
      action = gui.action_collection.action('file_save')
      disconnect action, SIGNAL(:triggered), @doc, SLOT('documentSave()')
      connect action, SIGNAL(:triggered), self, SLOT(:save)
      view.connect(SIGNAL('closing(QWidget*)')) do |v| 
        emit closing_view v, self
        @views.delete v
        @all_views.delete v
      end
      view.connect(SIGNAL('about_to_hide(QWidget*)')){|w| @views.delete w}
      view.connect(SIGNAL('about_to_show(QWidget*)')) do |w| 
        @views << w unless @views.include? w
      end
      emit view_created(view, self)
      view
    end
    
=begin rdoc
Return the project with wider scope the document belongs to. This is:
* the current global project if it exists and the document is associated with a file
  belonging to it
* the document project if there's no active global project or the document isn't
  associated with a file or the file doesn't belong the global project
=end
    def project
      prj = Ruber[:projects].current
      return @project if path.empty? or !prj
      prj.project_files.file_in_project?(url.to_encoded.to_s) ? prj : @project
    end
    
=begin rdoc
Returns the DocumentProject associated with the document
=end
    def own_project
      @project
    end
    
    def save_settings
      @project.save unless path.empty?
    end

=begin rdoc
Returns the path of the document
=end
    def path
      @doc.url.path || ''
    end

=begin rdoc
The document's text

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
As @KTextEditor::Document#line@

@param [Integer] n the line number
@return [String] the text in the given line or an empty string if the line is out
  of range
=end
    def line n
      @doc.line(n) || ''
    end
    
=begin rdoc
Executes the given block inside a pair of <tt>start_editing</tt>/<tt>end_editing</tt>
calls.
=end
    def editing
      begin
        @doc.start_editing
        yield
      ensure @doc.end_editing
      end
    end
    
=begin rdoc
Closes the document. If _ask_ is *true*, the <tt>query_close</tt> method is called,
asking the user what to do if the document is modified. If the user confirms
closing or if there's no need of confirmation, the following happens:
* the <tt>closing(QObject*)</tt> signal is emitted
* the view (if it exists) is closed
* the <tt>close_url</tt> method is called
* all the documnent extensions are removed
* al singnals are disconnected from the document
* the document is disposed of

Returns *true* if the document was closed and *false* otherwise

TODO: maybe remove the argument, since this method is not called anymore at 
=end
    def close ask = true
      if !ask || query_close
        emit closing(self)
        @project.save unless path.empty?
        @all_views.dup.each{|v| v.close}
        return false unless close_url false
        @project.close false
        delete_later
        self.disconnect
        true
      else false
      end
    end
        
=begin rdoc
The <tt>KParts::Part</tt> associated with the document
=end
  alias_method :part, :internal
    
    private
    
=begin rdoc
Works like <tt>KTextEditor::Document#documentSave</tt> but sets the starting directory to
either the project directory, if there's an active project, or to the default script
directory otherwise.

<b>Note:</b> there's a small difference with <tt>KTextEditor::Document#documentSave</tt>.
In that method, the encoding initially selected in the combo box is read from the
configuration. Since I couldn't figure how to access that, instead, the default
encoding here is set to UTF-8 if using ruby 1.9 and to ISO-8859-1 if using ruby
1.8
=end
    def document_save_as
      enc = RUBY_VERSION.match(/1\.9/) ? 'UTF-8' : 'ISO-8859-1'
      prj = Ruber[:projects].current
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
      @project.save
      @doc.saveAs u
    end
   
=begin rdoc
A hash associating icon roles used by Document with icon names. It is used by
+ICONS+
=end
    ICON_NAMES = { 
      :modified => 'document-save',
      :modified_on_disk => 'dialog-warning'
      }
    
=begin rdoc
Hash containing a list of predefined icons, each associated with a role (usually
a symbol describing the icon's use).

At the beginning, this hash is empty. It is automatically filled by loading icons
according with the associations specified in <tt>ICON_NAMES</tt> as they're requested.
This is necessary because the hash is created when this file is read, which may
happen before the application is created.
=end
    ICONS = Hash.new do |h, k|
      icon = KDE::IconLoader.load_icon ICON_NAMES[k]
      h[k] = icon
    end

  end
  
  class AnnotationModel < KTextEditor::AnnotationModel
    
    include Enumerable
    
    Annotation = Struct.new :type, :line, :msg, :tool_tip, :data
    
    signals 'annotations_changed()', 'annotation_changed(int)'
    
    @annotation_types = {}
    
    class << self
      attr_reader :annotation_types
    end
    
    def self.register_annotation_type type, back = nil, fore = nil
      raise ArgumentError, "Annotation type #{type} has already been added" if 
      @annotation_types.has_key?(type)
      @annotation_types[type] = [back, fore].map{|i| i ? Qt::Variant.fromValue(i) : Qt::Variant.new}
    end
    
    def initialize doc
      super()
      @doc = doc
      @annotations = Dictionary.alpha
      connect self, SIGNAL('annotation_changed(int)'), self, SIGNAL('lineChanged(int)')
    end
    
    def add_annotation *args
      a = args.size == 1 ? args[0] : Annotation.new( *args )
      # TODO: see why this sometimes gives extremely weird errors
      #The begin/rescue clause is there to find out why sometimes I get a crash saying:
      # `<': comparison of Fixnum with Qt::Variant failed (ArgumentError)
      #       begin
      
      #         raise IndexError, "Invalid line: #{a.line}" unless a.line < @doc.lines
      #       rescue ArgumentError
      #         puts "a.line: #{a.line}(#{a.line.class})"
      #         puts "@doc.lines: #{@doc.lines}(#{@doc.lines.class})"
      #       end
      @annotations[a.line] = a
      emit annotations_changed
      emit annotation_changed( a.line)
    end
    
    def data line, role
      a = @annotations[line]
      return Qt::Variant.new unless a
      case role
      when Qt::DisplayRole then Qt::Variant.new a.msg
      when Qt::ToolTipRole then Qt::Variant.new a.tool_tip
      when Qt::ForegroundRole then self.class.annotation_types[a.type][1]
      when Qt::BackgroundRole then self.class.annotation_types[a.type][0]
      else Qt::Variant.new
      end
    end
    
    def annotation line
      @annotations[line]
    end
    alias_method :[], :annotation
    
    def has_annotation? line
      @annotations.has_key? line
    end
    
    def has_annotations?
      !@annotations.empty?
    end
    
    def empty?
      @annotations.empty?
    end
    
    def clear
      @annotations.clear
      emit annotations_changed
      emit reset
    end
    
    def remove_annotation line
      if @annotations.delete line
        emit annotations_changed 
        emit annotation_changed( line )
      end
    end
    
    def each
      @annotations.each_pair{|k, v| yield v}
    end
    
  end
  
end