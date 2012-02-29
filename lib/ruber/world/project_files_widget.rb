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

require 'pathname'

require_relative 'ui/project_files_rule_chooser_widget.rb'
require_relative 'ui/project_files_widget.rb'

module Ruber

=begin rdoc
Widget which displays and allows to modify the rules which determine whether a
file belongs to a project or not.

It contains a @Qt::TreeView@ where the rules are displayed and some buttons to add
and remove rules. The tree view has two columns: the first displays the contents
of the rules, while the second contains the rules' type (whether they're regexp
rules or file rules).

@see Ruber::ProjectFilesList
=end
  class ProjectFilesRuleChooser < Qt::Widget
    
=begin rdoc
Signal emitted when the rules have been changed
=end
    signals 'rules_edited()'
    
=begin rdoc
@return [Ruber::Project] the project the widget displays rules for
=end
    attr_writer :project
    
=begin rdoc
Validator class for regexp rules

It marks the text as @Qt::Validator::Intermediate@ if a valid regexp can't be
constructed from it and as @Qt::Validator::Acceptable@ if it can
=end
    class RegexpRuleValidator < Qt::Validator
      
=begin rdoc
Override of @Qt::Validator#validate@

@param [String] input the text in the widget
@param [Integer] _pos the cursor position (unused)
@return [Integer] @Qt::Validator::Acceptable@ if the text is a valid regexp and
 @Qt::Validator::Intermediate@ otherwise
=end
      def validate input, _pos
        begin 
          Regexp.new(input)
          Acceptable
        rescue RegexpError
          Intermediate
        end
      end
      
    end
    
    slots :remove_rule, :add_regexp_rule, :add_path_rule, :edit_rule, :change_button_state

=begin rdoc
@param [Qt::Widget] parent the parent widget
=end
    def initialize parent = nil
      super 
      @project = nil
      @ui = Ui::ProjectFilesRuleChooser.new
      @ui.setupUi self
      model = Qt::StandardItemModel.new @ui.rules_widget
      @ui.rules_widget.model = model
      model.horizontal_header_labels = %w[Pattern Type]
      connect @ui.add_regexp_btn, SIGNAL('clicked()'), self, SLOT('add_regexp_rule()')
      connect @ui.add_path_btn, SIGNAL('clicked()'), self, SLOT('add_path_rule()')
      connect @ui.remove_rule_btn, SIGNAL('clicked()'), self, SLOT('remove_rule()')
      connect @ui.rules_widget.selection_model, SIGNAL('selectionChanged(QItemSelection, QItemSelection)'), self, SLOT('change_button_state()')
      @ui.remove_rule_btn.enabled = false
    end
    
=begin rdoc
Override of @Qt::Widget#sizeHint@

@return [Qt::Size] the optimal size to use (350x200)
=end
    def sizeHint
      Qt::Size.new(350,200)
    end

=begin rdoc
The rules chosen by the user

@return [Array<String,Regexp>] an array containing the rules the user has chosen.
String entries correspond to file rules, while regexp entries correspond to regexp
rules
=end
    def rules
      @ui.rules_widget.model.enum_for(:each_row).map do |rule, type|
        if type.text == 'Path' then rule.text
        else Regexp.new rule.text
        end
      end
    end
    
=begin rdoc
Fills the tree view

*Note:* calling this method won't trigger the {#rules_edited} signal

@param [Array<String,Regexp>] list a list of the rules to insert in the view. String
entries will be considered as file rules, while regexp entries will be considered
regexp rules
@return [nil]
=end
    def rules= list
      model = @ui.rules_widget.model
      model.clear
      model.horizontal_header_labels = %w[Pattern Type]
      list.each do |rule|
        type = 'Path'
        if rule.is_a? Regexp
          type = 'Regexp'
          rule = rule.source
        end
        model.append_row [Qt::StandardItem.new(rule), Qt::StandardItem.new(type)]
      end
      nil
    end
    
    private 
    
=begin rdoc
Adds a rule to the tree view

The {#rules_edited} signal will be emitted after the rule has been inserted

@param [String] text the text to insert in the first column of the view. It must
be the path of the file for a file rule and the source of the regexp for a regexp
rule
@param [String] the name of the type of rule. Currently, this should be either
@Regexp@ or @File@
@return [(Qt::StandardItem, Qt::StandardItem)] the new items inserted in the view's
model
=end
    def add_rule text, type
      row = [Qt::StandardItem.new(text), Qt::StandardItem.new(type)]
      @ui.rules_widget.model.append_row row
      @ui.rules_widget.selection_model.select row[0].index, 
            Qt::ItemSelectionModel::SelectCurrent| Qt::ItemSelectionModel::Rows |
            Qt::ItemSelectionModel::Clear
      emit rules_edited
      row
    end
    
=begin rdoc
Enables or disables the the Remove button

The button is enabled if a rule is selected and disabled otherwise

@return [nil]
=end
    def change_button_state
      @ui.remove_rule_btn.enabled = 
          !@ui.rules_widget.selection_model.selected_rows.first.nil?
      nil
    end
    
=begin rdoc
Adds a file rule to the list

A dialog is shown to the user to select the file to add to the project

@return [nil]
=end
    def add_path_rule
      rule = KDE::FileDialog.get_open_file_name KDE::Url.from_path(@project.project_dir),
          '', self, "Add files to project"
      return unless rule
      path = Pathname.new(rule)
      if path.child_of?(@project.project_dir)
        prj_dir = Pathname.new(@project.project_dir)
        rule = path.relative_path_from(prj_dir).to_s
      end
      add_rule rule, 'Path'
      nil
    end
    
=begin rdoc
Adds a regexp rule to the list

The user is shown a dialog to choose the regexp

@return [nil]
=end
    def add_regexp_rule
      rule = KDE::InputDialog.get_text "Add regexp rule", "Regexp", 
          :validator => RegexpRuleValidator.new(self)
      return unless rule
      add_rule rule, 'Regexp'
      nil
    end
    
=begin rdoc
Removes the selected rule from the list

The {#rules_edited} signal is emitted after removing the rule

*Note:* this method doesn't check whether there's an item selected and will fail
if it isn't so
@return [nil]
=end
    def remove_rule
      row = @ui.rules_widget.selection_model.selected_rows.first
      @ui.rules_widget.model.remove_row row.row
      emit rules_edited
      nil
    end

  end

=begin rdoc
Widget where the user can choose the rules for files to include and exclude from
a project.

This widget contains two {ProjectFilesRuleChooser} widgets, one for the files to
include in the project and another for the files to exclude, and one lineedit where
the user chooses the extensions of the files to add by default to the project.
=end
  class ProjectFilesWidget < ProjectConfigWidget
    
=begin rdoc
Signal emitted whenever the contents of the widgets change so that the Apply button
in the dialg can be enabled accordingly
=end
    signals 'settings_changed()'
    
    slots 'read_settings(QObject*)', 'store_settings(QObject*)',
        'read_default_settings(QObject*)'
    
=begin rdoc
@param [Ruber::Project] prj the project the widget is for
=end
    def initialize prj
      super
      @ui = Ui::ProjectFilesWidget.new
      @ui.setupUi self
      @ui.include_rules.project = prj
      @ui.exclude_rules.project = prj
      connect @ui.include_rules, SIGNAL('rules_edited()'), self, SIGNAL('settings_changed()')
      connect @ui.extensions, SIGNAL('textChanged(QString)'), self, SIGNAL('settings_changed()')
    end
    
=begin rdoc
Reads the settings from the project

@param [SettingsContainer] prj the project
@return [nil]
=end
    def read_settings prj
      rules = project[:general, :project_files]
      @ui.include_rules.rules = rules[:include]
      @ui.exclude_rules.rules = rules[:exclude]
      exts = rules[:extensions]
      @ui.extensions.text = exts.join ' '
      nil
    end
    
=begin rdoc
Writes the settings to the project

@param [SettingsContainer] prj the project
@return [nil]
=end
    def store_settings prj
      res = {
        :include => @ui.include_rules.rules,
        :exclude => @ui.exclude_rules.rules,
        :extensions => @ui.extensions.text.split(/[\s,;]/)
      }
      project[:general, :project_files] = res
      nil
    end
    
  end
  
end
