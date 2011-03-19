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
      
      include Activable
      
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
        if prj
          @project = prj
          @project.parent = self 
          connect @project, SIGNAL('closing(QObject*)'), self, SLOT(:close)
        end
        @tab_widget = KDE::TabWidget.new
        @views_by_activation = []
        @hint_solver = HintSolver.new @tab_widget, nil, @views_by_activation
        @documents = MutableDocumentList.new
        @active_editor = nil
        @active = false
      end
      
      def editor_for! doc, hints = DEFAULT_HINTS
        doc = Ruber[:world].document doc unless doc.is_a? Document
        hints = DEFAULT_HINTS.merge hints
        editor = @hint_solver.find_editor doc, hints
        unless editor
          return nil unless hints[:create_if_needed]
          editor = create_editor doc
          if hints[:show]
            view_to_split = @hint_solver.place_editor hints
            if view_to_split
              orientation = hints[:split] == :vertical ? Qt::Vertical : Qt::Horizontal
              view_to_split.parent.split view_to_split, editor, orientation
            else 
              new_pane = create_tab(editor)
              @tab_widget.add_tab new_pane, doc.icon, doc.document_name
              new_pane.label = label_for_document doc
              pane_changed new_pane
            end
            @views_by_activation << editor
          end
        end
        editor
      end
      
      def documents
        DocumentList.new @documents
      end
            
      def views doc = nil
        doc ? @views_by_activation.select{|v| v.document == doc} : @views_by_activation
      end
      
      def tab arg
        pane = arg.is_a?(Pane) ? arg : arg.parent
        return unless pane
        while parent = pane.parent_pane
          pane = parent
        end
        @tab_widget.index_of(pane) > -1 ? pane : nil
      end
      
      def activate_editor view
        raise "Not the active environment" if view and !active?
        return view if @active_editor == view
        deactivate_editor @active_editor
        if view
          Ruber[:main_window].gui_factory.add_client view.send(:internal)
          @active_editor = view
          @views_by_activation.unshift @views_by_activation.delete view
          idx = @tab_widget.index_of tab(view)
          @tab_widget.set_tab_text idx, label_for_document(view.document)
          @tab_widget.set_tab_icon idx, view.document.icon
          @tab_widget.current_index = idx
        end
        emit active_editor_changed(view)
        view.document.activate if view
        view
      end
      
      def close_editor editor, ask = true
        doc = editor.document
        if doc.views.count > 1 then editor.close
        else doc.close ask
        end
      end
      
      def close
        emit closing(self)
        deactivate
        views = @views_by_activation.group_by{|v| v.document}
        to_save = @documents.select do |doc|
          doc.views.all?{|v| views[doc].include? v}
        end
        saving_done = Ruber[:main_window].save_documents to_save
        to_save.each do |doc|
          if saving_done || !doc.modified?
            views.delete doc
            doc.close false
          end
        end
        views.each_value do |a|
          a.each{|v| v.close}
        end
        saving_done
      end
      slots :close
      
      private
      
      def do_deactivation
        @tab_widget.hide
        deactivate_editor @active_editor
        super
      end
      
      def do_activation
        @tab_widget.show
        activate_editor @views_by_activation[0]
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
        if url.local_file? then doc.path
        elsif url.valid? then url.pretty_url
        else doc.document_name
        end
      end
      
      def create_tab view
        pane = Pane.new view
        connect pane, SIGNAL('removing_view(QWidget*, QWidget*)'), self, SLOT('pane_changed(QWidget*)')
        connect pane, SIGNAL('pane_split(QWidget*, QWidget*, QWidget*)'), self, SLOT('pane_changed(QWidget*)')
        connect pane, SIGNAL('view_replaced(QWidget*, QWidget*)'), self, SLOT('pane_changed(QWidget*)')
        pane
      end
      
      def create_editor doc
        editor = doc.create_view
        connect editor, SIGNAL('closing(QWidget*)'), self, SLOT('editor_closing(QWidget*)')
        editor
      end
      
      def pane_changed pane
        toplevel_pane = tab pane
        return unless toplevel_pane
        pane_docs = []
        toplevel_pane.each_view do |v| 
          @documents.add v.document
          pane_docs << v.document
        end
        @documents.uniq!
        pane_docs.uniq!
        tool_tip = pane_docs.map(&:document_name).join "\n"
        @tab_widget.set_tab_tool_tip @tab_widget.index_of(toplevel_pane), tool_tip
      end
      slots 'pane_changed(QWidget*)'
      
      def editor_closing view
        deactivate_editor view
      end
      slots 'editor_closing(QWidget*)'
      
    end
    
  end
  
end