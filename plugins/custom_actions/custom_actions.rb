=begin
    Copyright (C) 2012 by Stefano Crocco   
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

require_relative 'ui/config_widget'

module Ruber

=begin rdoc
Plugin allowing the user to associate pieces of ruby code to actions which are
kept in a menu and can be assigned custom shortcuts.

Each action has a name and a piece of code associated with it, which can be
both configured in the settings dialog. Shortcuts for these action can be set
from the shortcuts dialog as for any other action.
=end
  module CustomActions
    
    class Plugin < GuiPlugin
      
=begin rdoc
@param [PluginSpecification] the plugin specification associated with the plugin
=end      
      def initialize psf
        super
        @mapper = Qt::SignalMapper.new self
        @mapper.connect(SIGNAL('mapped(int)')){|idx| execute_code idx}
        @actions = nil
        @codes = []
        # The GUI doesn't as yet exist when load_settings is frist called
        load_settings
      end
      
=begin rdoc
Override of {PluginLike#load_settings}

It reads the actions from the config object and creates the submenu
@note This method does nothing if the GUI associated with the plugin hasn't been
  initialized (for example, when called from {Plugin#initialize}).
@return [nil]
=end
      def load_settings
        if gui
          entries = Ruber[:config][:custom_actions, :actions]
          if @actions
            shortcuts = Hash[@actions.map{|a| [a.object_name, a.shortcut]}]
            remove_old_actions
          else
            shortcuts = Ruber[:config][:custom_actions, :shortcuts].dup
            shortcuts.each_pair{|k, v| shortcuts[k] = Qt::KeySequence.from_string v}
            @actions = []
          end
          add_actions entries
          @actions.each do |a|
            a.shortcut = shortcuts[a.object_name]
          end
        end
        nil
      end
      slots :load_settings
      
=begin rdoc
Override of {PluginLike#save_settings}

It stores the shortcuts associated with custom actions in the configuration
file.
@return [nil]
=end      
      def save_settings
        shortcuts = Hash[@actions.map{|a| [a.object_name, a.shortcut.to_string]}]
        Ruber[:config][:custom_actions, :shortcuts] = shortcuts
        nil
      end
      
      private
     
=begin rdoc
Executes the code associated with a custom action

Any exception raised from within the custom action is rescued, so there is no risk of
crash in case of an error in the action.

@param [Integer] idx the index of the action in the list of custom actions
@return [nil]
=end
      def execute_code idx
        code = @codes[idx]
        return unless code
        begin eval code, TOPLEVEL_BINDING, 'Custom tool'
        rescue Exception => ex
          tool_name = @actions[idx].object_name
          dlg = ExceptionDialog.new ex, Ruber[:main_window], true, 
              "The custom tool #{tool_name} raised the following exception:"
          dlg.set_button_text KDE::Dialog::Ok, i18n('Ok')
          dlg.exec
        end
        nil
      end
      
=begin rdoc
Inserts a list with actions associated with the given entries in the action list

@param [<String>] entries the texts of the actions to insert. If empty, a single,
  disabled action with @(Empty)@ as text will be created
@return [nil]
=end
      def add_actions entries
        if !entries.empty?
          entries.each_with_index do |data, idx|
            name, code = data
            @codes << code
            action = action_collection.add_action name, nil, nil
            action.object_name = name
            action.text = name
            @mapper.set_mapping action, idx
            connect action, SIGNAL(:triggered), @mapper, SLOT(:map)
            @actions << action
          end
        else
          action = action_collection.add_action "default_custom_action", nil, nil
          action.text = "(Empty)"
          action.enabled = false
          @actions << action
        end
        gui.plug_action_list 'custom_actions_actions', @actions
        nil
      end
      
=begin rdoc
Removes the actions from the action list
@return [nil]
=end
      def remove_old_actions
        gui.unplug_action_list 'custom_actions_actions'
        @actions.each do |a|
          action_collection.remove_action a
          @mapper.remove_mappings a
#           a.delete_later
        end
        @actions = []
        @codes.clear
        nil
      end
      
    end
    
=begin rdoc
Configuration widget for the custom actions plugin
=end
    class ConfigWidget < Qt::Widget
      
=begin rdoc
@param [Qt::Widget,nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::CustomActionsConfigWidget.new
        @ui.setup_ui self
        @actions = {}
        @action_widget = @ui.actions
        @action_widget.model = Qt::StandardItemModel.new @action_widget
        @ui.new_action.connect(SIGNAL(:clicked)){add_action}
        @ui.remove_action.connect(SIGNAL(:clicked)){remove_selected_action}
        @ui.rename_action.connect(SIGNAL(:clicked)){rename_selected_action}
        @action_widget.selection_model.connect(SIGNAL('selectionChanged(QItemSelection, QItemSelection)')) do |cur, prev|
          prev = prev.indexes
          store_code_for prev[0] unless prev.empty?
          cur = cur.indexes
          change_current_item cur[0] unless cur.empty?
          @ui.remove_action.enabled = !cur.empty?
          @ui.rename_action.enabled = !cur.empty?
          @ui.code.enabled = !cur.empty?
        end
      end
      
=begin rdoc
Reads the settings from the container

It fills the action widget with the entries of the @custom_actions/actions@
setting.

@param [SettingsContainer] cont the container
@return [nil]
=end      
      def read_settings cont
        @action_widget.model.clear
        @ui.code.clear
        cont[:custom_actions, :actions].each do |name, code|
          @actions[name] = code
          @action_widget.model.append_row Qt::StandardItem.new(name)
        end
        unless @action_widget.model.empty?
          idx = @action_widget.model.index 0, 0
          @action_widget.selection_model.select idx, Qt::ItemSelectionModel::ClearAndSelect
        end
        nil
      end

=begin rdoc
Stores the settings in the container

It stores the actions contained in the action widget in the @custom_actions/actions@
setting

@param [SettingsContainer] cont the container
@return [nil]
=end
      def store_settings cont
        idx = @action_widget.selection_model.selected_indexes[0]
        if idx
          item = @action_widget.model.item_from_index idx
          @actions[item.text] = @ui.code.to_plain_text
        end
        cont[:custom_actions, :actions] = @action_widget.model.map do |a|
          [a.text, @actions[a.text]]
        end
        nil
      end

=begin rdoc
Clears the widget

@return [nil]
=end
      def read_default_settings cont
        @action_widget.model.clear
        @ui.code.clear
        @actions.clear
        nil
      end
      
      private
      
=begin rdoc
Slot called when the user presses the New Action button

It displays a dialog asking for the name of the new action and inserts it in
the widget

@return [nil]
=end      
      def add_action
        name = KDE::InputDialog.get_text 'New custom action', 'Action name'
        if name
          item = Qt::StandardItem.new name
          @action_widget.model.append_row item
          selected = @action_widget.selection_model.selected_indexes[0]
          store_code_for selected if selected
          @action_widget.selection_model.select item.index, Qt::ItemSelectionModel::ClearAndSelect
        end
        nil
      end
      
=begin rdoc
Slot called when the user presses the Rename Selected Action button

It displays a dialog asking for the new name of the action and updates the widget

@return [nil]
=end      
      def rename_selected_action
        idx = @action_widget.selection_model.selected_indexes[0]
        return unless idx
        item = @action_widget.model.item_from_index idx
        old_name = item.text
        name = KDE::InputDialog.get_text 'Rename custom action', 'Action name',
            :value => old_name
        return unless old_name
        item.text = name
        @actions[name] = @actions[old_name]
        @actions.delete old_name
        nil
      end

=begin rdoc
Slot called when the user presses the Remove Selected Action button

@return [nil]
=end      
      def remove_selected_action
        idx = @action_widget.selection_model.selected_indexes[0]
        return unless idx
        item = @action_widget.model.item_from_index idx
        @actions.delete item.text
        @ui.code.clear
        @action_widget.model.remove_row item.row
        nil
      end
      
=begin rdoc
Slot called when a new action is selected

It associates the code in the code widget with the previously selected action

@param [Qt::ModelIndex] the index of the previously selected item
@return [nil]
=end
      def store_code_for idx
        name = @action_widget.model.data(idx).to_string
        @actions[name] = @ui.code.to_plain_text
        nil
      end

=begin rdoc
Slot called when a new action is selected

It inserts the text associated with the new selected action in the code widget
(an empty string is used if no code is associated with the action)

@param [Qt::ModelIndex] the index of the new selected item
@return [nil]
=end
      def change_current_item idx
        name = @action_widget.model.data(idx).to_string
        @ui.code.plain_text = @actions[name]
        nil
      end
      
    end
    
  end
  
end