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

require_relative 'ui/autosave_config_widget'

=begin rdoc
Subclass of @Qt::ListView@ which emits a signal whenever the model changes
@todo Put under the correct namespace
=end
class AutosavePluginListView < Qt::ListView

=begin rdoc
Signal emitted whenever some of the indexes in the model change
=end
  signals :items_changed
  
=begin rdoc
Override of @Qt::ListView#model=@
  
Besides calling *super*, it also connects to the model's @dataChanged@ signal to
the view's {#items_changed} signal (and disconnects the old model if necessary).
=end
  def model= mod
    if model
      model.disconnect SIGNAL('dataChanged(QModelIndex, QModelIndex)'), self, SIGNAL(:items_changed)
    end
    super
    if model
      connect model, SIGNAL('dataChanged(QModelIndex, QModelIndex)'), self, SIGNAL(:items_changed)
    end
  end
  
end

module Ruber

=begin rdoc
Plugin providing a common interface to autosaving documents.

Plugins which want to autosave some files whenever something happen may register
with this plugin then call its {AutosavePlugin#autosave autosave} method whenever
they want to autosave files.

The user can choose whether they want autosave globally enabled an turn it off
plugin-wise if they want. If autosave is disabled for a given plugin (either because
it's disabled globally or only for that plugin), the {AutosavePlugin#autosave autosave}
method will behave as if the files were successfully saved, but, of course, will
not actually save them.

<b>Note:</b> in all the documentation of this class, the method parameter _plug_
can be either a plugin or its name.

@api feature autosave
@plugin AutosavePlugin
=end
  module Autosave

=begin rdoc
Plugin class for the @autosave@ plugin.

@api_method #autosave
@api_method #register_plugin
@api_method #remove_plugin
@api_method #registered_plugins
=end
    class AutosavePlugin < Plugin

=begin rdoc
@return [Hash] a hash which has the names of registered plugins as keys and whether
autosaving is enabled for them as keys
=end
      attr_reader :registered_plugins
      
=begin rdoc
Creates a new instance

@param [PluginSpecification] the plugin specification associated with the plugin
=end
      def initialize pdf
        @registered_plugins = {}
        @enabled = true
        @settings = {}
        super
        Ruber[:components].connect SIGNAL('unloading_component(QObject*)') do |c|
          @registered_plugins.delete c.component_name
        end
      end
      
=begin rdoc
Makes another plugin known to @Autosave@. 
      
If the configuration file already has an entry for the plugin _plug_ in the
@autosave/plugins@ setting, autosaving
will be enabled or not basing on that value. If there's not such an entry,
then autosaving will be enabled if _default_ is *true* and disabled otherwise.

<b>Note:</b> you have to register a plugin before calling the {#autosave} method
 for it.

@param [PluginLike, Symbol] plug the plugin to register or its name
@param [Boolean] default whether or not autosaving should be enabled for _plug_
if the configuration file doesn't have an entry for it
=end
      def register_plugin plug, default = true
        plug = plug.plugin_name if plug.is_a? PluginLike
        val = @settings.fetch plug, default
        @registered_plugins[plug] = val
        val
      end
      
=begin rdoc
Removes a plugin from the list of registered plugins.
      
Usually, there's no need to use this method, as registered plugins are automatically
removed whenever they're unloaded.

<b>Note:</b> you can't call the {#autosave} method for a plugin which has been
removed using this method.

@param [PluginLike, Symbol] plug the name of the plugin to remove from the autosave 
list or its name
=end
      def remove_plugin plug
        plug = plug.plugin_name if plug.is_a? PluginLike
        @registered_plugins.delete plug
      end
      
=begin rdoc
Loads the settings

@return [void]
=end
      def load_settings
        @enabled = Ruber[:config][:autosave, :enable]
        @settings = Ruber[:config][:autosave, :plugins]
        nil
      end
      
=begin rdoc
Autosaves the given documents or files.

This is the main method of this class. Whenever a plugin wants some documents to be autosaved,
it calls this method passing itself as first argument and a list of the documents
to save (or one of the special symbols listed below) as second argument and, optionally
some options or a block.

If autosaving is enabled both globally and for the plugin, an attempt will
be made to save all the specified documents. If one or more documents can't be saved, the
behaviour depends on the third and fourth argument. If autosaving is disabled,
either globally or for the given plugin, this method does nothing.

@param [PluginLike, Symbol] plug the plugin requesting to autosave the documents
or its name
@param [<Document>, Symbol] what either an array with the documents to autosave
or one of the symbols listed below.

* @:open_documents@: autosave all the open documents (including those which aren't
  associated with a file)
  
* @:documents_with_file@: autosave all the open documents which are associated with
a file

* @:project_files@: autosave all the open documents corresponding to a file belonging
to the current project. Note that using this value when there's no active global
project leads to undefined behaviour.

@param [Hash] opts a hash which fine tunes the behaviour in case one of the specified
documents can't be saved.

@param [Proc] blk a block which will be called if some of the documents couldn't
be saved. If given, it will be given an array containing the unsaved documents as
argument.

@option opts [Boolean] :stop_on_failure (false) whether to stop saving documents
as soon as one fails to save. By default, this method attempts to save all given
documents, regardless of whether saving the other documents was successful or not.
@option opts [Symbol] :on_failure (nil) what to do if some documents can't be saved
(this option will be ignored if a block has been given).
It can have the following values:
      
* @:warn@: an information message box describing the error is displayed

* @:ask@: a Yes/No message box describing he error is displayed. The return value
of the method depends on the choice made by the user

@option opts [String] message nil custom text to add to the default message in
the message box displayed if the @:on_failure@ option is @:warn@ or @:ask@. If the
message box is a Yes/No one, most likely you'll need to specify this option to 
describe what will happen if the user chooses Yes and what happens if he chooses
No.

@return [Boolean] *true* if all the documents were saved successfully or if autosaving
was disabled either globally or for the specific plugin. If some documents couldn't
be saved, this method returns *false*, unless

* a  block was given. In this case, the return value of the block is returned

* the @:on_failure@ option is @:ask@. In this case, the returned value is *true*
if the user chose Yes in the message box and *false* otherwise.
=end
      def autosave plug, what, opts = {}, &blk
        plug = plug.plugin_name if plug.is_a? PluginLike
        return true unless @enabled and @registered_plugins[plug]
        if what.is_a? Array then save_files what, opts, blk
        else send "save_#{what}", opts, blk
        end
      end
      
      private
      
=begin rdoc
Attempts to save all the open documents corresponding to a file belonging to the current project.

This method should only be called if autosaving is enabled because it doesn't take
into account the enabled option and always attempt to save the documents.

@param [Hash] opts see {#autosave}
@param [Proc] blk see {#autosave}
@return [Boolean] see {#autosave}
=end
      def save_project_files opts, blk
        docs = Ruber[:docs].documents_with_file
        prj_files = Ruber[:projects].current.project_files.abs
        docs = docs.select{|d| prj_files.include? d.path}
        save_files docs, opts, blk
      end
      
=begin rdoc
Attempts to save all the open documents.

This method should only be called if autosaving is enabled because it doesn't take
into account the enabled option and always attempt to save the documents.

@param [Hash] opts see {#autosave}
@param [Proc] blk see {#autosave}
@return [Boolean] see {#autosave}
=end
      def save_open_documents opts, blk
        save_files Ruber[:docs].documents, opts, blk
      end
      
=begin rdoc
Attempts to save all the open documents corresponding to a file. 

This method should only be called if autosaving is enabled because it doesn't take
into account the enabled option and always attempt to save the documents.

@param [Hash] opts see {#autosave}
@param [Proc] blk see {#autosave}
@return [Boolean] see {#autosave}
=end
      def save_documents_with_file opts, blk
        save_files Ruber[:docs].documents_with_file, opts, blk
      end
      
=begin rdoc
Attempts to save the documents contained in the array _docs_. 

This method should only be called if autosaving is enabled because it doesn't take
into account the enabled option and always attempt to save the documents.

@param [<Document>] docs an array with the documents to save
@param [Hash] opts see {#autosave}
@param [Proc] blk see {#autosave}
@return [Boolean] see {#autosave}
=end
      def save_files docs, opts, blk
        unsaved = []
        docs.each_with_index do |d, i|
          unless save_doc d
            unsaved << d
            if opts[:stop_on_failure]
              unsaved += docs[(i+1)..-1]
              break
            end
          end
        end
        msg = <<-EOS
The following documents couldn't be saved:
#{
  unsaved.map{|d| d.path.empty? ? d.document_name : d.path}
}
        EOS
        if unsaved.empty? then return true
        elsif blk then return blk.call unsaved
        else
          case opts[:on_failure]
          when :warn
            msg << "\n#{opts[:message]}" if opts[:message]
            KDE::MessageBox.sorry Ruber[:main_window], msg
          when :ask
            msg << "\n#{opts[:message]||'Do you want to go on?'}"
            ans = KDE::MessageBox.question_yes_no Ruber[:main_window], msg
            return true if ans == KDE::MessageBox::Yes
          end
        end
        false
      end
      
      def load_settings
        super
        @remote_files_policy = Ruber[:config][:autosave, :remote_files]
      end
      
      private
      
=begin rdoc
Attempts to save a document

If the document is associated with a remote file, the behaviour will change depending
on the value of the @autosave/remote_files@ settings:
* if it's @:skip@ then nothing will be done
* if it's @:ignore@ then an attempt to save the document will be done, but any failures
  will be ignored
* if it's @:normal@ then the behaviour will be the same as for a local file

@param [Document] doc the document to save
@return [Boolean] *true* if the document was saved successfully and *false* otherwise.
  in case of a remote document, it will always return *true* except when the
  @autosave/remote_files@ option is set to @:normal@
=end
      def save_doc doc
        if doc.url.local_file? or doc.url.relative? then doc.save
        else
          case @remote_files_policy
          when :skip then true
          when :ignore
            doc.save
            true
          else doc.save
          end
        end
      end
      
    end
    
=begin rdoc
The configuration widget for the Autosave plugin
=end
    class ConfigWidget < Qt::Widget
      
=begin rdoc
Associations between remote files behaviour and entries in the Remote files widget
=end
      REMOTE_FILES_MODE = {:normal => 0, :skip => 1, :ignore => 2}

=begin rdoc
Creates a new instance

@param [Qt::Widget, nil] the parent widget
=end
      def initialize parent = nil
        super
        @ui = Ui::AutosaveConfigWidget.new
        @ui.setupUi self
        m = Qt::StandardItemModel.new @ui._autosave__plugins
        @ui._autosave__plugins.model = m
        fill_plugin_list
        @ui._autosave__plugins.enabled = false
        @ui._autosave__enable.connect(SIGNAL('toggled(bool)')) do |b|
          @ui._autosave__plugins.enabled = b
        end
      end
      
=begin rdoc
Changes the status of the Plugins widget according to the given value

@param [Hash] val the keys are the names of the plugin, while the values tell whether
autosave should be enabled or not for the given plugin. Any entries corresponding
to plugins without a corresponding entry in the wigdet are added

@return [void]
=end
      def plugins= val
        mod = @ui._autosave__plugins.model
        val.each_pair do |k, v|
          name = v.to_s
          it = mod.find{|i| i.data.to_string == name}
          unless it
            it = Qt::StandardItem.new k.to_s
            it.data = Qt::Variant.new k.to_s
            it.flags = Qt::ItemIsEnabled|Qt::ItemIsSelectable|Qt::ItemIsUserCheckable
            mod.append_row it
          end
          it.checked = v
        end
      end
      
=begin rdoc
The plugins for which autsave is enabled and those for which it's disabled

@return [Hash] a hash whose keys are the plugin names and whose values tell whether
autosave is enabled or not for a given plugin
=end
      def plugins
        mod = @ui._autosave__plugins.model
        mod.inject({}) do |res, it|
          res[it.data.to_string.to_sym] = it.checked?
          res
        end
      end
      
      private
      
=begin rdoc
Fills the list view with the registered plugins

@return [nil]
=end
      def fill_plugin_list
        m = @ui._autosave__plugins.model
        Ruber[:autosave].registered_plugins.each_pair do |pl, val|
          obj = Ruber[pl.to_sym]
          it = Qt::StandardItem.new obj.plugin_description.about.human_name
          it.data = Qt::Variant.new(pl.to_s)
          it.flags = Qt::ItemIsEnabled|Qt::ItemIsSelectable|Qt::ItemIsUserCheckable
          it.checked = val
          m.append_row it
        end
        nil
      end
      
=begin rdoc
Selects the appropriate entry from the remote file combo box

@param [Symbol] val the bheaviour with respect to remote files. It can be one of
  @:normal@, @:skip@ or @:ignore@
@return [nil]
=end
      def remote_files= val
        mode = 
        @ui._autosave__remote_files.current_index = REMOTE_FILES_MODE[val]
        nil
      end
      
=begin rdoc
@return [Symbol] the symbol associated with the entry selected in the remote files
  widget according to {REMOTE_FILES_MODE}
=end
      def remote_files
        REMOTE_FILES_MODE.invert[@ui._autosave__remote_files.current_index]
      end
      
    end
    
  end
  
end