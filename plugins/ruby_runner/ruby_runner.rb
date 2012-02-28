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

require 'shellwords'

require 'ruber/plugin_specification_reader'
require 'ruber/external_program_plugin'
require_relative 'ui/ruby_runnner_plugin_option_widget'

require 'ruby_runner/project_widget'
require 'ruby_runner/config_widget'

module Ruber
  
=begin rdoc
Plugin providing support for running ruby programs.

It provides:
* an option for the user to choose which ruby interpreter to use (both at global
and project level)
* a menu entry to temporarily choose another interpreter
* a ready to use widget where the user can enter the options to pass to ruby
* a class from which plugins which need to run a ruby program may inherit

@api feature ruby_runner
@plugin RubyInterpretersPlugin
@api_class Ruber::RubyRunner::RubyOptionsWidget
@api_class Ruber::RubyRunner::RubyRunnerPluginInternal Ruber::RubyRunner::RubyRunnerPlugin
@config_option ruby interpreters [<String>] a list of the interpreters to display
in the menu
@config_option ruby ruby [String] the path of the default interpreter to use
@config_option ruby ruby_options [<String>] a list of the options to pass to the
ruby interpreter
@project_option ruby ruby [String] the path of the interpreter to use for the project
=end
  module RubyRunner
    
=begin rdoc
Widget to use to set the @ruby_options@ setting.

It is made by a KDE::LineEdit and the corresponding Qt::Label.
It already provides the signal property to be used by SettingsDialogContainer (set
to <tt>text_changed(QString)</tt>).

Plugin developers should only need to put this widget inside their project widget
and give it the appropriate name (usually <tt>_grp__ruby_options</tt>, where _grp_
is the group specified in RubyRunnerPlugin.new)

If something fancier is needed, the underlying label and line edit widgets can
be accessed using the @label_widget@ and @text_widget@ methods.

@todo Put this class inside the namespace after it's been changed from Ruber (as rbuic
  puts all classes starting with K in the KDE namespace)
=end
    class RubyOptionsWidget < Ruber::ProjectConfigWidget
  
=begin rdoc
Signal emitted whenever the text inside the line edit changes.

@param [String] text the new content of the line edit
=end
  signals 'text_changed(QString)'
  
=begin rdoc
Creates a new instance

@param [Qt::Widget] parent the parent widget
=end
  def initialize parent = nil
    super
    @ui = Ui::PluginOptionWidget.new
    @ui.setupUi self
    connect @ui.text, SIGNAL('textChanged(QString)'), self, SIGNAL('text_changed(QString)')
  end
  
=begin rdoc
The label widget.
  
This is useful, for example, if you don't like the default label.

@return [Qt::Label] the label widget
=end
  def label_widget
    @ui.label
  end

=begin rdoc
The line edit widget widget.

In most cases, you shouldn't need to use this

@return [KDE::LineEdit] the line edit widget

=end
  def text_widget
    @ui.text
  end
  
=begin rdoc
Sets the text in the line edit
  
@param [<String>] val an array of strings, with each string being a shell token
=end
  def text= val
    @ui.text.text = val.join ' '
  end
  
=begin rdoc
Converts the contents of the line edit to an array
  
@return [<String>] an array of shell tokens
=end
  def text
    Shellwords.split_with_quotes @ui.text.text
  end

end
    
=begin rdoc
The plugin object for the @ruby_runner@ feature.

This class provides a way to set the ruby interpreter to use, allowing to override
the interpreter set globally or for the current project. This choice can be made
programmaticaly or by the user, using the "Interpreter" submenu added by this class
to the "Ruby" menu.

The interpreters which can be chosen are configured globally by the user.

@api_method #chosen_interpreter
@api_method #choose_interpreter
=end
    class RubyInterpretersPlugin < GuiPlugin
      
=begin rdoc
Creates a new RubyInterpretersPlugin.
@param [Ruber::PluginSpecification] psf the plugin specification object describing
the plugin
=end
      def initialize psf
        silently do
          Object.const_set :RubyOptionsWidget, RubyOptionsWidget
        end
        super
        @default_interpreter_action = action_collection.action('ruby_runner-configured_interpreter')
        @interpreter_actions = []
        @interpreters_group = Qt::ActionGroup.new self
        @interpreters_group.add_action @default_interpreter_action
        @default_interpreter_action.checked = true
        fill_interpreters_menu
      end
      
=begin rdoc
The path of the interpreter chosen by the user
@return [String,nil] a string with the path of the interpreter to use or *nil* if
the default interpreter should be used
=end
      def chosen_interpreter
        checked = @interpreters_group.checked_action
        checked.same?( @default_interpreter_action) ? nil : checked.object_name
      end
      
=begin rdoc
Sets the ruby interpreter to use.

Calling this method will check one of the entries of the "Interpreters" submenu

@param [String, nil] arg the interpreter to use. If *nil*, the default interpreter
will be used. If it is a string, it is the path of the interpreter to use. If this
doesn't correspond to one of the entries in the "Interpreters" submenu, nothing
is done.
@return [String,nil] the chosen interpreter or *nil* if the default one should
be used.
=end
      def choose_interpreter arg
        if arg.nil? then @default_interpreter_action.checked = true
        else 
          action = @interpreters_group.actions.find{|a| a.object_name == arg}
          action.checked = true if action
        end
        chosen_interpreter
      end
      
=begin rdoc
Override of {PluginLike#unload}

Besides doing the same as the base class method, it also removes the @Ruber::RubyRunner::RubyRunnerPlugin@
constant, so that other plugins may reimplement it using another base class.
@return [nil]
=end
      def unload
        Ruber::RubyRunner.send :remove_const, :RubyRunnerPlugin
        super
      end

      
      private
      
=begin rdoc
Finds the ruby interpreters availlable on the system.

The interpreters are searched using the @which -a@ command (this means that only
interpreters in the @PATH@ environment variable will be found). The names which
are tried are: @ruby@, @ruby19@, @ruby18@, @ruby1.9@ and @ruby1.8@.
@return [<String>] a list with the paths of the ruby interpreters availlable on
the system
=end
      def find_interpreters
        look_for = %w[ruby ruby19 ruby18 ruby1.9 ruby1.8]
        look_for.map{|r| interpreters = `which #{r} 2> /dev/null`.split_lines}.flatten
      end
      
=begin rdoc
Clears and refills the "Interpreters" submenu

The list of availlable interpreters is read from the @ruby/interpreters@ config
option

The selection is preserved if possible (that is, if an interpreter with the same
path as the previously selected one still exists). If this isn't possible, the
default entry is selected.

@return *nil*
=end
      def fill_interpreters_menu
        @gui.unplug_action_list 'ruby_runner-interpreters'
        old_checked = @interpreters_group.checked_action.object_name
        @interpreter_actions.each{|a| @interpreters_group.remove_action a}
        @interpreter_actions.clear
        @interpreter_actions = Ruber[:config][:ruby, :interpreters].map do |i|
          a = KDE::ToggleAction.new i, action_collection
          a.object_name = i
          @interpreters_group.add_action a
          a.checked = true if i == old_checked
          a
        end
        @gui.plug_action_list 'ruby_runner-interpreters', @interpreter_actions
        unless @interpreters_group.checked_action
          action_collection.action('ruby_runner-configured_interpreter').checked = true
        end
        nil
      end

    end
      
=begin
Abstract class plugins which need to run a ruby program can derive from.

It provides some convenience methods to retrieve an option for a target (which
can be either a global project, a document or a file) so that, if the option isn't
found in the target itself, a global value is used. It also provide methods to
retrieve the path of the ruby interpreter to use for a given target, taking into
account the choice made by the user in the "Interpreters" submenu.

Lastly, this class adds a project option called @ruby_options@ to the PS for the
plugin.

*Note:* classes which want to derive from this class should derive from
{Ruber::RubyRunner::RubyRunnerPlugin} rather than from this.

@api_method #option_for
@api_method #interpreter_for
@api_method #ruby_command_for
=end
    class RubyRunnerPlugin < ExternalProgramPlugin

=begin rdoc
Creates a new instance.
      
Before passing it to RunnerPlugin's constructor, it adds the @ruby_options@
project option to the plugin specification object, in the given group.

@param [PluginSpecification] pso the plugin specification object associated with
the plugin
@param [String,Symbol] group the group the @ruby_options@ option should be added
to. If an option called @ruby_options@ already exists in the group, it won't be
overwritten
@param [Hash] rules the rules to apply to the @ruby_options@ option
@param [Integer,nil] order has the same meaning as in the PSF and applies to the
@param line_buffered [Boolean] as in {ExternalProgramPlugin#initialize}

@option rules [<Symbol>] scope ([:global]) has the same meaning as in the PSF,
but cannot contain the @:all@ entry and *must* be an array.
@option rules [<String>] mimetypes ([]) has the same meaning as in the PSF, but
must be an array, even if it only contains one entry
@option rules [<String>] file_extension ([]) has the same meaning as in the PSF, but
must be an array, even if it only contains one entry
=end
      def initialize pso, group, rules = {}, order = nil, line_buffered = true
        group = group.to_sym
        @group = group
        default_rules = {:scope => [:global], :file_extension => [], :mimetype => [], :place => [:local]}
        rules = default_rules.merge rules
        ruby_options_data = {
          :name => :ruby_options,
          :group => group,
          :default => Ruber[:config][:ruby, :ruby_options],
          :scope => rules[:scope],
          :mimetype => rules[:mimetype],
          :file_extension => rules[:file_extension],
          :order => order,
          :place => rules[:place]
        }
        pso.project_options[[group, :ruby_options]] ||= PluginSpecificationReader::Option.new ruby_options_data
        super pso, line_buffered
      end
      
=begin rdoc
Searches for an option for the given target.

The behaviour of this method depends on what _target_ is:
* if it is an {AbstractProject}, the option is searched in it
* if it is a {Document} or a string representing a file name and belongins to
the current project, the option is searched in the current project
* if it is a {Document} but doesn't belong to the current project (or no current
project exists), the option is searched in the document's own project
* if it is a string representing a file which doesn't belong to the current project
(or there's no current project) the option is looked for in the global configuration
object.

In all cases, if the search fails, the option is looked up in the global configuration
object.

@param [AbstractProject, Document, String, nil] target the object to look up the
option for. If *nil*, the option will directly be looked up in the global configuration
object
@param [Symbol] group the group the option belongs to
@param [Symbol] name the name of the option
@param [Boolean] ignore_project if *true* the option won't be looked for in the
current project, even if _target_ is a {Document} or the name of a file belonging
to it
@param [Boolean] abs it has the same meaning as in {SettingsContainer#[]}
@raise [IndexError] if the option can't be found
=end
      def option_for target, group, name, ignore_project = false, abs = false
        cont = []
        case target
        when AbstractProject then cont << target
        when Document
          cont << (ignore_project ? (target.own_project) : target.project)
        when String
          if !ignore_project and Ruber[:world].projects.project_for_file target
            cont << Ruber[:world].active_project
          end
        end
        cont << Ruber[:config]
        abs = :abs if abs
        cont.each_with_index do |c, i|
          begin return c[group, name, abs]
          rescue IndexError
            raise if i == cont.size - 1
          end
        end
      end
      
=begin rdoc
Returns the name of the ruby interpreter to use for the given target

It is specialized version of {#option_for} which looks for the @ruby/ruby@ option
and takes into account the selected entry in the "Interpreters" submenu.

@param [Boolean] ignore_project as in {#option_for}
@return [String] the path of the interpreter to use
=end
      def interpreter_for target, ignore_project = false
        Ruber[:ruby_interpreters].chosen_interpreter || 
            option_for(target, :ruby, :ruby, ignore_project)
      end
      
=begin rdoc
Returns the command to use to execute ruby according to the appropriate options
for the given target.

To build the command, it uses the @ruby/ruby@ and the @ruby_options@ (in the group
specified in the constructor).

@param [AbstractProject, Document, String, nil] target as in {#option_for}
@param [String] dir the directory to run ruby from (it will be passed to ruby using
the @-C@ flag)
@param [Hash] opts some options to fine tune the behaviour of the method

@option opts [Boolean] default_interpreter (false) if *true*, ignores the choice
made by the user in the "Interpreters" submenu
@option opts [Boolean] ignore_project (false) as in {#option_for}
@option opts [String] ruby (nil) if given, use this instead of the content of the @ruby/ruby@
option as default interpreter
@option opts [<String>] ruby_options (nil) if given, use this instead of the content
of the @ruby_options@ option.
@return [<String>] an array whose first entry is the name of the ruby interpreter
to use and whose other elements are the options to pass to the interpreter.
=end
      def ruby_command_for target, dir, opts = {}
        ruby =  Ruber[:ruby_interpreters].chosen_interpreter
        if !ruby or opts[:default_interpreter]
          ruby = if opts[:ruby] then opts[:ruby]
          else option_for target, :ruby, :ruby, opts[:ignore_project]
          end
        end
        ruby_options = opts[:ruby_options]
        ruby_options ||= option_for target, @group, :ruby_options, opts[:ignore_project]
        [ruby] + ruby_options + ['-C', dir] 
      end
      
    end
    
  end
  
end
