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

require 'ruber/settings_dialog_manager'

module Ruber

=begin rdoc
Dialog used to change the options contained in an SettingsContainer. It is a specialized
<tt>KDE::PageDialog</tt>.

The widgets added to the option container are displayed in pages corresponding to
the captions included in the widgets' description. If more than one widget has
the same caption, they're displayed in the same page, one below the other (using
a Qt::VBoxLayout). The icon used for each page is the first one found among the
widgets in that page.

The process of keeping the options in sync between the widgets and the option container
can be automatized using the functionality provided by the internal SettingsDialogManager.
If this automatic management can't be achieved for a particular option (for example,
because the value should be obtained combining the data of more than one widget),
you can still automatically manage the other widgets and integrate the manual
management of the widgets which need it with the automatic management. To do so,
you'll need to define a read_settings, a store_settings and a read_default_settings
method in your widget. In this case, you can access the dialog using the @settings_dialog
instance variable, which is created by this class when the widget is created.

===Manual option management example
Suppose you have an option called <tt>:default_path</tt> in the :general group which stores a path. In
your widget, however, the path is split in two parts: the directory and the filename,
which are shown in two line edit widgets, called respectively <tt>default_dir_widget</tt>
and <tt>default_file_widget</tt>. Since the automatic option management system assumes
that each option corresponds to a single widget, you can't use it. So, you define
a <tt>read_settings</tt>, a <tt>store_settings</tt> and a <tt>read_default_settings</tt>
method in your widget class like this:

  class MyWidget < Qt::Widget

    def initialize parent = nil
      super
      @default_dir_widget = KDE::LineEdit.new self
      @default_file_widget = KDE::LineEdit.new self
    end

    def read_settings
      path = @settings_dialog.settings_container[:general, :default_path]
      @default_dir_widget.text = File.dirname(path)
      @default_file_widget.text = File.basename(path)
    end
    
    def store_settings
      path = File.join @default_dir_widget.text, @default_file_widget.text
      @settings_dialog.settings_container[:general, :default_path] = path
    end
    
    def read_default_settings
      path = @settings_dialog.settings_container.default(:general, :default_path)
      @default_dir_widget.text = File.dirname(path)
      @default_file_widget.text = File.basename(path)
    end

  end

Note that the <tt>@settings_dialog</tt> instance variable has been automatically
created by the dialog when the widget has been created and contains a reference
to the dialog itself.

=end
  class SettingsDialog < KDE::PageDialog
    
    slots :store_settings, :read_default_settings
    
=begin rdoc
The option container. This method can be used by the widgets which need to define
the read_settings, store_settings and read_default_settings methods to access the
option container of the dialog.
=end
    attr_accessor :container
    alias_method :settings_container, :container
    
=begin rdoc
Creates a new SettingsDialog. The dialog will store settings in the SettingsContainer
_container_, manage the options _options_ and display the widgets _widgets_.
_options_ is an array of option objects (see SettingsContainer#add_option).
_widgets_ is an array containing
the description of the widgets to be displayed in the dialog (see SettingsContainer#add_widget).

This method defines a new instance variable for each widget it creates. The variable
is called @settings_dialog and contains a reference to the dialog itself. It can be
used from custom widgets' implementation of read_settings, store_settings and
read_default_settings methods to access the option container corresponding to
the dialog.
=end
    def initialize container, options, widgets, title = nil
      super Ruber[:main_window]
      self.buttons = Ok|Apply|Cancel|Default
      self.window_title = title if title
      @container = container
      grouped_widgets = Hash.new{|h, k| h[k] = []}
      widgets.each{|w| grouped_widgets[w.caption] << w }
      @page_items = []
      @widgets = Hash.new{|h, k| h[k] = []}
      grouped_widgets.keys.sort.each do |c|
        icon = nil
        page = Qt::Widget.new self
        page.layout = Qt::VBoxLayout.new page
        grouped_widgets[c].each do |w| 
          widget = if w.respond_to?(:code) and w.code then widget_from_code(w.code) 
          else widget_from_class(w.class_obj)
          end
          widget.parent = page
          widget.instance_variable_set :@settings_dialog, self
          @widgets[c] << widget
          page.layout.add_widget widget
          icon ||= KDE::Icon.new w.pixmap if w.pixmap rescue nil
        end
        @page_items << add_page(page, c)
        @page_items[-1].icon = icon if icon
      end
      @manager = SettingsDialogManager.new self, options, @widgets.values.flatten
      connect self, SIGNAL(:okClicked), self, SLOT(:store_settings)
      connect self, SIGNAL(:applyClicked), self, SLOT(:store_settings)
      connect self, SIGNAL(:defaultClicked), self, SLOT(:read_default_settings)
      enable_button_apply false
    end
    
=begin rdoc
Returns an array containing all the widgets created for the dialog, that is the
widgets created from the data in the third argument of the constructor.
=end
    def widgets
      res = []
      @widgets.each_value{|a| res += a}
      res
    end
    
=begin rdoc
This method reads settings from the option container and displays them in the widgets.
It calls the read_settings method of the option dialog manager and the read_settings
method of each widgets which provide it.
=end
    def read_settings
      @manager.read_settings
      @widgets.values.flatten.each{|w| w.read_settings if w.respond_to? :read_settings}
    end

=begin rdoc
This method takes the values from the dialog widgets and stores them in to option container.
It calls the store_settings method of the option dialog manager and the store_settings
method of each widgets which provide it, then calls the write method of the container
so that the options are written to file.
=end
    def store_settings
      @manager.store_settings
      @widgets.values.flatten.each{|w| w.store_settings if w.respond_to? :store_settings}
      @container.write
    end

=begin rdoc
This method works as read_settings except for the fact that it reads the default
values of the options instad of the values set by the user.
=end
    def read_default_settings
      @manager.read_default_settings
      @widgets.values.flatten.each{|w| w.read_default_settings if w.respond_to? :read_default_settings}
    end

=begin rdoc
Override of <tt>KDE::PageDialog#exec</tt> which makes sure the first page is the current
page and gives focus to the first widget on the page and reads the settings from
the option container.

This is needed because usually the dialog object isn't deleted after having been
closed, so the interface should be updated manually.
=end
    def exec
      read_settings
      if @page_items[0]
        self.current_page = @page_items[0] 
        self.current_page.widget.layout.item_at(0).widget.set_focus
      end
      super
    end
    
=begin rdoc
Override of <tt>KDE::PageDialog#show</tt> which makes sure the first page is the current
page and gives focus to the first widget on the page and reads the settings from
the option container.

This is needed because usually the dialog object isn't deleted after having been
closed, so the interface should be updated manually.
=end
    def show
      read_settings
      self.current_page = @page_items[0]
      self.current_page.widget.layout.item_at(0).widget.set_focus
      super
    end
    
    private
    
=begin rdoc
Method called to create a widget which is specified using a <tt>code</tt> entry
in the third argument to initialize. _code_ is the string containing the code.

It evaluates _code_ in the toplevel binding and returns the resulting object. Derived
classes may override it to change this behaviour (for example, they may want to
evaluate the code in another binding).
=end
    def widget_from_code code
      eval code, TOPLEVEL_BINDING
    end

=begin rdoc
Method called to create a widget which is specified using the <tt>class_obj</tt> entry
in the third argument to initialize. _cls_ is the widget's class.

The widget is created simply calling new on _cls_ (no arguments are passed to it).
Derived classes may want to override it to change this behaviour (for example,
they may want to pass some argument to +new+).
=end
    def widget_from_class cls
      cls.new
    end
    
  end
end
