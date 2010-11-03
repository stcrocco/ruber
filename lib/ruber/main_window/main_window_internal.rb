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
    
    private    
    
=begin rdoc
Checks whether an editor view for the given document exists and creates it if it
doesn't. In both cases, An editor view for the document is returned. _doc_ is the
Document for which the editor should be created.

<b>Note:</b> this also creates a new tab with the new view, if it needs to create
one
=end
    def create_editor_if_needed doc
      if doc.view then doc.view
      else
        view = doc.create_view
        @editors_mapper.set_mapping view, view
        connect view, SIGNAL(:closing), @editors_mapper, SLOT(:map)
        connect view.document, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('document_modified_changed(bool)')
        connect view.document, SIGNAL('modified_on_disk(QObject*, bool, KTextEditor::ModificationInterface::ModifiedOnDiskReason)'), self, SLOT('update_document_icon(QObject*)')
        connect view.document, SIGNAL('document_url_changed(QObject*)'), self, SLOT(:document_url_changed)
        @views.add_tab view, doc.icon, doc.document_name
        view
      end
    end

=begin rdoc
Changes the icon in the tab corresponding to the Document _doc_ so that it reflects
its current status
=end
    def update_document_icon doc
      ed = editor_for doc
      return unless ed
      idx = @views.index_of ed
      return unless idx
      @views.set_tab_icon idx, doc.icon
    end
    
=begin rdoc
Opens a file, creating a document and an editor for it, activates and gives focus
to the editor and adds the file to the list of recent files. _file_ is the absolute
path of the file to open
=end
    def gui_open_file file
      editor = editor_for! file
      return unless editor
      focus_on_editor editor
      url = KDE::Url.new file
      action_collection.action('file_open_recent').add_url url, url.file_name
    end

=begin rdoc
If _ed_ is the active editor, it deactivates it and removes it from the gui. If
_ed_ is not the active editor (or if it's *nil*), nothing is done.
    
<b>Note:</b> this doesn't change the status bar associated with the view.
=end
    def deactivate_editor ed
      return unless ed and ed == @active_editor
      @active_editor.document.deactivate
      gui_factory.remove_client ed.send( :internal)
    end
    
=begin rdoc
Remove the editor _ed_ from the tab widget, deactivating it before (if needed).
If automatical activation of editors is on, it also activates another editor,
if any
=end
    def remove_view ed
      status_bar.view = nil if ed == @active_editor
      deactivate_editor ed
      idx = @views.index_of ed
      @views.remove_tab idx
      #This assumes that only one editor can exist for each document
      ed.document.disconnect SIGNAL('modified_changed(bool, QObject*)'), self
      ed.document.disconnect SIGNAL('document_url_changed(QObject*)'), self
      if @views.current_widget and @auto_activate_editors
        activate_editor @views.current_widget
        @views.current_widget.set_focus
      end
    end
    
    protected
    
=begin rdoc
Override of <tt>KParts::MainWindow#queryClose</tt> which calls the <tt>query_close</tt>
method of the component manager. This means that the latter method will be called
everytime the application is closed.
=end
    def queryClose
      Ruber[:components].query_close
    end
    
=begin rdoc
Override of <tt>KParts::MainWindow#queryExit</tt> which calls the +shutdown+ method
of the component
=end
    def queryExit
      Ruber[:app].quit_ruber
      true
    end
    
=begin rdoc
Saves the properties for session management.
TODO: currently, session management doesn't work at all. So, either remove the
method or make it work
=end
    def saveProperties conf
      data = YAML.dump @session_data 
      conf.write_entry 'Ruber', data
    end

=begin rdoc
Reads the properties from the config object for session management
=end
    def readProperties conf
      @last_session_data = YAML.load conf.read_entry('Ruber', '{}')
    end
   
=begin rdoc
Creates a suitable title for the main window.
=end
    def make_title 
      title = ''
      prj = Ruber[:projects].current_project
      if prj
        title << (prj.project_name ? prj.project_name :
                  File.basename(prj.project_file, '.ruprj'))
      end
      if @active_editor and @active_editor.document.path.empty? 
        title << ' - ' << @active_editor.document.document_name
      elsif @active_editor
        title << ' - ' << @active_editor.document.path
      end
      title.sub!(/\A\s+-/, '')
      mod = current_document.modified? rescue false
      set_caption title, mod
    end
    
=begin rdoc
:call-seq: document_modified_changed(mod) [SLOT]

Slot called whenever the modified status of a document changes. It updates the
icon on the tab of the document's editor and the window title (if the document
was the active one) accordingly.
=end
    def document_modified_changed mod
      doc = self.sender
      make_title
#This assumes that only one editor exists for each document
      update_document_icon doc
    end
    
=begin rdoc
Slot called whenever the document url changes (usually because the document has
been saved). It changes the title and icon of the tab and changes the title of the
window is the document is active.
=end
    def document_url_changed
      doc = self.sender
      make_title
      idx = @views.index_of doc.view
      @views.set_tab_text idx, doc.document_name
      update_document_icon doc
      
      unless doc.path.empty?
        action_collection.action('file_open_recent').add_url KDE::Url.new(doc.path) 
      end
    end
    
=begin rdoc
Removes the action handlers for all the actions belonging to the plugin _plug_
from the list of handlers
=end
    def remove_plugin_ui_actions plug
      @actions_state_handlers.delete_if do |state, hs|
        hs.delete_if{|h| h.plugin == plug}
        hs.empty?
      end
    end
   
=begin
Sets the UI states defined by the main window to their initial values.
=end
    def setup_initial_states
      change_state 'active_project_exists', false
      change_state 'current_document', false
    end
    
    def close_project_files prj
      to_close = @views.select do |v|
        prj.project_files.file_in_project? v.document.path
      end
      save_documents to_close.map &:document
      to_close.each{|v| v.document.close}
    end
    
    
  end
  
end
