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

require 'tempfile'

require 'ruber/filtered_output_widget'

require_relative 'ui/config_widget'

module Ruber
  
  module FindInFiles

=begin rdoc
Tool widget to display the output of a search.

It adds the "Filter on file names" toggle action to the RBM menu: when its on,
any filter will be applied to the rows containing the file names; when it's off
(the default) the filter will only be applied to rows containing the found text.
=end
    class FindWidget < FilteredOutputWidget
      
      slots 'filter_on_filename_changed(bool)'
    
=begin rdoc
@private
The number of the role used to store the kind of find information stored in an
index
=end
      FIND_ROLE = IsTitleRole + 1
     
=begin rdoc
Creates a new instance
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize parent = nil
        super parent, :view => :tree, :filter => Filter.new, :use_default_font => true
        filter_model.filter_key_column = 1
        filter_model.exclude = :toplevel
        model.append_column []
        @current_file_item = Qt::StandardItem.new
        filter_model.connect(SIGNAL('rowsInserted(QModelIndex, int, int)')) do |par, st, en|
          if !par.valid?
            st.upto(en) do |i|
              view.set_first_column_spanned i, par, true
              view.expand filter_model.index(i, 0, par)
            end
          end
        end
        self.connect(SIGNAL(:about_to_fill_menu)) do
          actions.delete 'copy'
          actions.delete 'copy_selected'
          action_list.delete 'copy'
          action_list.delete 'copy_selected'
        end
        view.all_columns_show_focus =  true
        view.header_hidden = true
        setup_actions
      end
      
=begin rdoc
Displays the output of rak in the widget

Results in the same file are put under a single parent in the tree

@param [<String>] lines the output from rak, divided into lines. Each line should
have the format @filename line|text@. Lines which don't have this format are ignored
@return [nil]
=end
      def display_output lines
        lines.each do |l|
          match = l.match(/^(.+)\s+(\d+)\|(.*)$/)
          next unless match
          file, line, text = match.to_a[1..-1].map{|i| i.strip}
          if @current_file_item.text != file
            @current_file_item = model.insert(file, :message, nil)[0]
            @current_file_item.set_data Qt::Variant.new('file'), FIND_ROLE
          end
          it_line, it_text = model.insert [line.to_s, text], [:output1, :output],
              nil, :parent => @current_file_item
          it_line.set_data Qt::Variant.new('line'), FIND_ROLE
          it_text.set_data Qt::Variant.new('text'), FIND_ROLE
        end
        nil
      end

=begin rdoc
Remove the contents from the widget

@return *nil*
=end
      def clear_output
        @current_file_item = Qt::StandardItem.new
        super
        nil
      end
      
      private
      
=begin rdoc
Adds the custom actions to the RMB menu

@return [nil]
=end
      def setup_actions
        a = KDE::ToggleAction.new 'Filter on File Names', self
        actions['find_in_files-filter_on_files'] = a
        action_list.insert_after 'clear_filter', nil, 'find_in_files-filter_on_files'
        connect a, SIGNAL('toggled(bool)'), self, SLOT('filter_on_filename_changed(bool)')
        nil
      end
      
=begin rdoc
Override of {Ruber::OutputWidget#find_filename_in_index}

If the index corresponds to a file name, retrieves the line from the
first child, while if it corresponds to a another entry, retrieves the file name
from its parent and the line from the appropriate column on the same line

@return [String, Integer] see {Ruber::OutputWidget#find_filename_in_index} for
more information
=end
      def find_filename_in_index idx
        it = model.item_from_index idx
        if it.data(FIND_ROLE).to_string == 'file'
          line = it.row_count > 0 ? it.child(0,0).text.to_i : 0
          [it.text, line]
        else
          file = it.parent.text
          line = (it.data(FIND_ROLE).to_string == 'line' ? it : it.parent.child(it.row, 0)).text.to_i
          [file, line]
        end
      end
      
=begin rdoc
Slot called when the user toggles the "Filter on file names" action

@param [Boolean] on whether the user switched the action on or off
=end
      def filter_on_filename_changed b
        filter_model.filter_key_column = b ? 0 : 1
        filter_model.exclude = b ? :children : :toplevel
      end
      
=begin rdoc
@private
Filter model used by the view in FindWidget
=end
      class Filter < FilterModel
        
=begin rdoc
Filters a row

If the filter column is the first, always returns *true* for child rows, while
always returns *true* for top level rows for all other values of the filter column

@return [Boolean]
=end
        def filterAcceptsRow row, parent
          if filter_key_column == 0 
            parent.valid? ? true : super
          else parent.valid? ? super : true
          end
        end
        
      end
      
    end
    
=begin rdoc
Tool widget which displays the results of a replace operation

The widget consists of a checkable tree view with two columns. The first column
contains the text which will be replaced, while the second contains the text
after the replacement. The user can uncheck the replacements he doesn't want,
both linewise or filewise. The replacement is only carried out when the user
presses the Replace button in the tool widget. A Clear button empties the tool
widget.
=end
    class ReplaceWidget < OutputWidget
      
=begin rdoc
@private

Model used in the ReplaceWidget

It only differs from #{OutputWidget::Model} in the flags it gives to items
=end
      class Model < OutputWidget::Model
        
        def flags idx
          default_flags = Qt::ItemIsSelectable | Qt::ItemIsEnabled
          if !idx.parent.valid? or idx.column == 0 
            default_flags | Qt::ItemIsUserCheckable
          else default_flags
          end
          
        end
        
      end
      
=begin rdoc
Signal emitted when a new file is added to the model.

@param [String] str the name of the file
=end
      signals 'file_added(QString)'

      slots :replace
          
      slots 'file_modified(QString)'
      
=begin rdoc
Creates a new instance

@param [Qt::Object, nil] parent the parent object
=end
      def initialize parent = nil
        super parent, :view => :tree, :use_default_font => true
        self.auto_scroll = false
        model.global_flags |= Qt::ItemIsUserCheckable.to_i
        def model.flags idx
          if idx.column == 0 then super idx
          else (Qt::ItemIsEnabled | Qt::ItemIsSelectable).to_i
          end
        end
        @replace_button = Qt::PushButton.new( 'Replace', self){self.enabled = false}
        @clear_button = Qt::PushButton.new('Clear', self){self.enabled = false}
        layout.remove_widget view
        layout.add_widget view, 0,0,1,0
        layout.add_widget @replace_button, 1, 0
        layout.add_widget @clear_button, 1, 1
        model.horizontal_header_labels = ['Line', 'Original text', 'Replacement text']
        @file_items = {}
        @watcher = KDE::DirWatch.new self
        connect @watcher, SIGNAL('dirty(QString)'), self, SLOT('file_modified(QString)')
        connect @replace_button, SIGNAL(:clicked), self, SLOT(:replace)
        connect @clear_button, SIGNAL(:clicked) , self, SLOT(:clear_output)
        self.connect(SIGNAL(:about_to_fill_menu)) do
          actions.delete 'copy'
          actions.delete 'copy_selected'
          action_list.delete 'copy'
          action_list.delete 'copy_selected'
        end
        model.connect(SIGNAL('rowsInserted(QModelIndex, int, int)')) do |par, st, en|
          if !par.valid?
            st.upto(en) do |i|
              view.set_first_column_spanned i, par, true
              view.expand model.index(i, 0, par)
            end
          end
        end
        Ruber[:find_in_files].connect SIGNAL(:replace_search_started) do
          @replace_button.enabled = false
          @clear_button.enabled = false
          view.header.resize_mode = Qt::HeaderView::Fixed
          self.cursor = Qt::Cursor.new Qt::WaitCursor
        end
        Ruber[:find_in_files].connect SIGNAL(:replace_search_finished) do
          @watcher.start_scan
          @replace_button.enabled = true
          @clear_button.enabled = true
          h = view.header
          view.resize_column_to_contents 0
          view.header.resize_mode = Qt::HeaderView::Fixed
          av_size = h.rect.width - h.section_size( 0)
          view.set_column_width 1,  av_size / 2.0
          view.set_column_width 2, av_size / 2.0
          unset_cursor
        end
        view.all_columns_show_focus =  true
      end
      
=begin rdoc
Inserts the name of the files in the output widget

Each file is added to the file watcher, so that replacing in it can be disabled
if it changes.

@param [<String>] lines an array containing the name of the files
@return [nil]
=end
      def display_output lines
        lines.each do |l|
          it = model.insert([l, nil, nil], :message, nil)[0]
          it.checked = true
          @watcher.add_file l
          @watcher.stop_scan
          @file_items[l] = it
          emit file_added(l)
        end
        nil
      end
      
=begin rdoc
Adds a replacement line to the widget

A replacement line is made of three columns: the line number in the file,
the original text and the text after the replacement.

@param [String] file the file where the line is
@param [Integer] line the line number (0 based)
@param [String] orig the original text of the line
@param [String] repl the text of the line after the replacement
@return [nil]
=end
      def add_line file, line, orig, repl
        parent = @file_items[file]
        row = model.insert [(line+1).to_s, orig, repl], [:output1, :output, :output], nil, :parent => parent
        row[0].checked = true
        view.expand parent.index
        nil
      end
      
=begin rdoc
Empties the widget

@return [nil]
=end
      def clear_output
        @file_items.clear
        @file_items.each_key{|k| @watcher.remove_file k}
        @replace_button.enabled = false
        @clear_button.enabled = false
        super
      end
      
      private
      
=begin rdoc
Performs the replacements chosen by the user

Calling this method applies replaces the original text with the replacement
texts for all the lines chosen by the user (that is, the checked lines which
belong to a checked file). A message box is shown if some replacements cannot be
carrried out.

Items corresponding to successful replacements are removed from the view.

@return [nil]
=end
      def replace
        failed = {}
        success = []
        docs = Ruber[:docs].documents_with_file.map{|d| [d.path, d]}.to_h
        model.each_row.each_with_index do |r, i|
          if r[0].checked?
            res = replace_file r[0], docs[r[0].text]
            if res then failed[r[0].text] = res 
            else success << r[0]
            end
          end
        end
        success.reverse_each do |i| 
          @file_items.delete i.text
          model.remove_row i.row
        end
        create_error_message = Proc.new do |f, err|
          if err == :doc_modified then "#{f}: modified in editor"
          else "#{f}: #{err.message}"
          end
        end
        unless failed.empty?
          failed_text = failed.map{|f, err| create_error_message.call f, err}.join "\n"
          KDE::MessageBox.sorry Ruber[:main_window], "The following files couldn't be modified:\n#{failed_text}"
        end
        nil
      end
      
=begin rdoc
Carries out the replacements for a file

If the file is associated with a document and the document isn't modified, the
text in the editor is changed to reflect the modifications in the file. If the
document is modified (which means its contents differ from the contents of the
file), instead, nothing will be done.

@param [Qt::StandardItem] it the item corresponding to the file in the model
@param [Document, nil] doc the document associated with the file, if any
@return [Symbol, SystemCallError, nil] *nil* if the replacement was carried out
correctly; an exception derived from @SystemCallError@ if it wasn't possible to
write the file and the symbol @:doc_modified@ if the replacement wasn't attempted
because the document corresponding to the file was modified
=end
      def replace_file it, doc
        file = it.text
        lines_to_replace = {}
        it.each_row do |line, _, repl|
          lines_to_replace[line.text.to_i] = repl.text if line.checked?
        end
# TODO see what the line below did. In my opinion, it is the remainder of some line
# I added for testing and forgot to remove
#         path = file.sub( '/home/stefano/tmp/ruber', '').gsub('/', '_')
        lines = File.readlines(file)
        lines_to_replace.each_pair{|idx, text| lines[idx - 1] = text + "\n"}
        new_text = lines.join ''
        if doc
          pos = doc.view.cursor_position if doc.view
          return :doc_modified if doc.modified?
          text = nil
          doc.editing do
            text = doc.text
            doc.clear
            doc.text = new_text
          end
          doc.save
          doc.view.go_to pos.line, pos.column if pos
        else
          Tempfile.open(File.basename(file)) do |f|
            f.write new_text
            f.flush
            begin 
              FileUtils.cp f.path, file
            rescue SystemCallError => e
              return e
            end
          end
        end
        nil
      end
      
=begin rdoc
Slot called when a file among those listed for replacement is modified on disk

When this happens, the file is marked as modified in the view and it is no longer
checkable (the same happens for its children)

@return [nil]
=end
      def file_modified file
        @watcher.remove_file file
        it = @file_items[file]
        if it
          it.text = it.text + "\t [MODIFIED]"
          it.checked = false
          view.collapse it.index
          model.set_data it.index, Qt::Variant.new, Qt::ForegroundRole
          it.flags = Qt::ItemIsSelectable
          it.each_row do |r|
            r[0].checked = false
            r.each{|i| i.flags = Qt::ItemIsSelectable}
          end
        end
        nil
      end
      
    end
    
=begin rdoc
The configuration widget for the plugin
=end
    class ConfigWidget < Qt::Widget
      
=begin rdoc
@param [Qt::Widget, nil] parent the parent widget
=end
      def initialize parent = nil
        super
        @ui = ::Ui::FindInFilesConfigWidget.new
        @ui.setupUi self
      end
      
    end
    
    
  end
  
end
