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

  class SaveModifiedFilesDlg < KDE::Dialog

    attr_reader :save
    def initialize docs, parent = nil
      super parent
      @save = true
      @docs = docs
      self.caption = "Save documents"
      self.modal = true
      create_buttons
      self.main_widget = KDE::VBox.new self
      Qt::Label.new KDE.i18n("The following documents have been modified. Do you want to save them before closing?"), main_widget
      @document_list = Qt::TreeView.new main_widget
      m = Qt::StandardItemModel.new @document_list
      def m.flags idx
        Qt::ItemIsSelectable|Qt::ItemIsEnabled|Qt::ItemIsUserCheckable
      end
      @document_list.model = m
      @document_list.root_is_decorated = false
      fill_list
    end

    def to_save
      res = []
      m = @document_list.model
      @docs.each_with_index do |d, i|
        res << d if m.item(i, 0).checked?
      end
      res
    end

    private

    def create_buttons
      self.buttons = Yes|No|Cancel

      save = KDE::StandardGuiItem.save
      save.text = KDE::i18n "&Save selected"
      set_button_gui_item Yes, save
      self.connect(SIGNAL('yesClicked()')) do
        @save = true
        done KDE::Dialog::Yes
      end

      set_button_gui_item No, KDE::StandardGuiItem.dont_save
      self.connect(SIGNAL('noClicked()')) do
        @save = false
        done KDE::Dialog::No
      end

      cancel = KDE::StandardGuiItem.cancel
      cancel.text = KDE::i18n "&Abort"
      set_button_gui_item Cancel, cancel
    end

    def fill_list
      @document_list.model.horizontal_header_labels = %w[Title Location]
      @docs.each do | d |
        row = [Qt::StandardItem.new(d.document_name), Qt::StandardItem.new(d.path)|| '']
        row[0].checked = true
        @document_list.model.append_row row
      end
    end

  end

end
