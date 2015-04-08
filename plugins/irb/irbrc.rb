#! /usr/bin/ruby

names = [File.join(ENV['HOME'], '.irbrc'), '.irbrc', 'irb.rc', '_irbrc', '$irbrc', '/etc/irbrc'].map do |f|
  File.expand_path(f)
end

irbrc = names.find{|f| File.file? f}

load irbrc if irbrc

names = [File.join(ENV['HOME'], '.quirbrc'), '.quirbrc', 'quirb.rc', '_quirbrc', '$quirbrc', '/etc/quirbrc'].map do |f|
  File.expand_path(f)
end

quirbrc = names.find{|f| File.file? f}

load quirbrc if quirbrc

module IRB
  class Context
    
    alias_method :initialize_before_quirb, :initialize
    
    def initialize *args, &blk
      initialize_before_quirb *args, &blk
      self.prompt_mode = :QUIRB if IRB.conf[:PROMPT][:QUIRB]
    end
    
  end
end