require './spec/framework'
require './spec/common'
require 'plugins/auto_end/auto_end'

describe Ruber::AutoEnd::Extension do
  
  before do
    Ruber[:components].load_plugin 'plugins/auto_end/'
  end
  
  after do
    Ruber[:components].unload_plugin :auto_end
  end
  
  it 'includes the Extension module' do
    Ruber::AutoEnd::Extension.should include(Ruber::Extension)
  end
  
end