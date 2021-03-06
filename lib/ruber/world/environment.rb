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

require 'ruber/world/hint_solver'
require 'ruber/world/document_list'

module Ruber
  
  module World
    
    class Environment < Qt::Object
      
     class ViewList
        
        attr_reader :by_activation, :by_document, :by_tab, :tabs
        
        def initialize
          @by_activation = []
          @by_tab = {}
          @by_document = {}
          @tabs = {}
        end
        
        def add_view view, tab
          @by_activation << view
          (@by_tab[tab] ||= []) << view
          (@by_document[view.document] ||= []) << view
          @tabs[view] = tab
        end
        
        def remove_view view
          tab = @tabs[view]
          @by_activation.delete view
          @by_tab[tab].delete view
          @by_tab.delete tab if @by_tab[tab].empty?
          @by_document[view.document].delete view
          @by_document.delete view.document if @by_document[view.document].empty?
          @tabs.delete view
        end
        
        def move_to_front view
          @by_activation.unshift @by_activation.delete(view)
          tab = @tabs[view]
          @by_tab[tab].unshift @by_tab[tab].delete(view)
          doc = view.document
          @by_document[doc].unshift @by_document[doc].delete(view)
        end
        
      end
      
      include Activable
      
      include Extension
      
=begin rdoc
The default hints used by methods like {#editor_for} and {#editor_for!}
=end
    DEFAULT_HINTS = {
      :exisiting => :always, 
      :strategy => [:current, :current_tab, :first],
      :new => :new_tab,
      :split => :horizontal,
      :show => true,
      :create_if_needed => true
    }.freeze
    
    signals 'active_editor_changed(QWidget*)'
    
    signals :deactivated
    
    signals :activated
    
    signals 'closing(QObject*)'
      
=begin rdoc
@return [Project,nil] the project associated with the environment or *nil* if the
  environment is not associated with a project
=end
      attr_reader :project
      
=begin rdoc
@return [KDE::TabWidget] the tab widget containing the views contained in the
  environment
=end
      attr_reader :tab_widget
      
=begin rdoc
@return [EditorView,nil] the active editor or *nil* if no active editor exists
=end
      attr_reader :active_editor
      
      def initialize prj, parent = nil
        super parent
        @project = prj
        @tab_widget = KDE::TabWidget.new{self.document_mode = true}
        @tab_widget.tabs_closable = true if Ruber[:config][:workspace, :close_buttons]
        connect @tab_widget, SIGNAL('currentChanged(int)'), self, SLOT('current_tab_changed(int)')
        connect @tab_widget, SIGNAL('tabCloseRequested(int)'), self, SLOT('close_tab(int)')
        @views = ViewList.new
        @hint_solver = HintSolver.new @tab_widget, nil, @views.by_activation
        @documents = MutableDocumentList.new
        @active_editor = nil
        @active = false
        @focus_on_editors = true
        unless prj
          @default_document = Ruber[:world].new_document
          @default_document.object_name = 'default_document'
          @default_document.connect(SIGNAL('closing(QObject*)')){@default_document = nil}
          editor_for! @default_document
        end
      end
      
      def editor_for! doc, hints = DEFAULT_HINTS
        doc = Ruber[:world].document doc unless doc.is_a? Document
        hints = DEFAULT_HINTS.merge hints
        editor = @hint_solver.find_editor doc, hints
        unless editor
          return nil unless hints[:create_if_needed]
          view_to_split = @hint_solver.place_editor hints
          editor = doc.create_view
          if view_to_split
            orientation = hints[:split] == :vertical ? Qt::Vertical : Qt::Horizontal
            view_to_split.parent.split view_to_split, editor, orientation
          else 
            new_pane = create_tab(editor)
            add_editor editor, new_pane
            @tab_widget.add_tab new_pane, doc.icon, doc.document_name
            connect @tab_widget, SIGNAL('mouseMiddleClick(QWidget*)'), self, SLOT('tab_middle_clicked(QWidget*)')
            new_pane.label = label_for_document doc
          end
        end
        editor
      end
      
      def documents
        DocumentList.new @documents
      end
      
      def tabs
        @tab_widget.to_a
      end
            
      def views doc = nil
        doc ? @views.by_document[doc].dup : @views.by_activation.dup
      end
      
      def tab arg
        if arg.is_a?(Pane)
          pane = arg
          while parent = pane.parent_pane
            pane = parent
          end
          @tab_widget.index_of(pane) > -1 ? pane : nil
        else @views.tabs[arg]
        end
      end
      
      def activate_editor view
        return view if @active_editor == view
        deactivate_editor @active_editor
        if view
          if active?
            Ruber[:main_window].gui_factory.add_client view.send(:internal)
            @active_editor = view
          end
          @views.move_to_front view
          view_tab = tab(view)
          idx = @tab_widget.index_of view_tab
          @tab_widget.set_tab_text idx, view.document.document_name
          @tab_widget.set_tab_icon idx, view.document.icon
          @tab_widget.current_index = idx
        end
        if active?
          emit active_editor_changed(view) 
          view.document.activate if view
        end
        view.set_focus if view and focus_on_editors?
        view
      end
      slots 'activate_editor(QWidget*)'
      
      def active_document
        @active_editor ? @active_editor.document : nil
      end
      
      def close_editor editor, ask = true
        doc = editor.document
        if doc.views.count > 1 then editor.close
        else doc.close ask
        end
      end
      
      def close mode = :save
        if @project then @project.close mode == :save
        else 
          docs_to_close = @views.by_document.to_a.select{|d, v| (d.views - v).empty?}
          docs_to_close.map!{|d| d[0]}
          if mode == :save
            return false unless Ruber[:main_window].save_documents docs_to_close
          end
          emit closing(self)
          self.active = false
          docs_to_close.each{|d| d.close false}
          @views.by_activation.dup.each{|v| v.close}
          delete_later
          true
        end
      end
      slots :close
      
      def display_document doc, hints = {}
        ed = editor_for! doc, hints
        activate_editor ed
        line = hints[:line]
        ed.go_to line, hints[:column] || 0 if hints[:line]
        ed
      end
      
      def close_editors editors, ask = true
        editors_by_doc = editors.group_by &:document
        docs = editors_by_doc.keys
        to_close = docs.select{|doc| (doc.views - editors_by_doc[doc]).empty?}
        if ask
          return unless Ruber[:main_window].save_documents to_close 
        end
        to_close.each do |doc| 
          doc.close false
          editors_by_doc.delete doc
        end
        editors_by_doc.each_value do |a|
          a.each &:close
        end
      end
      
      def replace_editor old, new
        if new.is_a? Document
          new = new.create_view
        elsif new.is_a? String or new.is_a? KDE::Url
          new = Ruber[:world].document(new).create_view
        end
        if old.document.views.count == 1
          return unless old.document.query_close
          close_doc = true
        end
        old.parent.replace_view old, new
        close_editor old, false
        new
      end
      
      def focus_on_editors?
        @views.tabs.empty? || @focus_on_editors
      end
      
      def query_close
        if Ruber[:app].status != :asking_to_quit
          docs = @views.by_document.select{|d, v| (d.views - v).empty?}
          Ruber[:main_window].save_documents docs.map{|a| a[0]}
        else true
        end
      end
      
      def remove_from_project
        raise "environment not associated with a project" unless @project
        emit closing(self)
        self.active = false
        docs_to_close = @views.by_document.select{|d, v| (d.views - v).empty?}
        docs_to_close.each{|d| d[0].close false}
        @views.dup.by_activation.each{|v| v.close}
      end
      
      private
      
      def maybe_close_default_document doc
        return unless @default_document
        return if @default_document == doc
        return unless @default_document.pristine?
        return if @default_document.views.count != 1
        @default_document.close
      end
      
      def add_editor editor, pane
        maybe_close_default_document editor.document
        @views.add_view editor, pane
        doc = editor.document
        editor.parent.label = label_for_document doc
        unless @documents.include? doc
          @documents.add doc
          connect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT('document_url_changed(QObject*)')
        end
        connect editor, SIGNAL('focus_in(QWidget*)'), self, SLOT('editor_got_focus(QWidget*)')
        connect doc, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('document_modified_status_changed(bool, QObject*)')
        connect editor, SIGNAL('focus_out(QWidget*)'), self, SLOT('editor_lost_focus(QWidget*)')
        update_pane pane
      end
      
      def remove_editor pane, editor
        editor_tab = @views.tabs[editor]
        if @active_editor == editor
          to_activate = @views.by_tab[editor_tab][1]
          activate_editor to_activate
          deactivate_editor editor
        end
        disconnect editor, SIGNAL('focus_in(QWidget*)'), self, SLOT('editor_got_focus(QWidget*)')
        disconnect editor, SIGNAL('focus_out(QWidget*)'), self, SLOT('editor_lost_focus(QWidget*)')
        @views.remove_view editor
        unless @views.by_tab[editor_tab]
          @tab_widget.remove_tab @tab_widget.index_of(editor_tab) 
        end
        doc = editor.document
        unless @views.by_document[doc]
          @documents.remove doc 
          disconnect doc, SIGNAL('document_url_changed(QObject*)'), self, SLOT('document_url_changed(QObject*)')
          disconnect doc, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('document_modified_status_changed(bool, QObject*)')
        end
      end
      slots 'remove_editor(QWidget*, QWidget*)'
      
      def close_tab idx
        views = @tab_widget.widget(idx).views
        close_editors views
      end
      slots 'close_tab(int)'
      
      def editor_got_focus editor
        @focus_on_editors = true
        activate_editor editor
      end
      slots 'editor_got_focus(QWidget*)'
      
      def editor_lost_focus editor
        #When an editor is closed, the editor's parent pane is made parentless before the removing_editor
        #signal is emitted by the pane, which means the editor is hidden (and thus
        #looses focus) before it is actually closed. We don't want @focus_on_editors
        #to be changed in that case (otherwise closing an editor which had focus
        #would cause focus not to be given to the next active editor). The only
        #check I can think of is whether the editor's parent pane has a parent
        #or not
        if editor.is_active_window and editor.parent.parent
          @focus_on_editors = false 
        end
      end
      slots 'editor_lost_focus(QWidget*)'
      
      def do_deactivation
        #hiding the tab widget would make the editors all loose focus, but we
        #want that setting to be kept until the environment becomes active again,
        #so we store the original value in a temp variable and restore it afterwards
        old_focus_on_editors = @focus_on_editors
#         @tab_widget.hide
        deactivate_editor @active_editor
        @focus_on_editors = old_focus_on_editors
        super
      end
      
      def do_activation
        #showing the tab widget may make some editors all receive focus, but we
        #want that setting to be kept until the environment becomes active again,
        #so we store the original value in a temp variable and restore it afterwards
#         old_focus_on_editors = @focus_on_editors
#         @tab_widget.show
#         @focus_on_editors = old_focus_on_editors
        activate_editor @views.by_activation[0]
        super
      end
      
      
      def deactivate_editor view
        if view and @active_editor == view
          view.document.deactivate
          Ruber[:main_window].gui_factory.remove_client view.send(:internal)
          @active_editor = nil
        end
      end
      
      def label_for_document doc
        url = doc.url
        label = if url.local_file? then doc.path
        elsif url.valid? then url.pretty_url
        else doc.document_name
        end
        label << ' [modified]' if doc.modified?
        label
      end
      
      def create_tab view
        pane = Pane.new view
        pane.label = label_for_document view.document
        connect pane, SIGNAL('removing_view(QWidget*, QWidget*)'), self, SLOT('remove_editor(QWidget*, QWidget*)')
        connect pane, SIGNAL('pane_split(QWidget*, QWidget*, QWidget*)'), self, SLOT('pane_split(QWidget*, QWidget*, QWidget*)')
        connect pane, SIGNAL('view_replaced(QWidget*, QWidget*, QWidget*)'), self, SLOT('view_replaced(QWidget*, QWidget*, QWidget*)')
        pane
      end
      
      def pane_split pane, old, new
        add_editor new, tab(pane)
      end
      slots 'pane_split(QWidget*, QWidget*, QWidget*)'
      
      def view_replaced pane, old, new
        toplevel_pane = tab(pane)
        add_editor new, toplevel_pane
        remove_editor toplevel_pane, old
        update_pane toplevel_pane
      end
      slots 'view_replaced(QWidget*, QWidget*, QWidget*)'
      
      def update_pane pane
        docs = @views.by_tab[pane].map(&:document).uniq
        tool_tip = docs.map(&:document_name).join "\n"
        @tab_widget.set_tab_tool_tip @tab_widget.index_of(pane), tool_tip
      end
      slots 'update_pane(QWidget*)'
      
      def current_tab_changed idx
        current_tab = @tab_widget.widget idx
        view = idx >= 0 ? @views.by_tab[current_tab][0] : nil
        activate_editor view
        view
      end
      slots 'current_tab_changed(int)'
      
      def remove_tab pane
        @tab_widget.remove_tab @tab_widget.index_of(pane)
      end
      slots 'remove_tab(QWidget*)'
      
      def document_url_changed doc
        @tab_widget.each{|t| update_pane t}
        label = label_for_document doc
        @views.by_document[doc].each{|v| v.parent.label = label}
        @tab_widget.each_with_index do |w, i|
          if @views.by_tab[w][0].document == doc 
            @tab_widget.set_tab_text i, doc.document_name 
            @tab_widget.set_tab_icon i, doc.icon
          end
        end
      end
      slots 'document_url_changed(QObject*)'

      def document_modified_status_changed mod, doc
        label = label_for_document doc
        @views.by_document[doc].each{|v| v.parent.label = label}
        @tab_widget.each_with_index do |w, i|
          if @views.by_tab[w][0].document == doc 
            @tab_widget.set_tab_icon i, doc.icon
          end
        end
      end
      slots 'document_modified_status_changed(bool, QObject*)'
      
      def tab_middle_clicked w
        idx = @tab_widget.index_of w
        close_tab idx if idx >= 0 and Ruber[:config][:workspace, :middle_button_close]
      end
      slots 'tab_middle_clicked(QWidget*)'
      
    end
    
  end
  
end