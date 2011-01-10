=begin
    Copyright (C) 2010,2011 by Stefano Crocco   
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

require 'ruber/plugin'
require 'yaml'

require 'facets/hash/mash'

require_relative 'ui/config_widget'

module Ruber

=begin rdoc
Plugin which allows Ruber to store and restore back its state.

In this context, the term _state_ means the open project and documents, the tabs
in the main window, the editors in each tab, the position of the cursor in the
editors and the active editor. All this data is stored
in the configuration file and in the project or document project files. Using
the API provided by this plugin, it is possible to restore a single document,
project or the whole application to the state it was when it was last closed.

In addition to providing an API for saving and restoring state, this plugin also
restores the full Ruber state when restoring a session and (according to the
user preferences) when the application starts up.

@api feature state
@plugin
=end
  module State
    
=begin rdoc
Plugin object for the State plugin

@api_method #with
@api_method #restore
@api_method #restore_document
@api_method #restore_project
=end
    class Plugin < Ruber::Plugin
      
=begin rdoc
@param [Ruber::PluginSpecification] psf the plugin specification object associated
with the plugin
=end
      def initialize psf
        super
        @force_restore_project_files = nil
        @force_restore_cursor_position = nil
      end
      
=begin rdoc
Override of {PluginLike#delayed_initialize}

If the application is starting and there's no open project and a single, pristine
document, it uses the {#restore_last_state} method to restore the last state Ruber
was according to the user preferences.

@return [nil]
=end
      def delayed_initialize
        return unless Ruber[:app].starting?
        if Ruber[:projects].to_a.empty? and Ruber[:docs].to_a.size == 1 and
                 Ruber[:docs][0].pristine?
          restore_last_state
        end
        nil
      end
      
=begin rdoc
Tells whether or not the cursor position should be restored.

This takes into account user settings and eventual requests made by the programmer
using the {#with} method
@return [Boolean] *true* if the cursor position should be restored and *false*
otherwise
=end
      def restore_cursor_position?
        if @force_restore_cursor_position.nil?
          Ruber[:config][:state, :restore_cursor_position]
        else @force_restore_cursor_position
        end
      end

=begin rdoc
Tells whether or not the open files in the project should be restored.

This takes into account user settings and eventual requests made by the programmer
using the {#with} method
@return [Boolean] *true* if the open files in the project should be restored and *false*
otherwise
=end
      def restore_project_files?
        if @force_restore_project_files.nil?
          Ruber[:config][:state, :restore_project_files]
        else @force_restore_project_files
        end
      end
      
=begin rdoc
Executes a block temporarily overriding the user's settings about what should be
restored and what shouldn't.

Nested calls to this method are allowed. By default, the outer call wins over the
inner, meaning that a value set by the inner call are only used if the outer
call didn't set that value. You can change this behaviour by passing the @:force@
option.
@param [Hash] hash the settings to change. All settings not specified here will
remain as chosen by the user
@option hash [Boolean] :force (false) if *true*, in case of a nested call to this
method, the values specified by the inner call will override values set by the
outer call.
@option hash [Boolean] :restore_cursor_position (false) whether or not the cursor position
in documents should be restored, regardless of what the user chose
@option hash [Boolean] :restore_project_files (false) whether or not the open
files in projects should be restored, regardless of what the user chose
@return [Object] the value returned by the block
=end
      def with hash
        old_doc = @force_restore_cursor_position
        old_projects = @force_restore_project_files
        if hash.has_key? :restore_cursor_position
          if @force_restore_cursor_position.nil? or hash[:force]
            @force_restore_cursor_position = hash[:restore_cursor_position] || false 
          end
        end
        if hash.has_key? :restore_project_files
          if @force_restore_project_files.nil? or hash[:force]
            @force_restore_project_files = hash[:restore_project_files] || false 
          end
        end
        begin yield
        ensure
          @force_restore_cursor_position = old_doc
          @force_restore_project_files = old_projects
        end
      end
      
=begin rdoc
Restores the given document

@see DocumentExtension#restore DocumentExtension#restore for more information

@param [Ruber::Document] doc the document to restore
@return [nil]
=end
      def restore_document doc
        doc.extension(:state).restore
      end

=begin rdoc
Restores the given global project

@see ProjectExtension#restore ProjectExtension#restore for more information

@param [Ruber::Project] prj the document to restore
@return [nil]
=end
      def restore_project prj
        prj.extension(:state).restore
      end
      
=begin rdoc
Restores the open projects according to a given configuration object

Restoring the project means closing all the open projects and opening the projects
and setting the active project according to the information in _conf_

This method is called both when the session is restored and when ruber starts
up (if the user chose so).

@param [#[Symbol, Symbol]] conf the object from which to read the state. See {#restore}
for more information
@return [nil]
=end
      def restore_projects conf = Ruber[:config]
        projects = Ruber[:projects]
        projects.to_a.each{|pr| projects.close_project pr}
        file = conf[:state, :open_projects][0]
        if file
          prj = Ruber[:main_window].safe_open_project file
          Ruber[:projects].current_project = prj if prj
        end
        nil
      end

=begin rdoc
Restores the open documents according to a given configuration object

Restoring the open documents means:


This method is called both when the session is restored and when ruber starts
up (if the user chose so).

@param [#[Symbol, Symbol]] conf the object from which to read the state. See {#restore}
for more information
@return [nil]
=end
      def restore_documents config = Ruber[:config]
        return unless Ruber[:documents].close_all
        docs = config[:state, :open_documents]
        unnamed_docs = []
        docs = docs.map do |i| 
          if i.is_a?(String) then Ruber[:documents].document(i)
          else 
            doc = Ruber[:documents].new_document
            unnamed_docs << doc
            doc
          end
        end
        return if docs.empty?
        tabs = config[:state, :tabs]
        mw = Ruber[:main_window]
        positions = config[:state, :cursor_positions]
        tabs.each_with_index do |t, i| 
          pn = restore_pane t, unnamed_docs
          views = pn.to_a
          views.each_with_index do |v, j|
            cursor = KTextEditor::Cursor.new(*(positions[i][j] rescue [0,0]))
            v.cursor_position = cursor
          end
        end
        active_editor = config[:state, :active_view]
        if active_editor
          mw.focus_on_editor mw.tabs[active_editor[0]].to_a[active_editor[1]]
        end
      end
      
      def restore_pane data, docs
        mw = Ruber[:main_window]
        find_first_view = lambda do |array|
          if array.size == 1 then array[0]
          elsif array[1].is_a? Array then find_first_view.call array[1]
          else array[1]
          end
        end
        recreate_pane = lambda do |pn, array|
          orientation = array[0]
          last_view = pn.view
          array.each_with_index do |e, i|
            #the first element of the array is the orientation; the second is
            #the first view, which is already contained in the pane
            next if i < 2 
            view = e.is_a?(Array) ? find_first_view.call(e) : e
            view = mw.editor_for! view.is_a?(String) ? view: docs[view], 
                        :existing => :never, :show => false
            pn.split last_view, view, orientation
            last_view = view
            recreate_pane.call view.parent, e if e.is_a? Array
          end
          recreate_pane.call pn.splitter.widget(0), array[1] if array[1].is_a?(Array)
        end
        view = find_first_view.call data
        view = mw.editor_for! view.is_a?(String) ? view : docs[view], 
                      :existing => :never, :new => :new_tab
        pane = view.parent
        recreate_pane.call pane, data
        pane
      end
      
=begin rdoc
Restores ruber state according to the user settings and the data stored in the given object

The argument can be any object which has a @[]@ method which takes two arguments
and behaves as the hash returned by {#gather_settings}.

@param [#[Symbol, Symbol]] conf the object from which to read the state
@return [nil]
=end
      def restore cfg = Ruber[:config]
        if !cfg[:state, :open_projects].empty? then restore_projects cfg
        else restore_documents cfg
        end
        nil
      end

=begin rdoc
Restores Ruber's state according to the user settings so that it matches the state
it was when it was last shut down

The state information is read from the global configuration object.

@return [nil]
=end
      def restore_last_state
        case Ruber[:config][:state, :startup_behaviour]
        when :restore_all then restore
        when :restore_projects_only
          with(:restore_project_files => false){restore_projects}
        when :restore_documents_only then restore_documents
        end
      end
      
=begin rdoc
Restores Ruber's state as it was in last session

Since this method deals with session management, it ignores the user settings

@return [nil]
=end
      def restore_session data
        hash = data['State'] || {:open_projects => [], :open_documents => [], :active_view => nil, :tabs => []}
        hash = hash.map_hash{|k, v| [[:state, k], v]}
        def hash.[] k, v
          super [k, v]
        end
        with(:restore_project_files => true, :restore_cursor_position => true, :force => true) do
          restore hash
        end
        nil
      end
      
=begin rdoc
Saves Ruber's state to the global config object

@return [nil]
=end
      def save_settings
        h = gather_settings
        cfg = Ruber[:config]
        h.each_pair do |k, v| 
          cfg[:state, k] = v
        end
        nil
      end
      
=begin rdoc
Override of {PluginLike#session_data}

@return [Hash] a hash containing the session information under the @State@ key
=end
      def session_data
        {'State' => gather_settings}
      end
      
      def projects_state
        projects = Ruber[:projects].projects.map{|pr| pr.project_file}
        unless projects.empty?
          active_prj = Ruber[:projects].current
          projects.unshift projects.delete(active_prj.project_file) if active_prj
        end
        projects
      end
      
      def documents_state
        docs = Ruber[:documents].documents
        docs.map{ |doc| doc.has_file? ? doc.url.to_encoded.to_s : nil}
      end
      
      def tabs_state
        res = {}
        doc_map = {}
        doc_idx = 0
        Ruber[:documents].each do |doc|
          if !doc.has_file?
            doc_map[doc] = doc_idx
            doc_idx += 1
          end
        end
        tabs = Ruber[:main_window].tabs
        tabs_tree = []
        cursor_positions = []
        tabs.each do |t|
          tabs_tree << tab_to_tree(t, doc_map)
          cursor_positions << t.map do |v|
            pos = v.cursor_position
            [pos.line, pos.column]
          end
        end
        res[:tabs] = tabs_tree
        res[:cursor_positions] = cursor_positions
        active = Ruber[:main_window].active_editor
        if active
          active_tab = Ruber[:main_window].tab(active)
          res[:active_view] = [tabs.index(active_tab), active_tab.to_a.index(active)]
        end
        res
      end
      
      private
      
=begin rdoc
Creates a hash with all the data needed to restore Ruber's state

@return [Hash] a hash with the following keys:
 * @:open_projects@: an array containing the project file of each open project.
  the first entry is the active project
 * @:open_documents@: an array with the name of the file corresponding to each
  open document (documents without an associated file can't be restored and aren't
  included). The order is that of opening
 * @:visible_documents@: an array with the name of the files corresponding to the
  documents associated with a file and having a view
 * @:active_document@: the name of the file associated with the active document or
  *nil* if there's no open document
=end
      def gather_settings
        res = {
          :open_projects => projects_state,
          :open_documents => documents_state
        }
        res.merge! tabs_state
        res
      end
      
      def tab_to_tree pane, docs
        if pane.single_view?
          doc = pane.view.document
          return [doc.has_file? ? doc.url.url : docs[doc]]
        end
        panes = {}
        tab_to_tree_prc = lambda do |pn|
          if pn.single_view?
            doc = pn.view.document
            panes[pn.parent_pane] << (doc.has_file? ? doc.url.url : docs[doc])
          else 
            data = [pn.orientation]
            panes[pn] = data
            panes[pn.parent_pane] << data if pn.parent_pane
          end
        end
        tab_to_tree_prc.call pane
        pane.each_pane :recursive, &tab_to_tree_prc
        panes[pane]
      end
      
    end
    
=begin rdoc
Extension for documents needed by the State plugin

The scope of this extension is to save and restore the position of the cursor
in the document
=end
    class DocumentExtension < Qt::Object
      
      include Extension
      
      slots 'auto_restore(QObject*)'
      
=begin rdoc
@param [Ruber::DocumentProject] prj the project associated with the document
=end
      def initialize prj
        super
        @last_view = nil
        @project = prj
        @document = prj.document
        connect @document, SIGNAL('view_created(QObject*, QObject*)'), self, SLOT('auto_restore(QObject*)')
        connect @document, SIGNAL('closing_view(QWidget*, QObject*)'), self, SLOT('view_closing(QWidget*)')
      end
      
=begin rdoc
Restores the position of the cursor according to the value saved in the document's
own project

It does nothing if the document isn't associated with a view
@return [nil]
=end
      def restore view
        if @last_view then view.cursor_position = @last_view.cursor_position
        else
          pos = @document.own_project[:state, :cursor_position]
          view.go_to *pos
        end
        nil
      end
      
=begin rdoc
Saves the position of the cursor in the document's own project

It does nothing if the document isn't associated with a view
@return [nil]
=end
      def save_settings
        if @last_view
          cur = @last_view.cursor_position
          pos = [cur.line, cur.column]
          @project[:state, :cursor_position] = pos
        end        
        nil
      end
      
      private
      
=begin rdoc
Moves the cursor in a new view to the position stored in the document's own project

It does nothing if the user chose not to have the position restored when opening
a document.
@return [nil]
=end
      def auto_restore view
        restore view if Ruber[:state].restore_cursor_position?
        connect view, SIGNAL('focus_in(QWidget*)'), self, SLOT('view_received_focus(QWidget*)')
        nil
      end
      
      def view_received_focus view
        @last_view = view
      end
      slots 'view_received_focus(QWidget*)'
      
      def view_closing view
        if view == @last_view
          save_settings
          @last_view = nil
        end
      end
      slots 'view_closing(QWidget*)'
      
    end
    
=begin rdoc
Extension for projects needed by the State plugin

The scope of this extension is to save and restore the open documents associated
with projects
=end
    class ProjectExtension < Qt::Object
      
      include Extension
      
      slots :auto_restore, :save_settings
      
=begin rdoc
@param [Ruber::Project] prj the project associated with the extension
=end
      def initialize prj
        super
        @project = prj
        connect @project, SIGNAL(:activated), self, SLOT(:auto_restore)
        connect @project, SIGNAL(:deactivated), self, SLOT(:save_settings)
      end
      
=begin rdoc
Opens all the files associated with the proejct which were opened last time the
project's state was changed

Any already open document is closed (after saving)

@return [nil]
=end

      def restore
        Ruber[:state].restore_documents @project
        nil
      end
      
=begin rdoc
Saves the list of open project files to the project

@return [nil]
=end
      def save_settings
        @project[:state, :open_documents] = Ruber[:state].documents_state
        tabs_state = Ruber[:state].tabs_state
        [:tabs, :cursor_positions, :active_view].each do |e|
          @project[:state, e] = tabs_state[e]
        end
        nil
      end
      
      private

=begin rdoc
Opens all the files associated with the proejct which were opened last time the
project's state was changed when the project is opened.

Any already open document is closed (after saving).

It does nothing if the user chose not restore open project files when opening a
project.
@return [nil]
=end
      def auto_restore
        @project.disconnect SIGNAL(:activated), self, SLOT(:auto_restore)
        restore if Ruber[:state].restore_project_files?
      end
      
    end
    
=begin rdoc
Configuration widget for the State plugin
=end
    class ConfigWidget < Qt::Widget
      
=begin rdoc
A list of different behaviour the plugin can have at startup
=end
      STARTUP_BEHAVIOURS = [:restore_all, :restore_documents_only, :restore_projects_only, :restore_nothing]
      
=begin rdoc
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::StateConfigWidget.new
        @ui.setup_ui self
      end
      
=begin rdoc
Selects the correct startup behaviour in the associated widget

@param [Symbol] val the symbol stored in the configuration object. It must be one
of the entries in {STARTUP_BEHAVIOURS}
=end
      def startup_behaviour= val
        @ui._state__startup_behaviour.current_index = STARTUP_BEHAVIOURS.index val
        nil
      end
      
=begin rdoc
Returns the symbol associated with the startup behaviour selected in the widget
@return [Symbol] the entry in {STARTUP_BEHAVIOURS} corresponding to the selected
entry in the _Startup behaviour_ widget
=end
      def startup_behaviour
        STARTUP_BEHAVIOURS[@ui._state__startup_behaviour.current_index]
      end
      
    end
      
  end
  
end