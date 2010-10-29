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
  
  module Rake

=begin rdoc
Extension which takes care of storing and rebuilding the task list contained in the rake/tasks
project option when one of the rake/rake, rake/rakefile, rake/options or rake/environment
changes.
=end
    class ProjectExtension < Qt::Object
      
      include Extension
      
      signals :tasks_updated
      
=begin rdoc
@param [Ruber::AbstractProject] prj the project associated with the extension
=end
      def initialize prj
        super
        @project = prj
        @project.connect SIGNAL('option_changed(QString, QString)') do |grp, name|
          emit tasks_updated if grp == 'rake' and name == 'tasks'
        end
      end
      
=begin rdoc
The tasks defined in the rakefile associated with the project

This method uses {Rake::Plugin#tasks} to retrieve the list of tasks.

@return [Hash] a hash having the task names as keys and their descriptions as
values

@see Rake::Plugin#tasks
=end
      def tasks
        pars = gather_parameters
        ruby, *ruby_opts = Ruber[:rake].ruby_command_for @project, pars[:dir]
        pars[:ruby_options] = ruby_opts
        Ruber[:rake].tasks ruby, pars[:dir], pars
      end
      
=begin rdoc
Runs a given task in rake
      
The output from rake is displayed in the associated output widget, according to
the settings for the associated project.

Before running rake, all the open documents belonging to the project are saved using
autosave (this means that if the associated project is a {DocumentProject}, only
the corresponding document will be saved).

@param [String, nil] task the name of the task to execute or *nil* to execute the
default task
@raise RakeError if rake reports an error while executing the rakefile
@raise RakefileNotFound if rake can't find the rakefile
@raise Timeout if @rake -T@ doesn't exit after a suitable time
@return [nil]
=end
      def run_rake task
        params = gather_parameters
        files = @project.files
        docs= Ruber[:documents].documents_with_file.select{|d| files.include? d.path}
        return unless Ruber[:autosave].autosave Ruber[:rake], docs, :on_failure => :ask
        ruby, *ruby_opts = Ruber[:rake].ruby_command_for @project, params[:dir]
        params[:ruby_options] = ruby_opts
        params[:task] = task
        Ruber[:rake].run_rake ruby, params[:dir], params
      end
      
=begin rdoc
Updates the @rake/tasks@ project option so that the tasks match those reported
by rake.

@raise {Plugin::RakefileNotFound} if rake reports that no rakefile has been found
@raise {Plugin::Rake::Timeout} if rake doesn't return the list of task in the amount of time set
by the user
@raise {Plugin::Rake::RakeError} if rake aborts with an error

@return [nil]
=end
      def update_tasks
        new_tasks = tasks
        old_tasks = @project[:rake, :tasks]
        new_tasks.each_pair do |k, v| 
          data = [v]
          old_data = old_tasks[k]
          data << old_data[1] if old_data and old_data[1]
          new_tasks[k] = data
        end
        @project[:rake, :tasks] = new_tasks
        @project.save
        emit tasks_updated
        self
      end
    
      private

=begin rdoc
Retrieves the parameters to run rake with from the associated project.

@return [Hash] a hash contains the following entries
 @:rake@: the path of the rake program to use
 @:env@: the environment to pass to rake
 @:options@: the options to pass to rake
 @:dir@: the directory to run rake from
 @:rakefile@: the path of the rakefile to use (relative to the @dir+ entry) or
  *nil* if it is not specified in _prj_. If _prj_ is a {DocumentProject}, this
  entry will always contain the path of the document
=end
      def gather_parameters
        res = {}
        res[:rake] = @project[:rake, :rake].dup
        res[:env] = @project[:rake, :environment].dup
        res[:options] = @project[:rake, :options].dup
        sync_stdout = @project[:rake, :sync_stdout]
        res[:options] << '-E' << '$stdout.sync = true' if sync_stdout
        rakefile = @project[:rake, :rakefile, :abs] rescue @project.document.path
        rakefile = rakefile.dup if rakefile
        if rakefile
          res[:rakefile] = File.basename rakefile
          res[:dir] = File.dirname rakefile
        else res[:dir] = @project.project_directory.dup
        end
        res
      end
      
    end
    
  end
  
end