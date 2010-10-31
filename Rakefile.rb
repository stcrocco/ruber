require 'rdoc'

verbose(true)

rule(/_(dlg|widget)\.rb\Z/ => proc{|f| f.sub(/\.rb\Z/,'.ui')}) do |t|
  cmd = "rbuic4 -o #{t.name} #{t.source}"
  sh cmd
end

UI_FILES = Dir.glob('**/*.ui').map{|f| f.sub(/\.ui\Z/, '.rb')}
RB_FILES = Dir.glob('**/*.rb')-UI_FILES

desc 'Creates all the files needed to run Ruber'
file :ruber => UI_FILES 

task :default => :ruber

rdoc_warning = <<-EOS
WARNING: the documentation for this project is written for YARD (http://www.yardoc.org)
         If you use rdoc, you'll obtain documentation which is incomplete and hard to read.
         If possible, consider installing and using YARD instead
EOS

rake_rdoc = begin 
  version = RDoc::VERSION
  version.split('.')[1].to_i < 3
rescue NameError then true
end
if rake_rdoc
  require 'rake/rdoctask'
  Rake::RDocTask.new do |t|
    output_dir= File.expand_path(ENV['OUTPUT_DIR']) rescue 'rdoc'
    puts rdoc_warning
    t.rdoc_dir = output_dir
    t.rdoc_files.include( 'lib/ruber/**/*.rb', 'plugins/**/*.rb', 'TODO', 'INSTALL', 'LICENSE')
    t.options  << '-a' << '-S' << '-w' << '2' << '-x' << 'lib/ruber/ui' << '-x' << 'plugins/.*/ui'
#     << '-A' <<
#   'data_reader=R' << '-A' << 'data_writer=W' << '-A' << 'data_accessor=RW' << '-x' << 
    t.title = "Ruber"
  end
  
else
  require 'rdoc/rdoc'
  
  desc 'Generates the documentation using RDoc'
  task :rdoc do |t|
    puts rdoc_warning
    output_dir= File.expand_path(ENV['OUTPUT_DIR']) rescue 'rdoc'
    files = Rake::FileList['lib/ruber/**/*.rb','plugins/**/*.rb', 'TODO', 'INSTALL', 'LICENSE']
    options = %W[-o #{output_dir} -w 2 -x lib/ruber/ui -x plugins/.*/ui --title Ruber]
    args =  options + files
    RDoc::RDoc.new.document( args)
    self
  end
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
    t.files   = ['lib/**/*.rb',  'lib/ruber/**/*.rb', 'plugins/**/*.rb', '-', 'TODO', 'manual/**/*', 'INSTALL']
    t.options = [cache, '--protected', '--private', '--backtrace', '-e', 'yard/extensions', '--title', 'Ruber API', '--private', '-o', output_dir, '-m', 'textile', '--exclude', '/ui/[\w\d]+\.rb$']
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