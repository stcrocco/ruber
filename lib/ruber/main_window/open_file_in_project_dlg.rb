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

require 'facets/boolean'

require 'pathname'

require_relative "ui/open_file_in_project_dlg"

module Ruber

=begin rdoc
 This class is a dialog where the user can choose a file to open among the
 files of the project.

 The dialog is made by two widgets: a <tt>KDE::LineEdit</tt>, where the user
 can enter a file pattern, and a <tt>Qt::ListView</tt>, where all files in
 the project matching the 
 given regexp are shown. The user can choose the file either by pressing the
 Return key or by activating an item in the list.
 
 The pattern is interpreted as a regexp and is checked against the whole path
 of the file if it contains a pattern separator character (the '/' character
 on UNIX) and only
 against the name of the file otherwise. When the user changes the pattern, 
 the file list is changed accordingly. This is achieved using a
 filter model derived from <tt>Qt::SortFilterProxyModel</tt>.
=end
  class OpenFileInProjectDlg < Qt::Dialog

=begin rdoc
 Class implementing the filter for the +OpenFileInProjectDlg+ class.
=end
    class FilterModel < Qt::SortFilterProxyModel

=begin rdoc
 Returns a new +FilterModel+.
 =====Arguments
 _parent_:: the <tt>Qt::Object</tt> parent of the filter
=end
      def initialize parent = nil
        super
        @filter = nil
        @role = Qt::DisplayRole
      end

=begin rdoc
 Changes the regexp used to filter the files, then re-applies the filter
 calling the +invalidate+ method.
 =====Arguments
 _value_:: the new regexp. It can be +nil+ or a regexp. In the first case,
           the filter won't be applied.
 =====TODO
 On Windows, allow to also use the '\' character as pattern separator.
 The problem is that that character is also the escape character in a regexp,
 so things may become complicated.
=end
      def filter= value
        @filter = value
        # TODO This doesn't work
        #on windows, where one can also use \ as separator. The problem is that in regexp
        #it's the escape character, so one must use something like
        #value.include?(File::SEPARATOR) || (File::ALT_SEPARATOR and value.match(/\\{2}))
        @role = if @filter and !value.source.include?(File::SEPARATOR) then Qt::UserRole + 1 
        else Qt::DisplayRole
        end
        invalidate
      end

      protected

=begin rdoc
 Reimplementation of Qt::SortFilterProxyModel#filterAcceptsRow which returns
 +true+ if the file matches the regexp and +false+ otherwise (if the regexp
 is +nil+, this method always returns +true+).
 
 If the source of the regexp contains the pattern separator, the whole
 filename is tested, otherwise only the name of the file will be tested.
=end
      def filterAcceptsRow r, parent
        return true unless @filter
        idx = source_model.index r, 0, parent
        res = idx.data(@role).to_string.match @filter
        res.to_bool #It seems that it's required to return true or false - other objects don't work
      end

    end

    slots 'change_filter(const QString &)', 'item_activated(const QModelIndex &)'

=begin rdoc
 Returns a new +OpenFileInProjectDlg+.
 =====Arguments
 _parent_:: the widget parent of the dialog
=end
    def initialize prj, parent = nil
      super
      files = prj.project_files.to_a
      @base_dir = Ruber.current_project.project_directory
      @ui = Ui::OpenFileInProjectDlg.new
      @ui.setupUi self
      @ui.regexp_error.hide
      filter = FilterModel.new @ui.file_list
      model = Qt::StandardItemModel.new filter
      @ui.file_list.model = filter
      filter.source_model = model
      files.each do |f|
        path = f.sub %r{\A#{Regexp.quote(@base_dir)}/}, ''
        it = Qt::StandardItem.new path
        it.set_data Qt::Variant.new(File.basename(path))
        it.editable = false
        model.append_row it
      end      
      @ui.pattern.install_event_filter self
      connect @ui.pattern, SIGNAL('textChanged(const QString &)'), self, SLOT('change_filter(const QString &)')
      connect @ui.file_list, SIGNAL('activated(const QModelIndex &)'), self, SLOT('item_activated(const QModelIndex &)')
      @ui.file_list.selection_model.select @ui.file_list.model.index(0,0), 
        Qt::ItemSelectionModel::ClearAndSelect|Qt::ItemSelectionModel::Rows
      @ui.file_list.current_index = @ui.file_list.model.index(0,0)
#       @ui.file_list.header.resize_sections Qt::HeaderView::ResizeToContents
    end

=begin rdoc
 Returns the file chosen by the user or +nil+ if no file has been chosen. The
 chosen file is the file last selected in the file list.
=end
    def chosen_file
      selection = @ui.file_list.selection_model.selected_indexes
      return nil if selection.empty?
      idx = selection.first
      File.join(@base_dir, idx.data.to_string.gsub(/\A\./,''))
    end

=begin rdoc
 Reimplements Qt::Object.eventFilter. It blocks the +KeyPress+ events for the 
 up and down keys (but only if there's no modifier) and redirects them to the 
 file list widget. All other events are allowed to pass. This allows to scroll
 the list without taking the focus from the pattern widget.
 =====Arguments
 _obj_:: the object whose events should be filtered
 _e_:: the event
=end
    def eventFilter obj, e
      if e.type != Qt::Event::KeyPress then return false
      else
        if (e.key == Qt::Key_Down || e.key == Qt::Key_Up) and e.modifiers == Qt::NoModifier
# TODO: reintroduce the last parameter when it stops giving errors
          new_ev = Qt::KeyEvent.new e.type, e.key, e.modifiers, e.text, 
e.is_auto_repeat, e.count
          Ruber[:app].post_event @ui.file_list, new_ev
          true
        else false
        end
      end
    end

    private
    
=begin rdoc
 Changes the pattern used by the filter model applied to the view so that it is
 equal to the text currently in the pattern widget and selects the first item in
 the view (if any). If the list is empty, it also disables the Ok button.
 =====Arguments
 _text_:: the new pattern
=end
    def change_filter text
      begin
        reg = text.empty? ? nil : Regexp.new( text )
        @ui.file_list.model.filter= reg
        @ui.file_list.selection_model.select @ui.file_list.model.index(0,0), 
          Qt::ItemSelectionModel::ClearAndSelect|Qt::ItemSelectionModel::Rows
        @ui.file_list.current_index = @ui.file_list.model.index(0,0)
        @ui.buttons.button(Qt::DialogButtonBox::Ok).enabled = @ui.file_list.model.row_count > 0
        @ui.regexp_error.hide
      rescue RegexpError 
        @ui.regexp_error.show
      end
    end

=begin rdoc
 Closes the dialog with the <tt>Qt::Dialog::Accepted</tt> status and selects the
 index passed as argument.
 =====Arguments
 _idx_:: the index of the activated item.
=end
    def item_activated idx
      @ui.file_list.selection_model.select idx, Qt::ItemSelectionModel::ClearAndSelect|
          Qt::ItemSelectionModel::Rows
      @ui.file_list.current_index = idx
      accept
    end

  end

end
