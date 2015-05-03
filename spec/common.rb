require 'fileutils'
require 'yaml'

require 'flexmock/argument_types'
require 'korundum4'
require 'kio'
require 'ostruct'

require 'ruber/qt_sugar'
require 'ruber/kde_sugar'
require 'ruber/ktexteditor_sugar'
require 'ruber/utils'

#Distinguish between rspec 1.* and later
RSPEC = begin require 'rspec/core'
  RSpec
rescue LoadError
  Spec
end
(RSPEC.name == 'RSpec' ? RSPEC : RSPEC::Runner).configure do |config|
  config.mock_with :flexmock
  # Don't check for versions, as newer versions of 2.x seem to allow this
  begin config.expect_with(:rspec){|c| c.syntax = [:should, :expect]}
  rescue
  end
end

OS = OpenStruct

=begin rdoc
 [
  [dir1, [dir2, [fi1e1, file2, [dir3, file3] ]],
  [dir4, file4]
 ]
 produces
 dir1
  dir2
    dir3
      file3
    file1
    file2
  dir4
    file4
=end
def make_dir_tree contents, base = '/tmp/', file_contents = {}
  letters = ('A'..'Z').to_a + ('a'..'z').to_a
  temp_dir = File.join base, 10.times.map{letters[rand(52)]}.join
  dirs = []
  files = []
  contents = YAML.load(contents) if contents.is_a? String
  mktree = lambda do |dir, current|
    if current.is_a? Array
      current_full = File.join(dir, current[0])
      dirs << current_full
      current[1..-1].each do |c|
        mktree.call current_full, c
      end
    else files << File.join(dir, current)
    end
  end
  contents.each {|d| mktree.call temp_dir, d}
  FileUtils.mkdir temp_dir
  file_contents = file_contents.map{|k, v| [File.join( temp_dir, k), v]}.to_h
  dirs.each{|d| FileUtils.mkdir d}
  files.each do |f|
    if file_contents[f] then File.open(f, 'w'){|out| out.write file_contents[f]}
    else `touch #{f}`
    end
  end
  temp_dir
end

=begin rdoc
Returns a random string of length _length_ made of characters from 'a' to 'z'
=end
def random_string length = 5
  ('a'..'z').to_a.sample(length).join
end

if RUBY_VERSION =~ /9/
  RSPEC::Matchers.define :include do |it|
    match do |cont|
      cont.include? it
    end
  end
end

RSPEC::Matchers.define :have_entries do |hash|

  match do |obj|
    if obj.respond_to? :[]
      hash.each_pair do |k, v|
         break false unless obj[k] == v
      end
    else
      hash.each_pair do |k, v|
        break false unless obj.send(k) == v
      end
    end
  end

end

RSPEC::Matchers.define :be_the_same_as do |exp|
  match{|obj| obj.equal? exp}
end

data = KDE::AboutData.new "test", "", KDE::ki18n("test"), "0.0.0"
KDE::CmdLineArgs.init [], data
opts = KDE::CmdLineOptions.new
opts.add("+[FILES]", KDE.ki18n("Open FILES. Files with extension .krprj will "\
                               "be opened as projects. Only the more recent "\
                              "project will be used"))
KDE::CmdLineArgs.add_cmd_line_options opts
if defined? init_ruber_core then init_ruber_core
else KDE::Application.new
end
at_exit{Qt::Internal.application_terminated = true}
GC.disable
