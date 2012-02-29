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

  module CustomActions
    
    class Plugin < GuiPlugin
      
      def initialize psf
        super
        @actions = {}
      end
      
    end
    
    class ConfigWidget < Qt::Widget
      
      def initialize parent = nil
        super
        @ui = Ui::CustomActionsConfigWidget.new
        @ui.setup_ui self
      end

      def read_settings cont
        
      end
      
      def store_settings cont
        
      end
      
    end
    
  end
  
end