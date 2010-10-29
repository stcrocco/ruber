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

module Ruber
  
=begin rdoc
The Ruber status bar
=end
  class StatusBar < KDE::StatusBar
    
    slots 'display_information(const QString &)', 'update_cursor_position(KTextEditor::Cursor)',
        'update_view_mode(const QString &)', 'update()', 'update_selection_mode(bool)',
        'update_state()'
    
=begin rdoc
Creates a new StatusBar. _parent_ is the status bar's parent widget
=end
    def initialize parent
      super parent
      @view = nil
      @cursor_position_label = Qt::Label.new(self){self.margin = 3}
      @status_label = Qt::Label.new self
      @mode_label = Qt::Label.new(self){self.margin = 3}
      @selection_mode_label = Qt::Label.new(self){self.margin = 3}
#       @cursor_position_label.margin = 3
#       @status_label.margin = 3
#       @mode_label.margin = 3
#       @selection_mode_label.margin = 3
#       @status_label.margin = 3
      add_widget @cursor_position_label
      add_widget @status_label
      add_widget @mode_label
      add_widget @selection_mode_label
      update
    end
    
=begin rdoc
Associates an editor view with the status bar. This means that the status bar will
display information about that view.

_v_ can be the view to associate with the status bar or *nil*. If it's *nil*, the
status bar won't show anything
=end
    def view= v
      return if @view == v
      if @view 
        disconnect @view, nil, self, nil 
        disconnect @view.document, nil, self, nil
        clear_widgets
      end
      @view = v
      if v
        connect @view, SIGNAL('information_message(QString, QWidget*)'), self, SLOT('display_information(const QString &)')
        connect @view, SIGNAL('cursor_position_changed(KTextEditor::Cursor, QWidget*)'), self, SLOT('update_cursor_position(KTextEditor::Cursor)')
        connect @view, SIGNAL('view_mode_changed(QString, QWidget*)'), self, SLOT('update_view_mode(const QString &)')
        connect @view, SIGNAL('selection_mode_changed(bool, QWidget*)'), self, SLOT('update_selection_mode(bool)')
        connect @view.document, SIGNAL('modified_changed(bool, QObject*)'), self, SLOT('update_state()')
        connect @view.document, SIGNAL('modified_on_disk(QObject*, bool, KTextEditor::ModificationInterface::ModifiedOnDiskReason)'), self, SLOT('update_state()')
        update
      end
    end
    
=begin rdoc
Empties all the widgets in the status bar (it doesn't hide messages, though)
=end
    def clear_widgets
      @cursor_position_label.text = ''
      @status_label.pixmap = Qt::Pixmap.new
      @mode_label.text = ''
      @selection_mode_label.text= ''
    end
    
    private
    
=begin rdoc
Update the various widget so they respect the view's status
=end
    def update
      if @view
        pos = @view.cursor_position
        update_cursor_position pos
        update_view_mode @view.view_mode
        update_selection_mode @view.block_selection?
      else
        update_cursor_position nil
        update_view_mode nil
        update_selection_mode nil
      end
      update_state
    end
    
=begin rdoc
Displays the information emitted by the document associated with the view
=end
    def display_information msg
      show_message msg, 4000
    end
    
=begin rdoc
Updates the cursor position
=end
    def update_cursor_position pos
      if pos
        @cursor_position_label.text = "Line: #{pos.line+1} Col: #{pos.column+1}"
      else @cursor_position_label.text = ''
      end
    end
    
=begin rdoc
Updates the view mode
=end
    def update_view_mode mode
      @mode_label.text = mode ? mode : ''
    end
    
=begin rdoc
Updates the selection mode
=end
    def update_selection_mode mode
      @selection_mode_label.text = if mode.nil? then ''
      elsif mode then 'BLOCK'
      else 'LINE'
      end
    end

=begin rdoc
Updates the status icon
=end
    def update_state
      pix = if @view and ((d = @view.document).modified? or d.modified_on_disk?)
        d.icon.pixmap(16)
      else Qt::Pixmap.new(16, 16){|px| px.fill Qt::Color.new(Qt.transparent)}
      end
      @status_label.pixmap = pix
    end
    
  end

end