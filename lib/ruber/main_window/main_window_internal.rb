=begin 
    Copyright (C) 2010, 2011 by Stefano Crocco   
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
    59 Temple Place - Suite g, Boston, MA  02111-1307, USA.             
=end

require 'facets/enumerable/sum'

module Ruber
  
  class MainWindow < KParts::MainWindow
    
=begin rdoc
A list of strings to be used to create the filter for open file dialogs
=end
    OPEN_DLG_FILTERS = [
      '*.rb|Ruby source file (*.rb)', 
      '*.yaml *.yml|YAML files (*.yaml, *.yml)',
      '*|All files'
      ]
    
    slots 'remove_view(QWidget*)', 'document_modified_changed(bool)',
        :document_url_changed, :next_document, :previous_document,
        'store_splitter_sizes(QString)', 'update_document_icon(QObject*)',
        'remove_plugin_ui_actions(QObject*)', 'close_project_files(QObject*)'
    
    protected
    
=begin rdoc
Override of @KParts::MainWindow#queryClose@ 
    
It calls the {Application#ask_to_quit ask_to_quit} method of the application.
@return [Boolean] what {Application#ask_to_quit} returns
=end
    def queryClose
      res = Ruber[:app].ask_to_quit
      res
    end
    
=begin rdoc
Override of @KParts::MainWindow#queryExit@

It calls the {Application#quit_ruber quit_ruber} method of the application
@return [TrueClass] *true*
=end
    def queryExit
      #There's a C++-side crash in any view is open after this method when closing
      #a session. As I have no clue as why this happens, for the time being, as
      #a workaround, we close all the documents.
      
      #For some reason, this method is called twice when closing a session
      #but only when Ruber is launched from the global installation (that is, typing
      #ruber in the shell), and not when testing from xsm. This causes a number of
      #problems, the most evident is the save_settings method being called twice,
      #one of the times after all documents have been closed. This obviously breaks
      #the state plugin. To avoid the issue, we use an instance variable to keep
      #trace of whether the method has already been called or not. Ruber[:app].quit_ruber
      #is only called the first time, while the documents are only closed the
      #second time
      if @query_exit_called
        Ruber[:world].close_all :documents, :discard
      else 
        Ruber[:app].quit_ruber
        @query_exit_called = true
      end
      true
    end
    
=begin rdoc
Saves the properties for session management

It also saves the plugins settings, using {ComponentManager#save_components_settings}

@return [nil]
=end
    def saveProperties conf
      Ruber[:components].save_components_settings
      data = YAML.dump @session_data 
      conf.write_entry 'Ruber', data
      nil
    end

=begin rdoc
Reads the properties from the config object for session management

@return [nil]
=end
    def readProperties conf
      @last_session_data = YAML.load conf.read_entry('Ruber', '{}')
      nil
    end

    
    private
    
=begin rdoc
Slot called whenever a new document is created

It adds the document to the part manager and makes several signal-slot connections
@param [Document] doc the created document
@return [nil]
=end
    def document_created doc
      connect doc, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('document_modified_changed(bool)')
      connect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT(:document_url_changed)
      connect doc, SIGNAL(:completed), self, SLOT(:document_url_changed)
      update_switch_to_list
    end
    slots 'document_created(QObject*)'

    def slot_active_environment_changed(new, old)
      if old
        old.disconnect SIGNAL('active_editor_changed(QWidget*)'), self, SLOT('slot_active_editor_changed(QWidget*)')
      end
      @active_environment = new
      if new
        connect new, SIGNAL('active_editor_changed(QWidget*)'), self, SLOT('slot_active_editor_changed(QWidget*)')
        @workspace.main_widget = new.tab_widget
        change_state 'active_project_exists', !new.project.nil?
        select_active_project_entry
        change_title
      else Ruber[:world].active_environment = Ruber[:world].default_environment
      end
    end
    slots 'slot_active_environment_changed(QObject*, QObject*)'
    
=begin rdoc
Slot called whenever the active editor changes

It emits the {#current_document_changed} and {#active_editor_changed} signals
and updates the title and the statusbar
@param [EditorView,nil] the new active editor, or *nil* if there's no active
  editor
@return [nil]
=end
    def slot_active_editor_changed view
      status_bar.view = view
      emit current_document_changed view ?  view.document : nil
      emit active_editor_changed view
      change_title
      set_state 'current_document', !view.nil?
      nil
    end
    slots 'slot_active_editor_changed(QWidget*)'
    
    def slot_project_created prj
      @workspace.add_widget prj.environment.tab_widget
      update_active_project_menu
    end
    slots 'slot_project_created(QObject*)'
    
    def slot_project_closing prj
      @workspace.remove_widget prj.environment.tab_widget
      update_active_project_menu prj
    end
    slots 'slot_project_closing(QObject*)'
    

=begin rdoc
Changes the icon in the tab corresponding to a document so that it reflects its
current status

@param [Document] doc the document to update the icon for
@return [nil]
=end
#     def update_document_icon doc
#       views = doc.views
#       views.each do |v|
#         tab = @active_environment.tab v
#         next unless tab
#         tab_widget = @active_environment.tab_widget
#         if v.is_ancestor_of tab.focus_widget
#           idx = tab_widget.index_of tab
#           @tab_widget.set_tab_icon idx, doc.icon
#         end
#       end
#       nil
#     end
    
=begin rdoc
Opens a file in an editor, gives focus to it and adds it to the list of recent
files

If needed, a document is created for the file.

If the file can't be opened, nothing is done.

See {#editor_for!} for the values which can be included in _hints_
@param [String, KDE::Url] the absolute path of the file to open.
@param hints (see #editor_for!)
@return [EditorView,nil] the editor displaying the file or *nil* if the file
  couldn't be opened
=end
    def gui_open_file file, give_focus = true, hints = DEFAULT_HINTS
      editor = @active_environment.editor_for! file, hints
      return unless editor
      editor.set_focus if give_focus
      url = KDE::Url.new file
      action_collection.action('file_open_recent').add_url url, url.file_name
      action_collection.action('window-switch_to_recent_file').add_url url, url.file_name
      editor
    end

=begin rdoc
Changes the title

The title is created basing on the open project, the current document and its
modified status

@return [nil]
=end
    def change_title 
      title = ''
      prj = @active_environment.project
      if prj
        title << (prj.project_name ? prj.project_name :
                  File.basename(prj.project_file, '.ruprj'))
      end
      doc = active_document
      if doc and doc.path.empty? 
        title << ' - ' << doc.document_name
      elsif doc
        title << ' - ' << doc.path
      end
      title.sub!(/\A\s+-/, '')
      mod = doc.modified? rescue false
      set_caption title, mod
      nil
    end
    
=begin rdoc
Slot called whenever the modified status of a document changes
    
It updates the icon on the tab of the document's editor and (if the document is active)
the window title accordingly.

Nothing is done if the document isn't associated with a view
@return [nil]
@note this method uses @Qt::Object#sender@ to determine the document which emitted
  the signal, so it can only be called as a slot
=end
    def document_modified_changed mod
      doc = self.sender
      change_title
#       update_document_icon doc
      nil
    end
    
=begin rdoc
Slot called whenever the document url changes

It changes the title and icon of the tab and changes the title of the window is
the document is active.

Nothing is done if the document isn't associated with a view

@return [nil]
=end
    def document_url_changed
      doc = self.sender
#       return unless doc.has_view?
#       change_title
#       doc.views.each do |v|
#         v.parent.label = @view_manager.label_for_editor v
#         tab = @view_manager.tab v
#         if @view_manager.focus_editor? v, tab
#           idx = @tabs.index_of tab
#           @tabs.set_tab_text idx, doc.document_name
#         end
#       end
#       update_document_icon doc
      unless doc.path.empty?
        action_collection.action('file_open_recent').add_url KDE::Url.new(doc.path) 
      end
      nil
    end
    
=begin rdoc
Removes the gui action handlers for all the actions belonging to the given plugin
from the list of handlers

@param [Plugin] plug the plugin whose action handlers should be removed
@return [nil]
=end
    def remove_plugin_ui_actions plug
      @actions_state_handlers.delete_if do |state, hs|
        hs.delete_if{|h| h.plugin == plug}
        hs.empty?
      end
      nil
    end
   
=begin
Gives the UI states their initial values
@return [nil]
=end
    def setup_initial_states
      change_state 'active_project_exists', false
      change_state 'current_document', false
      nil
    end
    
=begin rdoc
Closes the views associated with the given project

If any of the views is the only one associated with its document, the document
itself will be closed. In this case, if the document is modified, the user has
the possiblity of choosing whether to save them, discard the changes or not to
close the documents. 
@param [Project] prj the project whose documents should be closed
@return [Boolean] *true* if the documents were closed and *false* if the user chose
  to abort
=end
#     def close_project_files prj
#       views_to_close = prj.extension(:environment).views
#       to_save = views_to_close.map do |v|
#         v.document.views(:all).count == 1 ? v.document : nil
#       end
#       return false unless save_documents to_save.compact
#       without_activating{views_to_close.each{|v| close_editor v, false}}
#     end

=begin rdoc
Creates a new view manager

A new tab widget for the view manager is created if none is given.

After creating the view manager, it makes all the necessary signal-slot connections
with it and with the associated tab widget, if a new one is created.
@param [KDE::TabWidget,nil] tabs the tab widget to use for the view manager. If
  *nil*, a new widget will be created
@return [ViewManager] the new view manager
=end
#     def create_view_manager tabs = nil
#       mw = self
#       tabs ||= KDE::TabWidget.new do 
#         self.document_mode = true
#         self.tabs_closable = Ruber[:config][:workspace, :close_buttons]
#         connect self, SIGNAL('tabCloseRequested(int)'), mw, SLOT('close_tab(int)')
#       end
#       manager = ViewManager.new tabs, self
#       connect manager, SIGNAL('active_editor_changed(QWidget*)'), self, SLOT('slot_active_editor_changed(QWidget*)')
#       manager
#     end

=begin rdoc
Activates a view manager

Activating a view manager means, besides other things, that its tab widget becomes
the main widget of the workspace (becoming visible if it was hidden) and that the
tab widget of the previously active view manager is hidden
@param [ViewManager] the view manager to activate
@return [ViewManager,nil] the previously active view manager, or *nil* if there
  wasn't a view manager active
=end
#     def switch_to_view_manager manager
#       old = @view_manager
#       if old
#         old.deactivate
#         old.tabs.hide
#       end
#       @view_manager = manager
#       @tabs = manager.tabs
#       @workspace.main_widget = @tabs
#       @tabs.show
#       @view_manager.activate
#       active_editor.set_focus if active_editor
#       old
#     end
    
  end
  
end
