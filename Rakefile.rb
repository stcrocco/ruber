require 'rdoc'
require 'yaml'

begin YAML::ENGINE.yamler='syck'
rescue NameError
end

verbose(true)

rule(/_(dlg|widget)\.rb\Z/ => proc{|f| f.sub(/\.rb\Z/,'.ui')}) do |t|
  cmd = "rbuic4 -o #{t.name} #{t.source}"
  sh cmd
end

UI_FILES = Dir.glob('**/*.ui').map{|f| f.sub(/\.ui\Z/, '.rb')}
RB_FILES = Dir.glob('**/*.rb')-UI_FILES

# This is needed because rbuic4 produces KEditListBox::Remove instead of
# KDE::EditListBox::Remove. So we have to correct it by hand
file 'plugins/custom_actions/ui/config_widget.rb' => 'plugins/custom_actions/ui/config_widget.ui' do |f|
  cmd = "rbuic4 -o #{f.name} #{f.prerequisites[0]}"
  sh cmd
  contents = File.read f.name
  contents.sub! 'KEditListBox', 'KDE::EditListBox'
  File.open(f.name, 'w'){|of| of.write contents}
end

desc 'Creates all the files needed to run Ruber'
file :ruber => UI_FILES

task :default => :ruber

require 'rdoc/task'
Rake::RDocTask.new do |t|
  output_dir= File.expand_path(ENV['OUTPUT_DIR']) rescue 'rdoc'
  t.rdoc_dir = output_dir
  t.rdoc_files.include( 'lib/ruber/**/*.rb', 'plugins/**/*.rb', 'TODO', 'INSTALL', 'LICENSE')
  t.options  << '-a' << '-S' << '-w' << '2' << '-x' << 'lib/ruber/ui' << '-x' << 'plugins/.*/ui'
  t.title = "Ruber"
  rdoc_warning = <<-EOS
WARNING: the documentation for this project is written for YARD (http://www.yardoc.org)
         If you use rdoc, you'll obtain documentation which is incomplete and hard to read.
         If possible, consider installing and using YARD instead
  EOS
  t.before_running_rdoc {puts rdoc_warning}
end

desc 'Removes documentation and intermediate files'
task :clean do
  sh "rm -f #{UI_FILES.join(' ')}"
  rm_rf 'doc'
  rm_rf 'rdoc'
end

begin 
  begin
    require 'rspec/core/rake_task'
    RSpec::Core::RakeTask.new do |t|
      t.fail_on_error = false
    end
  rescue LoadError
    require 'rspec/rake/spectask'
    rspec_rake_task_cls.new do |t|
      t.fail_on_error = false
      t.libs << 'lib'
      t.spec_opts += %w[-L m -R]
    end
  end
rescue LoadError
end

begin 
  require 'yard'
  desc 'generates the documentation using YARD'
  cache = ENV['YARD_NO_CACHE'] ? '' : '-c'
  YARD::Rake::YardocTask.new(:doc) do |t|
    output_dir= File.expand_path(ENV['OUTPUT_DIR']) rescue 'doc'
    t.files   = ['lib/**/*.rb',  'lib/ruber/**/*.rb', 'plugins/**/*.rb', '-', 'TODO', 'manual/**/*', 'INSTALL', 'CHANGES', 'LICENSE']
    t.options = ['-r', 'doc/_index.html', cache, '--protected', '--private', '--backtrace', '-e', './yard/extensions', '--title', 'Ruber API', '--private', '-o', output_dir, '-m', 'textile', '--exclude', '/ui/[\w\d]+\.rb$']
  end
rescue LoadError
end

desc 'Builds the ruber gem'
task :gem => [:ruber] do
  require 'rubygems'
  spec = Gem::Specification.load 'ruber.gemspec'
  builder = Gem::Builder.new(spec)
  builder.build
end
