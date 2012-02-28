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

require 'shellwords'
require 'facets/enumerable/mash'

require 'ruber/filtered_output_widget'

require_relative 'ui/config_widget'
require_relative 'ui/add_quick_task_widget'
require_relative 'ui/choose_task_widget'
require_relative 'ui/project_widget'

class RakeQuickTasksView < Qt::TreeView
  signals :tasks_changed
end

module Ruber
  
  module Rake
    
=begin rdoc
Where the user can choose the rake task to execute
=end
    class ChooseTaskDlg < KDE::Dialog
    
=begin rdoc
@param [Qt::Widget, nil] parent the dialog's parent widget
@param [Ruber::AbstractProject] prj as in {Rake::Plugin#choose_task_for}
=end
      def initialize prj, parent = Ruber[:main_window]
        super parent
        @ui = Ui::ChooseTaskWidget.new
        @ui.setupUi main_widget
        @project = prj
        @ui.tasks.model = Qt::SortFilterProxyModel.new @ui.tasks
        @tasks_model = Qt::StandardItemModel.new self
        @ui.tasks.model.source_model = @tasks_model
        @tasks_model.horizontal_header_labels = %w[Task Description]
        fill_tasks_widget
        enable_button_ok false  
        @ui.tasks.selection_model.connect(SIGNAL('selectionChanged(QItemSelection, QItemSelection)')) do
          enable_button_ok @ui.tasks.selection_model.has_selection
        end
        connect @ui.refresh_tasks, SIGNAL(:clicked), self, SLOT(:update_tasks)
        @ui.search_line.proxy = @ui.tasks.model
        @ui.tasks.set_focus
      end
      
=begin rdoc
The selected task

@return [String,nil] the selected task or *nil* if no task has been selected
=end
      def task
        sel = @ui.tasks.selection_model.selected_rows[0]
        sel ? sel.data.to_string : nil
      end
      
      private
      
=begin rdoc
Inserts the tasks for the object passed to the constructor in the task widget.

@Note:@ this method uses the {Rake::ProjectExtension#update_tasks} method,
so it can take some seconds to complete.
@return [nil]
=end
      def fill_tasks_widget
        tasks = @project[:rake, :tasks]
        items = tasks.sort.map{|task, data| [Qt::StandardItem.new(task), Qt::StandardItem.new(data[0])]}
        @tasks_model.remove_rows 0, @ui.tasks.model.row_count
        items.each{|i| @tasks_model.append_row i}
        @ui.tasks.resize_column_to_contents 0
        @ui.tasks.enabled = true
        nil
      end
      slots :fill_tasks_widget
      
=begin rdoc
Updates the list of tasks

@return [nil]
=end
      def update_tasks
        Ruber::Application.with_override_cursor do
          @project.extension(:rake).update_tasks
          fill_tasks_widget
        end
      end
      slots :update_tasks
      
    end
    
=begin rdoc
Delegate which allows to edit the entries using a @KDE::KeySequenceWidget@
=end
    class ShortcutDelegate < Qt::StyledItemDelegate
      
=begin rdoc
@param [Integer] col the column number
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize col, parent = nil
        super parent
        @column = col
      end
      
=begin rdoc
Override of @Qt::StyledItemDelegate#createEditor@ which returns a
@KDE::KeySequenceWidget@.

@param [Qt::Object] parent the parent object
@param [Qt::StyleOptionViewItem] opt controls how the editor appears
@param [Qt::ModelIndex] idx the index the editor is for
@return [Qt::Widget] the editor widget
=end
      def createEditor parent, opt, idx
        if idx.column != @column then super
        else
          w = KDE::KeySequenceWidget.new parent
          connect w, SIGNAL('stealShortcut(QKeySequence, KAction*)'), w, SLOT(:applyStealShortcut)
          collections = Ruber[:main_window].factory.clients.map{|cl| cl.action_collection}
          w.check_action_collections = collections
          w
        end
      end
      
=begin rdoc
Override of @Qt::StyledItemDelegate#setEditorData@ which fills the editor
with the content of the model.

@param [Qt::Widget] w the editor widget
@param [Qt::ModelIndex] idx the index the editor is for
@return [nil]
=end
      def setEditorData w, idx
        if idx.column != @column then super
        else w.key_sequence = Qt::KeySequence.new(idx.data.to_string)
        end
        nil
      end

=begin rdoc
Override of @Qt::StyledItemDelegate#setModelData@ which inserts the contents
of the shortcut widget in the model.

@param [Qt::Widget] w the editor widget
@param [Qt::AbstractItemModel] the model the index refers to
@param [Qt::ModelIndex] the index to modify
@return [nil]
=end
      def setModelData w, model, idx
        if idx.column != @column then super
        else model.set_data idx, Qt::Variant.new(w.key_sequence.to_string), Qt::DisplayRole
        end
        nil
      end
      
=begin rdoc
Override of @Qt::StyledItemDelegate#updateEditorGeometry@

@param [Qt::Widget] w the editor widget
@param [Qt::StyleOptionViewItem] opt the option to use when changing the editor
geometry
@param [Qt::ModelIndex] the index associated with the editor
@return [nil]
=end
      def updateEditorGeometry w, opt, idx
        if idx.column != @column then super
        else
          tl = opt.rect.top_left
          size = w.rect.size
          size.width += 50
          w.geometry = Qt::Rect.new tl, size
        end
        nil
      end
      
    end

=begin rdoc
The configuration widget for the plugin
=end
    class ConfigWidget < Qt::Widget
      
=begin rdoc
Dialog used by the configuration widget to have the user choose a quick task,
that is associate a shortcut with a name (which is supposed to correspond to
a task in the rakefile)
=end
      class AddQuickActionDlg < KDE::Dialog
        
=begin rdoc
@param [Qt::Widget,nil] the parent widget
=end
        def initialize parent = Ruber[:main_window]
          super
          @ui = Ui::AddQuickTaskWidget.new
          @ui.setupUi main_widget
          collections = Ruber[:main_window].factory.clients.map{|cl| cl.action_collection}
          @ui.shortcut.check_action_collections = collections
          connect @ui.shortcut, SIGNAL('stealShortcut(QKeySequence, KAction*)'), @ui.shortcut, SLOT(:applyStealShortcut)
          enable_button_ok false
          @ui.task.set_focus
          connect @ui.task, SIGNAL('textChanged(QString)'), self, SLOT(:change_ok_state)
          connect @ui.shortcut, SIGNAL('keySequenceChanged(QKeySequence)'), self, SLOT(:change_ok_state)
        end
        
=begin rdoc
The name chosen by the user
@return [String] the name chosen by the user
=end
        def task
          @ui.task.text
        end
        
=begin rdoc
The shortcut chosen by the user
@return [String] the shortcut chosen by the user
=end
        def shortcut
          @ui.shortcut.key_sequence.to_string
        end
        
        private
        
=begin rdoc
Enables or disables the Ok button depending on whether both the task name and
the corresponding shortcut have been chosen
@return [nil]
=end
        def change_ok_state
          enable_button_ok !(@ui.task.text.empty? || @ui.shortcut.key_sequence.empty?)
          nil
        end
        slots :change_ok_state
        
      end
            
      slots :add_task, :remove_current_task, :change_buttons_state
      
=begin rdoc
@param [Qt::Widget,nil] parent the widget's parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::RakeConfigWidget.new
        @ui.setupUi self
        m = Qt::StandardItemModel.new self
        v = @ui._rake__quick_tasks
        @ui._rake__quick_tasks.model = m
        
        connect m, SIGNAL('itemChanged(QStandardItem*)'), v, SIGNAL(:tasks_changed)
        connect m, SIGNAL('rowsInserted(QModelIndex, int, int)'), v, SIGNAL(:tasks_changed)
        connect m, SIGNAL('rowsRemoved(QModelIndex, int, int)'), v, SIGNAL(:tasks_changed)
        
        @ui._rake__quick_tasks.model.horizontal_header_labels = %w[Tasks Shortcuts]
        delegate = ShortcutDelegate.new 1, @ui._rake__quick_tasks
        @ui._rake__quick_tasks.item_delegate = delegate
        connect @ui.add_task, SIGNAL(:clicked), self, SLOT(:add_task)
        connect @ui.remove_task, SIGNAL(:clicked), self, SLOT(:remove_current_task)
        @ui._rake__quick_tasks.selection_model.connect SIGNAL('selectionChanged(QItemSelection, QItemSelection)') do 
          @ui.remove_task.enabled = @ui._rake__quick_tasks.selection_model.has_selection
        end
      end
      
=begin rdoc
Fills the "Quick tasks" widget
@param [Hash] tasks the tasks to insert in the widget. The keys are the task names,
while the values are strings representing the shortcuts to associate to each task
@return [nil]
=end
      def read_quick_tasks tasks
        m = @ui._rake__quick_tasks.model
        tasks.each_pair do |k, v|
          m.append_row [Qt::StandardItem.new(k), Qt::StandardItem.new(v)]
        end
        if m.row_count > 0
          @ui._rake__quick_tasks.selection_model.select m.index(0,0), Qt::ItemSelectionModel::ClearAndSelect|Qt::ItemSelectionModel::Rows|Qt::ItemSelectionModel::Current
        end
        nil
      end
      
=begin rdoc
Gathers data from the "Quick tasks" widget
@return [Hash] a hash having the task names as keys and strings representing the
associated shortcuts as values
=end
      def store_quick_tasks
        m = @ui._rake__quick_tasks.model
        res = {}
        m.each_row do |task, short|
          res[task.text] = short.text
        end
        res
      end
      
      private
      
=begin rdoc
Displays a dialog where the user can create a quick task by associating a (task)
name with a shortcut.
      
If the user presses the Ok button in the dialog, the new task is added to the task
widget. If he presses the Cancel button, nothing is done.
@return [nil]
=end
      def add_task
        dlg = AddQuickActionDlg.new
        return if dlg.exec == Qt::Dialog::Rejected
        row = [Qt::StandardItem.new(dlg.task), Qt::StandardItem.new(dlg.shortcut)]
        @ui._rake__quick_tasks.model.append_row(row)
        @ui._rake__quick_tasks.selection_model.select row[0].index, Qt::ItemSelectionModel::ClearAndSelect|Qt::ItemSelectionModel::Rows|Qt::ItemSelectionModel::Current
        nil
      end
      
=begin rdoc
Removes the currently selected entry from the "Quick tasks" widget

*Note:* this method assumes an item is selected.
@return [nil]
=end
      def remove_current_task
        #We don't check wheter there's a selected item because the Remove task
        #button is disabled if no entry is selected
        row = @ui._rake__quick_tasks.selection_model.selected_rows[0].row
        @ui._rake__quick_tasks.model.remove_row row
        nil
      end
      
    end

=begin rdoc
Project configuration widget
=end
    class ProjectWidget < ProjectConfigWidget
      
      slots :refresh_tasks, :add_task, :remove_task

=begin rdoc
@param [Ruber::AbstractProject] prj the project the widget refers to
=end
      def initialize prj
        super
        @ui = Ui::RakeProjectWidget.new
        @ui.setupUi self
        @ui.tasks.model = Qt::StandardItemModel.new @ui.tasks
        @ui.tasks.item_delegate = ShortcutDelegate.new 1, @ui.refresh_tasks
        view = @ui.tasks
        view.header.resize_mode = Qt::HeaderView::ResizeToContents
        def view.mouseDoubleClickEvent e
          idx = index_at e.pos
          if idx.valid? then super
          else
            it = Qt::StandardItem.new
            model.append_row 3.times.map{Qt::StandardItem.new ''}
            edit it.index
          end
        end
        connect @ui.refresh_tasks, SIGNAL(:clicked), self, SLOT(:refresh_tasks)
        connect @ui.add_task, SIGNAL(:clicked), self, SLOT(:add_task)
        connect @ui.remove_task, SIGNAL(:clicked), self, SLOT(:remove_task)
        view.selection_model.connect SIGNAL('selectionChanged(QItemSelection, QItemSelection)') do
          @ui.remove_task.enabled = !view.selection_model.selected_indexes.empty?
        end
        fill_tasks_widget @project[:rake, :tasks]
      end
      
=begin rdoc
Fills the Tasks widget according to the rake/tasks and rake/quick_tasks project 
options
@return [nil]
=end
      def read_settings
        fill_tasks_widget @project[:rake, :tasks]
        nil
      end

=begin rdoc
Sets the rake/tasks and rake/quick_task project options according to the contents
of the Tasks widget
@return [nil]
=end
      def store_settings
        @project[:rake, :tasks] = tasks
        nil
      end

=begin rdoc
Clears the task widget
@return [ni;]
=end
      def read_default_settings
        mod = @ui.tasks.model
        mod.remove_rows 0, mod.row_count
        nil
      end
      
=begin rdoc
The list of tasks

@return [Hash] a hash containing the tasks. The keys are the names of the tasks,
while the values are arrays having as first argument the task descriptions and
as second argument a string corresponding to the shortcut chosen by the user,
or *nil* if no shortcut has been chosen.
=end
      def tasks
        res = {}
        @ui.tasks.model.each_row do |r|
          unless r[0].text.empty?
            new_task = [r[2].text]
            new_task << r[1].text unless r[1].text.empty?
            res[r[0].text] = new_task
          end
        end
        res
      end
      
=begin rdoc
Fills the Rake options widget
@param [<String>] value an array with the rake options
@return [<String>]
=end
      def options= value
        @ui._rake__options.text = value.join " "
      end
      
=begin rdoc
The options set in the Rake options widget
@return [<String>] an array containing the options chosen by the user, split and
quoted according to {Shellwords.split_with_quotes}
=end
      def options
        Shellwords.split_with_quotes @ui._rake__options.text
      end
      
=begin rdoc
Fills the Rake environment widget
@param [<String>] value an array containing the environment variables to set. Each
entry of the array should have the form @ENV_VAR=value@ (with quotes added as needed)
@return [<String>]
=end
      def environment= value
        @ui._rake__environment.text = value.join " "
      end
      
=begin rdoc
The environment variables set in the Environment variables widget
@return [<String>] the environment variables chosen by the user, split according
to {Shellwords.split_with_quotes}.
=end
      def environment
        Shellwords.split_with_quotes @ui._rake__environment.text
      end
      
=begin rdoc
Fills the rakefile widget
@param [String,nil] value the path to the rakefile to use or *nil* to let rake
decide
@return [String]
=end
      def rakefile= value
        @ui._rake__rakefile.text = value || ''
      end
      
=begin rdoc
The rakefile chosen by the user
@return [String,nil] the path to the rakefile chosen by the user or *nil* to let
rake decide
=end
      def rakefile
        text = @ui._rake__rakefile.text
        text.empty? ? nil : text
      end
      
      private
      
=begin rdoc
Fills the task widget with an up to date list of tasks, according to the current
content of the various widgets
      
Shortcut assigned to tasks which still exist after the update are kept.

This also enables the Tasks widget and hides the outdated tasks warning.

If the tasks couldn't be retrieved because of a rake error, a message box is shown
and nothing is done
@return [nil]
=end
      def refresh_tasks
        new_tasks = begin find_updated_tasks
        rescue Rake::Error => e
          Ruber[:rake].display_task_retrival_error_dialog ex
        end
        new_tasks.each_pair{|k, v| new_tasks[k] = [v]}
        old_tasks = tasks
        old_tasks.each_pair do |t, data|
          if data[1]
            new = new_tasks[t]
            new << data[1] if new
          end
        end
        fill_tasks_widget new_tasks
        nil
      end
      
=begin rdoc
Fills the task widget
@param [Hash] tasks a hash with the information about the tasks to display. The
keys of the hash are the task names, while the values are arrays of size 1 or 2.
The first element of the array is a string representing the task description,
while the second, if it exists, is a string representing the shortcut associated
with the task
*Note:* the previous contents of the widget will be removed
@return [nil]
=end
      def fill_tasks_widget tasks
        mod = @ui.tasks.model
        mod.clear
        tasks = tasks.sort
        @ui.tasks.model.horizontal_header_labels = %w[Task Shortcut Description]
        tasks.each do |n, i|
          name = Qt::StandardItem.new n
          desc = Qt::StandardItem.new i[0]
          key = Qt::StandardItem.new(i[1] || '')
          mod.append_row [name, key, desc]
        end
        nil
      end

=begin rdoc
Uses the values in the Rake, Rake program, Rake options and environment variables
widgets to retrieve an up-to-date list of tasks

@raise {Plugin::RakeError} if rake fails
@return [Hash] a hash with the information about the tasks to display. The
keys of the hash are the task names, while the values are arrays of size 1 or 2.
The first element of the array is a string representing the task description,
while the second, if it exists, is a string representing the shortcut associated
with the task
=end
      def find_updated_tasks
        rake = @ui._rake__rake.text
        rakefile = @ui._rake__rakefile.text
        rakefile = nil if rakefile.empty?
        rake_options = Shellwords.split_with_quotes @ui._rake__options.text
        rake_options << '-T'
        env = Shellwords.split_with_quotes(@ui._rake__environment.text).select{|s| s.include? '='}
        dir = @project.project_directory
        if rakefile
          rel_dir = File.dirname(rakefile)
          dir = File.join dir, rel_dir unless rel_dir == '.'
        end
        ruby, *ruby_opts = Ruber[:rake].ruby_command_for @project, dir
        Ruber[:app].with_override_cursor do
          begin
            Ruber[:rake].tasks ruby, dir, :env => env, :ruby_options => ruby_opts,
              :rake_options => rake_options, :rakefile => rakefile, :rake => rake,
              :timeout => @ui._rake__timeout.value
          rescue Error => ex
            display_task_retrival_error_dialog ex
            return
          end
        end
      end
      
=begin rdoc
Displays a dialog where the user can add a new task and adds it to the task widget
@return [nil]
=end
      def add_task
        name = Qt::InputDialog.get_text self, 'Add task', 'Task name'
        return if name.nil? or name.empty?
        row = [name, '', ''].map{|i| Qt::StandardItem.new i}
        @ui.tasks.model.append_row row
        nil
      end
      
=begin rdoc
Removes the currently selected task from the task widget

*Note:* this method assumes a task is selected
@return [nil]
=end
      def remove_task
        #We don't check whether a task is selected or not as the button should
        #be disabled otherwise
        idx = @ui.tasks.selection_model.selected_indexes.first
        @ui.tasks.model.remove_row idx.row
        nil
      end
      
    end
    
  end
  
end