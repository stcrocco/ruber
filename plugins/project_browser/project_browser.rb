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
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             
=end

module Ruber
  
=begin rdoc
Plugin providing a tool widget which displays the files in the project directory

The tool widget consists of a tree view displaying the contents of the project directory,
which is automatically updated whenever the current project changes. The view
provides a menu which allows the user to choose whether to show only the files
belonging to the project or all files in the directory.

The view is updated whenever the contents of the project directory change or whenever
the @general/project_files@ project option changes.
=end
  module ProjectBrowser
    
=begin rdoc
The tool widget displaying the project directory
=end
    class ToolWidget < Qt::Widget
      
=begin rdoc
Filter used by the tree view to hide non-project files. It also allow to turn off
filtering, which is used when the user choose to display all files.

@todo currently, directories containing only non-project files are still shown. This
is because of how the filtering is done: filtering the parent object is done before
filtering child objects, so there's no direct way to remove empty items. See whether
something can be done about it
=end
      class FilterModel < KDE::DirSortFilterProxyModel
        
=begin rdoc
@param [Qt::Object] parent the parent object
=end
        def initialize parent = nil
          super
          @project = nil
          @do_filtering = true
          self.dynamic_sort_filter = true
        end
        
=begin rdoc
Override of @KDE::DirSortFilterProxyModel#filterAcceptsRow@ which rejects all files
not belonging to the project, unless filtering has been turned off.

@param [Integer] row the number of the row to be filtered (in the source model)
@param [Qt::ModelIndex] parent the parent of the row to be filtered (in the source model)
@return [Boolean] always *true* if filtering has been turned off or no project has
been set, otherwise *true*
if row corresponds to a directory or to a file belonging to the project and *false*
otherwise
=end
        def filterAcceptsRow row, parent
          return true if @project.nil? or !@do_filtering
          it = source_model.item_for_index source_model.index(row,0,parent)
          return true if it.dir?
          @project.file_in_project? it.local_path
        end
        
=begin rdoc
Changes the project to use for filtering and invalidates the filter
@param [Ruber::Project,nil] prj the project to use for filtering (if *nil*, all
items will be accepted)
@return [nil]
=end
        def project= prj
          @project = prj
          invalidate_filter
        end
        
=begin rdoc
Tells whether to exclude files not belonging to the project or to accept all items
@param [Boolean] val whether or not to accept all files
@return [Boolean] _val_
=end
        def do_filtering= val
          @do_filtering = val
          invalidate_filter
        end
        
=begin rdoc
Override of @KDE::DirSortFilterProxyModel#filterAcceptsRow@ which works as the
parent method but is public
@return [nil]
=end
        def invalidate_filter
          super
        end
        
      end
      
=begin rdoc
The view used by the plugin

The only scope of this class is to provide the context menu
=end
      class View < Qt::TreeView
        
=begin rdoc
Signal emitted whenever the user toggles the "Show only project files" action
@param [Boolean] *true* if the user checked the action and *false* if he unchecked
it
=end
        signals 'only_project_files_triggered(bool)'
  
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
        def initialize parent = nil
          super
          @menu = Qt::Menu.new self
          @toggle_filter_action = KDE::ToggleAction.new 'Show only project files', @menu
          @toggle_filter_action.checked = true
          @menu.add_action @toggle_filter_action
          connect @toggle_filter_action, SIGNAL('toggled(bool)'), self, SIGNAL('only_project_files_triggered(bool)')
        end
        
=begin rdoc
Override of @Qt::AbstractScrollArea#contextMenuEvent@ which displays a menu containing
the action
@param [Qt::ContextMenuEvent] e the event object
=end
        def contextMenuEvent e
          @menu.popup e.global_pos
        end
        
      end

=begin rdoc
Creates a new instance

The view of the new instance displays the contents of the directory of the current
project, if any
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        connect Ruber[:world], SIGNAL('active_project_changed(QObject*)'), self, SLOT('current_project_changed(QObject*)')
        self.layout = Qt::VBoxLayout.new self
        @view = View.new self
        @model = KDE::DirModel.new @view
        @model.dir_lister.open_url KDE::Url.new('/')
        @filter = FilterModel.new @view
        @filter.source_model = @model
        @view.model = @filter
        @view.edit_triggers = Qt::AbstractItemView::NoEditTriggers
        1.upto(@model.column_count-1){|i| @view.hide_column i}
        @view.header_hidden = true
        layout.add_widget @view
        @project = nil
        current_project_changed Ruber[:world].active_project
        @view.connect(SIGNAL('only_project_files_triggered(bool)')){|val| @filter.do_filtering = val}
        connect @view, SIGNAL('activated(QModelIndex)'), self, SLOT('open_file_in_editor(QModelIndex)')
      end
      
      private
      
=begin rdoc
Slot called whenever the current project changes

This method updates the view so that it displays the contents of the project directory
(or disables the view if there's no open project) and sets up the needed connections
with the project

@param [Ruber::Project,nil] prj the current project
@return [nil]
=end
      def current_project_changed prj
        @project.disconnect SIGNAL('option_changed(QString,QString)'), self if @project
        if prj
          @project = prj
          connect @project, SIGNAL('option_changed(QString, QString)'), self, SLOT('project_option_changed(QString, QString)')
          @model.dir_lister.open_url KDE::Url.new(prj.project_directory)
          @view.enabled = true
        else @view.enabled = false
        end
        @filter.project = prj
        nil
      end
      slots 'current_project_changed(QObject*)'
      
=begin rdoc
Slot called whenever a setting of the current project changes

It is needed to re-applicate the filter after the @general/project_files@ project
setting has changed
@param [String] group the group the changed setting belongs to
@param [String] the name of the changed setting
@return [nil]
=end
      def project_option_changed group, name
        @filter.invalidate_filter if group == 'general' and name == 'project_files'
        nil
      end
      slots 'project_option_changed(QString, QString)'
      
=begin rdoc
Slot called whenever the user activates an item in the view

If the item corresponds to a file, it will be opened in an editor, otherwise nothing
will be done. The tool widget will be closed unless the Meta key is pressed
@param [Qt::ModelIndex] idx the activated index (referred to the filter model)
@return [nil]
=end
      def open_file_in_editor idx
        #Currently, only the name column is supported. However, in the future,
        #other columns can be supported
        unless idx.column == KDE::DirModel::Name
          idx = @filter.index(KDE::DirModel::Name, idx.row, idx.parent)
        end
        item = @model.item_for_index @filter.map_to_source(idx)
        return if item.dir?
        file = item.local_path
        modifiers = Ruber[:app].keyboard_modifiers
        Ruber[:main_window].display_document file
        Ruber[:main_window].hide_tool self if (Qt::MetaModifier & modifiers) == 0
        nil
      end
      slots 'open_file_in_editor(QModelIndex)'
      
    end
    
  end
  
end