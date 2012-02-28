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

require_relative 'ui/find_in_files_widget'

module Ruber
  
  module FindInFiles

=begin rdoc
Dialog to set options for search/replace in files.

A single dialog is used for both search and replace. The action performed depends on whether the user clicks the Find or the Replace button.
This dialog can be used either as a modal or modeless dialog: if it is modal, use the value returned by #action to see whether the user chose find or replace; in modeless mode rely on the #find and #replace signals.
=end
    class FindReplaceInFilesDlg < KDE::Dialog

=begin rdoc
Signal emitted when the user presses the Find button.
=end
      signals :find
      
=begin rdoc
Signal emitted when the user presses the Replace button.
=end
      signals :replace
      
=begin rdoc
A list of possible matching modes
=end
      MODES = [:regexp, :plain]

=begin rdoc
A list of possible files where to search files
=end
      PLACES = [:project_files, :project_dir, :open_files, :custom_dir]
      
=begin rdoc
A map between the text shown in the file type widget and rak options
=end
      FILE_TYPES = {
        'C++ files' => :cpp,
        'C files' => :c,
        'C# files' => :csharp,
        'CSS files' => :css,
        'Elisp files' => :elisp,
        'Erlang files' => :erlang,
        'Fortran files' => :fortran,
        'Haskell files' => :haskell,
        'hh files' => :hh,
        'HTML files' => :html,
        'Java files' => :java,
        'Javascript file' => :js,
        'jsp files' => :jsp,
        'Lisp files' => :lisp,
        'Makefiles' => :make,
        'Mason files' => :mason,
        'OCaml files' => :ocaml,
        'Parrot files' => :parrot,
        'Perl files' => :perl,
        'PHP files' => :php,
        'Prolog files' => :prolog,
        'Python files' => :python,
        'Ruby files' => :ruby,
        'Scheme files' => :scheme,
        'Shell files' => :shell,
        'SQL files' => :sql,
        'TCL files' => :tcl,
        'TeX files' => :tex,
        'Text files' => :text,
        'tt files' => :tt,
        'Visual Basic files' => :vb,
        'Vim files' => :vim,
        'XML files' => :xml,
        'YAML files' => :yaml
      }
      
=begin rdoc
A specialized completer for use with the line edits in the dialog.
      
The only difference from the standard @Qt::Completer@ is that it creates its model by itself
=end
      class Completer < Qt::Completer
        
=begin rdoc
@param [Qt::Widget, nil] parent the completer's parent object
=end
        def initialize parent = nil
          super
          self.model = Qt::StringListModel.new self
        end
        
=begin rdoc
Adds a new string to the completer

@param [String] str the string to add
@return [nil]
=end
        def add_entry str
          row = model.row_count
          model.insert_rows row, 1
          model.set_data model.index(row), Qt::Variant.new(str), Qt::DisplayRole
        end
        
      end
      
=begin rdoc
The action chosen by the user when closing the dialog
@return [Symbol, nil] @:find@ if the user pressed the Find button, @:replace@ if
he chose the Replace button and *nil* if he pressed the Cancel button or if the
dialog hasn’t been closed as yet
=end
      attr_reader :action
      
=begin rdoc
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize parent = Ruber[:main_window]
        @operation = nil
        super
        set_buttons User1|User2|Cancel
        set_button_text User1, KDE.i18n('Replace')
        set_button_text User2, KDE.i18n('Find')
        set_default_button User2
        enable_button User1, false
        enable_button User2, false
        
        @ui = Ui::FindReplaceInFilesWidget.new
        @ui.setupUi main_widget
        
        @ui.find_text.completer = Completer.new @ui.find_text
        @ui.replace_text.completer = Completer.new @ui.replace_text
        @ui.custom_filter.completer = Completer.new @ui.custom_filter
        
        @ui.directory.mode = KDE::File::Directory
        
        
        @ui.find_text.connect SIGNAL('textChanged(QString)') do
          enable = !@ui.find_text.text.empty?
          enable_button User1, enable
          enable_button User2, enable
        end
        
        @ui.replace_text.connect(SIGNAL('textChanged(QString)')) do
          self.default_button = @ui.replace_text.text.empty? ? User2 : User1
        end
        
        @ui.places.connect(SIGNAL('currentIndexChanged(int)')) do |i| 
          @ui.directory.enabled = (i == @ui.places.count - 1) 
        end
        
        button(User1).connect SIGNAL(:clicked) do
          @action = :replace
          add_completions
          accept
          emit replace
        end
        
        button(User2).connect SIGNAL(:clicked) do
          @action = :find
          add_completions
          accept
          emit find
        end
        
        @ui.use_predefined_filters.connect SIGNAL('toggled(bool)') do |b|
          @ui.types.enabled = b
        end
        
        @ui.all_files.connect SIGNAL('toggled(bool)') do |b|
          @ui.types.enabled = !b
        end
        
        @ui.types.line_edit.read_only = true
        @ui.types.view.install_event_filter Filter.new(self)
        @ui.types.view.viewport.install_event_filter Filter.new(self)
        @ui.types.add_items FILE_TYPES.keys.sort
        @ui.types.model.each do |i|
          i.checkable = true
          i.checked = (i.text == 'Ruby files' || i.text == 'YAML files')
        end
        create_filter_text
        
      end
      
=begin rdoc
Whether the "Project files" and "Project directory" entries should be shown
in the _Search in_ widget or not.
@param [Boolean] val whether to show the entries or not
@return [Boolean] _val_
=end
      def allow_project= val
        if @ui.places.count == 4 and !val
          2.times{@ui.places.remove_item 0}
        elsif @ui.places.count == 2 and val
          @ui.places.insert_items 0, ['Project files', 'Project directory']
        end
      end
      
=begin rdoc
The text in the Find widget
@return [String] the text in the Find widget
=end
      def find_text
        @ui.find_text.text
      end

=begin rdoc
The text in the Replace widget
@return [String] the text in the Replace widget
=end
      def replacement_text
        @ui.replace_text.text
      end
      
=begin rdoc
The mode chosen by the user.
@return [Symbol] the mode chosen by the user. It can be either @:regexp@ or @:plain@
=end
      def mode
        MODES[@ui.mode.current_index]
      end
      
=begin rdoc
Whether the search should be performed only in whole words or not

@return [Boolean] whether the user chose to perform a search only on whole words
or also in the middle of a word
=end
      def whole_words?
        @ui.whole_words.checked?
      end
      
=begin rdoc
Whether the search should be case sensitive or not

@return [Boolean] whether or not the user chose to perform a case sensitive search
=end
      def case_sensitive?
        @ui.case_sensitive.checked?
      end
      
=begin rdoc
The file types the search should be restricted to
@return [<Symbol>, nil] an array containing the file types the user chose in the
types combo box (converted so they match the name of the options rak accepts) or
nil if the user checked the _All files_ radio button
=end
      def filters
        if @ui.use_predefined_filters.checked?
          @ui.types.model.map{|i| i.checked? ? FILE_TYPES[i.text] : nil}.compact
        else nil
        end
      end
      
=begin rdoc
The regexp to pass to rak -g option

@return [String, nil] the source of the regexp or *nil* if the user didn’t fill
the _Custom filter_ widget
=end
      def custom_filter
        text = @ui.custom_filter.text
        text.empty? ? nil : text
      end
      
=begin rdoc
Whether the search should be made on all files or only on some file types

@return [Boolean] whether the search should be performed on all files or only in
those with file type matching the entries selected in the File type combo box
=end
      def all_files?
        @ui.all_files.checked?
      end
      
=begin rdoc
Where to find the files to search:

@return [Symbol] one of the following symbols, according to what the user chose
in the _Search in_ combo box:
 * @:project_files@ perform the search only among the files belonging to the current project
 * @:project_directory@ perform the search among all the files in the current proejct’s directory
 * @:open_files@ perform the search only in files corresponding to open documents (note that the search will be performed in the files, not in the text in the documents)
 * @:custom_dir@ perform the search among all the files in the directory selected by the user in the Directory widget
=end
      def places
        idx = @ui.places.current_index 
        idx +=2 if @ui.places.count == 2
        PLACES[idx]
      end
      
=begin rdoc
The contents of the Directory widget
@return [String, nil] the contents of the Directory widget or nil if the wigdet
is disabled (because the user chose something else than _Custom directory_ in the
_Search in_ widget)
=end
      def directory
        @ui.directory.enabled? ? @ui.directory.text : nil
      end
      
=begin rdoc
Sets the contents of the dialog’s widgets to their default values

This method doesn't erase the completers and is usually called before showing the dialog.
*Note:* this also sets allow_project to true
=end
      def clear
        self.allow_project = true
        @action = nil
        @ui.find_text.text=''
        @ui.replace_text.clear
        @ui.mode.current_index = 0
        @ui.whole_words.checked = false
        @ui.case_sensitive.checked = true
        @ui.use_predefined_filters.checked = true
        @ui.custom_filter.clear
        @ui.places.current_index = 0
        @ui.find_text.set_focus
        @ui.directory.enabled = false
      end
      
=begin rdoc
Event filter to make the Predefined filters combo box be checkable.

@return [Boolean] *true* if the event should be blocked and *false* if it should be propagated
=end
      def eventFilter obj, e
        if e.type == Qt::Event::MouseButtonRelease
          obj=obj.parent unless obj.is_a?(Qt::ListView)
          idx = obj.index_at e.pos
          if idx.valid?
            op = Qt::StyleOption.new
            op.initFrom obj
            op.rect = obj.visual_rect(idx)
            r = obj.style.sub_element_rect(Qt::Style::SE_ViewItemCheckIndicator, op)
            if r.contains(e.pos)
              it = @ui.types.model.item_from_index idx
              it.checked = !it.checked?
              create_filter_text
              return true
            end
          end
        end
        false
      end
      
      private
      
=begin rdoc
Adds the values in the various line edit widgets to the respective completers

@return [nil]
=end
      def add_completions
        @ui.find_text.completer.add_entry @ui.find_text.text
        @ui.replace_text.completer.add_entry @ui.replace_text.text unless @ui.replace_text.text.empty?
        @ui.custom_filter.completer.add_entry @ui.custom_filter.text unless @ui.custom_filter.text.empty?
      end
      
=begin rdoc
Fills the text of the File type widget with a string according to the selected entries

@return [nil]
=end
      def create_filter_text
        text = @ui.types.model.select{|i| i.checked?}.map{|i| i.text}.join '; '
        text = 'All files' if text.empty?
        @ui.types.edit_text = text
      end
      
=begin rdoc
@private

Helper class whose only task is to have an eventFilter method which calls its parent’s eventFilter.

It’s needed because setting the dialog as event filter object doesn’t seem to work
=end
      class Filter < Qt::Object
=begin rdoc
Calls the parent object's @eventFilter@ method
@return [Boolean] what the parent object's @eventFilter@ method returned
=end
        def eventFilter o, e
          parent.eventFilter o, e
        end
      end
      
    end
    
  end
  
end