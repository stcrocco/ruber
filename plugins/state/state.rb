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

Documents which haven't been saved to a file are only partially restored: an empty
document is created for them (different views associated with the same document
will correctly be associated with the same empty document after restoration). Unsaved
changes in documents not associated with files won't be restored.

In addition to providing an API for saving and restoring state, this plugin also
restores the full Ruber state when restoring a session and (according to the
user preferences) when the application starts up.

@api feature state
@plugin
=end
  module State
    
    module EnvironmentState
      
=begin rdoc
The open tabs configuration in a form suitable to be written to a configuration object

@return [Hash] A hash containing the following keys:
 * @:tabs@: an array of arrays, with each inner array representing one tab, with
  the format described in {#restore_pane}. This value is the one to write under
  the @state/tabs@ entry in a project or configuration object
 * @:cursor_positions@:an array of arrays. Each inner array corresponds to a tab
  and contains the cursor position of each view. Each cursor position is represented
  as an array with two elements: the first is the line, the second is the column.
  The order the views are is the same used by {Pane#each_view}. This value is the one to write under
  the @state/cursor_positions@ entry in a project or configuration object
 * @:active_view@: the active view. It is represented by a size 2 array, with the
  first element being the index of the tab of the active view and the second being
  the index of the view in the corresponding pane (according to the order used by
  {Pane#each_view}). If there's no active view, this entry is *nil*. This is the value to write under
  the @state/active_view@ entry in a project or configuration object
=end
      def tabs_state env
        res = {}
        doc_map = {}
        doc_idx = 0
        env.documents.each do |doc|
          if !doc.has_file?
            doc_map[doc] = doc_idx
            doc_idx += 1
          end
        end
        tabs = env.tabs
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
        active = env.views[0]
        if active
          active_tab = env.tab(active)
          res[:active_view] = [tabs.index(active_tab), active_tab.to_a.index(active)]
        end
        res
      end
      
      def restore_environment env, data
        unnamed_docs = []
        env.close_editors env.views, false
        data[:tabs].each_with_index do |t, i|
          restore_tab env, t, data[:cursor_positions][i] || [], unnamed_docs
        end
        active_editor = data[:active_view]
        if active_editor
          editor = env.tabs[active_editor[0]].to_a[active_editor[1]]
          env.activate_editor editor
          editor.set_focus if editor
        end
      end
      
=begin rdoc
Restores a pane

Restoring a pane means creating the editors which were contained in the pane,
in the correct disposition.

The contents of the pane are described by the array _data_, which has the following
format:

* if it has a single element, the corresponding pane contains only a view. If the
  element is a string, it must represent the URL of the document the view is associated
  with. If it is a number, it means the view is associated with a document which
  hasn't been saved
* if it has more than one element, it means that the pane contains more than one
  view. The first element represents the orientation of the pane and can be either
  @Qt::Horizontal@ or @Qt::Vertical@. The other elements can be either strings,
  numbers or arrays. A string or number means, as above, the URL of the document
  associated with the view or a document which isn't associated with a file. An
  array (which should have the same format as this) means a sub pane
@param [Array] data the array containing the description of the contents of the
  pane
@param [Array<Document>] docs the document not associated with files to use for
  the numeric entries of _data_. A number _n_ in _data_ means to use the entry
  _n_ in _docs_
@return [Pane] the new pane
=end
      def restore_tab env, tab, cursor_positions, unnamed_docs
        world = Ruber[:world]
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
            if view.is_a?(String) 
              doc = world.document(KDE::Url.new(view)) || world.new_document
            else doc = unnamed_docs[view] ||= world.new_document
            end
            view = doc.create_view
            pn.split last_view, view, orientation
            last_view = view
            recreate_pane.call view.parent, e if e.is_a? Array
          end
          recreate_pane.call pn.splitter.widget(0), array[1] if array[1].is_a?(Array)
        end
        view = find_first_view.call tab
        if view.is_a?(String) 
          doc = world.document(KDE::Url.new(view))
        else doc = unnamed_docs[view] ||= Ruber[:world].new_document
        end
        view = env.editor_for! doc, :existing => :never, :new => :new_tab
        pane = view.parent
        recreate_pane.call pane, tab
        pane.views.each_with_index do |v, i|
          pos = cursor_positions[i]
          v.go_to *pos if pos
        end
        pane
      end
      
      private
      
=begin rdoc
A representation of a pane's configuration suitable to be written to a configuration
object

@param [Pane] pane the pane to return the representation for
@param [Hash{Document=>Integer}] docs a map between documents not associated
  with files and the number to represent them
@return [Array<Array,Integer,String>] an array as described in {#restore_pane}
=end
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
Plugin object for the State plugin
=end
    class Plugin < Ruber::Plugin
      
      include EnvironmentState
      
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
        docs = Ruber[:world].documents
        if Ruber[:world].projects.empty? and docs.size == 1 and docs[0].pristine?
          Ruber[:app].sessionRestored? ? restore_last_state(:force) : restore_last_state
        end
        connect Ruber[:world], SIGNAL('project_created(QObject*)'), self, SLOT('restore_project(QObject*)')
        nil
      end

      def restore_project prj
        prx = prj[:state]
        data = {
          :tabs => prx[:tabs],
          :cursor_positions => prx[:cursor_positions],
          :active_view => prx[:active_view]
        }
        env = Ruber[:world].environment(prj)
        if Ruber[:config][:state, :restore_projects] and env.tabs.count == 0
          restore_environment env, data
        end
      end
      slots 'restore_project(QObject*)'
           
=begin rdoc
Restores Ruber's state according to the user settings so that it matches the state
it was when it was last shut down

The state information is read from the global configuration object.

@return [nil]
=end
      def restore_last_state mode = nil
        force = mode == :force
        cfg = Ruber[:config][:state]
        if force or cfg[:startup_behaviour].include? :default_environment
          default_env_data = {
            :tabs => cfg[:default_environment_tabs],
            :active_view => cfg[:default_environment_active_view],
            :cursor_positions => cfg[:default_environment_cursor_positions]
          }
          restore_environment Ruber[:world].default_environment, default_env_data
        end
        active_prj = nil
        if force || cfg[:startup_behaviour].include?(:projects)
          cfg[:last_state].each_with_index do |f, i|
            next if f.nil?
            begin prj = Ruber[:world].project f
            rescue Ruber::AbstractProject::InvalidProjectFile
              next
            end
            active_prj = prj if i == 0
            data = {
              :tabs => prj[:state, :tabs],
              :cursor_positions => prj[:state, :cursor_positions],
              :active_view => prj[:state, :active_view]
            }
            restore_environment Ruber[:world].environment(prj), data
          end
          Ruber[:world].active_project = active_prj
        end
      end
            
=begin rdoc
Saves Ruber's state to the global config object

@return [nil]
=end
      def save_settings
        files = Ruber[:world].environments.map do |e|
          prj = e.project
          prj ? prj.project_file : nil
        end
        active_env = Ruber[:world].active_environment
        if active_env and active_env.project
          active_project = active_env.project.project_file
        else active_project = nil
        end
        files.unshift files.delete(active_project)
        Ruber[:config][:state, :last_state] = files
        default_env_state = tabs_state Ruber[:world].default_environment
        Ruber[:config][:state, :default_environment_tabs] = default_env_state[:tabs]
        Ruber[:config][:state, :default_environment_active_view] =
            default_env_state[:active_view]
        Ruber[:config][:state, :default_environment_cursor_positions] = 
            default_env_state[:cursor_positions]
        nil
      end
      
=begin rdoc
The open projects in a form suitable to be written to a configuration object

@return [Array<String>] an array containing the names of the project files for
  the currently open projects. The active project is the first one. This value
  is the one to write under the @state/open_projects@ entry in a project or configuration
  object
=end
      def projects_state
        projects = Ruber[:world].projects.map{|pr| pr.project_file}
        unless projects.empty?
          active_prj = Ruber[:world].active_document
          projects.unshift projects.delete(active_prj.project_file) if active_prj
        end
        projects
      end
      
    end
    
=begin rdoc
Extension for documents needed by the State plugin

The scope of this extension is to move the cursor of all newly created views
associated with the document to the position it was in the last used view. The
cursor position for the first view is read from the document's own project, where
it is saved whenever the document is closed.

The cursor position for a view is moved in response to the {Document#view_created}
signal.
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
Moves the cursor of a view to the position it was in the last used view

If there are no other views associated with the document, the position of the
cursor is read from the document's own project
@param [EditorView] the view to move the cursor for
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
Restores the cursor position for a view if the user choosed to do so

It does nothing if the user choosed not to restore the cursor position when a view
is created

@param [EditorView] the view to restore the cursor position for
@return [nil]
=end
      def auto_restore view
        restore view if Ruber[:config][:state, :restore_cursor_position] #.restore_cursor_position?
        connect view, SIGNAL('focus_in(QWidget*)'), self, SLOT('view_received_focus(QWidget*)')
        nil
      end
      
=begin rdoc
Memorizes which view has last received focus

This information is used to decide which view to ask for the cursor position when
a new view is created or the cursor position needs to be saved to the project
@param [EditorView] view the view which has received focus
@return [nil]
=end
      def view_received_focus view
        @last_view = view
        nil
      end
      slots 'view_received_focus(QWidget*)'
      
=begin rdoc
Method called whenever a view associated with the document is closed

If the closed view is the one which last got focus, its cursor position is saved
in the document's own project. Otherwise nothing is done. 
@param [EditorView] view the view being closed
@return [nil]
=end
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

The scope of this extension is to save and restore the state of the tabs open
when the project was last closed
=end
    class ProjectExtension < Qt::Object
      
      include Extension
      
      include EnvironmentState
      
      slots :auto_restore, :save_settings
      
=begin rdoc
@param [Ruber::Project] prj the project associated with the extension
=end
      def initialize prj
        super
        @project = prj
#         connect @project, SIGNAL(:activated), self, SLOT(:auto_restore)
#         connect @project, SIGNAL(:deactivated), self, SLOT(:save_settings)
      end
      
=begin rdoc
Saves Ruber's state to the project

The saved information is: the configuration of open tabs, the position of the cursor
in the views and the active view

@return [nil]
=end
      def save_settings
        state = tabs_state Ruber[:world].environment @project
        @project[:state, :tabs] = state[:tabs]
        @project[:state, :active_view] = state[:active_view]
        @project[:state, :cursor_positions] = state[:cursor_positions]
        nil
      end
      
    end
    
=begin rdoc
Configuration widget for the State plugin
=end
    class ConfigWidget < Qt::Widget
      
=begin rdoc
A list of different behaviour the plugin can have at startup
=end
      STARTUP_BEHAVIOURS = [
        [:default_environment, :projects],
        [:projects],
        [:default_environment],
        []
      ]
      
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