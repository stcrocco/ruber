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

require 'ruber/filtered_output_widget'

module Ruber
  
=begin rdoc
Plugin providing a tool widget which displays the files in the project directory

The tool widget consists of a tree view displaying the contents of the project directory,
which is automatically updated whenever the current project changes. The view
provides a menu which allows the user to choose whether to show only the files
belonging to the project or all files in the directory.

The view is updated whenever the contents of the project directory change or whenever
the @general/project_files@ project option changes.

Although it uses a {FilteredOutputWidget} for view, it doesn't provide a way to
filter files basing on filenames and the standard menu entries {FilteredOutputWidget}
usually have.
=end
  module ProjectBrowser
    
=begin rdoc
The tool widget displaying the project directory
=end
    class ToolWidget < FilteredOutputWidget
      
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
          @ignore = false
          self.dynamic_sort_filter = true
        end
        
=begin rdoc
Disables filtering
@return [nil]
=end
        def ignore_filter
          @ignore = true
          nil
        end
        
=begin rdoc
Tells whether to to accept all items or exclude files not belonging to the project.

If this changes from *true* to *false* or vice-versa, the filter is invalidated
@param [Boolean] val whether or not to accept all files
@return [Boolean] _val_
=end
        def ignore_filter= val
          old = @ignore
          @ignore = val.to_bool
          invalidate if old != @ignore
          nil
        end
        
=begin rdoc
Whether files not belonging to the project are being kept or filtered out
@return [Boolean] *true* if all files are being kept and *false* if files not belonging
  to the project are being filtered out
=end
        def filter_ignored?
          @ignore
        end
        
=begin rdoc
Needed to satisfy {FilteredOutputWidget::FilterModel} API

If does nothing
@return [nil]
=end
        def filter_reg_exp= val
        end

=begin rdoc
Needed to satisfy {FilteredOutputWidget::FilterModel} API

If does nothing
@return [nil]
=end
        def exclude
        end

=begin rdoc
Needed to satisfy {FilteredOutputWidget::FilterModel} API

If does nothing
@return [nil]
=end
        def exclude= val
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
          return true if @project.nil? or @ignore
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
Override of @KDE::DirSortFilterProxyModel#filterAcceptsRow@ which works as the
parent method but is public
@return [nil]
=end
        def invalidate_filter
          super
        end
        
      end
      
=begin rdoc
Creates a new instance

The view of the new instance displays the contents of the directory of the current
project, if any
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super parent, :view => :tree, :model => KDE::DirModel.new, :use_default_font => true,
            :filter => FilterModel.new
        action_list.clear
        actions.clear
        action = KDE::ToggleAction.new KDE.i18n('&Show only project files'), self
        action.object_name = 'only_project_files'
        actions['only_project_files'] = action
        action.connect(SIGNAL('toggled(bool)')){|val| filter_model.ignore_filter = !val}
        action_list << 'only_project_files'
        connect Ruber[:world], SIGNAL('active_project_changed(QObject*)'), self, SLOT('current_project_changed(QObject*)')
        action.checked = true
        model.dir_lister.open_url KDE::Url.new('/')
        view.edit_triggers = Qt::AbstractItemView::NoEditTriggers
        1.upto(model.column_count-1){|i| view.hide_column i}
        view.header_hidden = true
        @project = nil
        current_project_changed Ruber[:world].active_project
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
          model.dir_lister.open_url KDE::Url.new(prj.project_directory)
          view.enabled = true
        else view.enabled = false
        end
        filter_model.project = prj
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
        filter.invalidate_filter if group == 'general' and name == 'project_files'
        nil
      end
      slots 'project_option_changed(QString, QString)'
      
      def find_filename_in_index idx
        unless idx.column == KDE::DirModel::Name
          idx = filter.index(KDE::DirModel::Name, idx.row, idx.parent)
        end
        item = @model.item_for_index idx
        return if item.dir?
        [item.local_path, 0]
      end
      
    end
    
  end
  
end