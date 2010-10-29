require 'rake'

Gem::Specification.new do |s|

  s.instance_variable_set :@desktop_files, ['ruber.desktop']
  s.name = 'ruber'
  s.author = 'Stefano Crocco'
  s.email = 'stefano.crocco@alice.it'
  s.summary = 'A plugin-based Ruby editor for KDE 4 written in Ruby'
  s.description = <<-DESC
  Ruber is a Ruby editor for KDE 4 written in pure ruby, making use of the
  excellent ruby bindings for KDE 4 (korundum).
  
  Ruber is plugin-based, meaning that almost all its functionality is provided
  by plugins. This has two important consequences:
  1) A user can write plugins having availlable all the features availlable to 
  the Ruber developers. In other words, there's not a plugin-specifi API
  2) Users can write plugins which replace some of the core functionality of
  Ruber. For example, a user can create a plugin which replaces the default
  plugin to run ruby programs
  DESC
  s.version = '0.0.1'
  s.required_ruby_version = '>=1.8.7'
  s.requirements << 'KDE 4.5' << 'korundum4'
  s.add_dependency 'facets', '>=2.7'
  s.add_dependency 'dictionary'
  s.add_dependency 'rak'
  s.add_dependency 'outsider'
  s.bindir = 'bin'
  s.executables = 'ruber'
  s.files = FileList['lib/**/*.*', 'plugins/**/*.*', 'spec/**/*', 'data/**/*', 'ruber.desktop', 'outsider_files', 'icons/*.*', 'COPYING', 'INSTALL', 'LICENSE']
end
