def init_ruber_core
  require './lib/ruber/component_manager'
  manager = Ruber::ComponentManager.new
  manager.load_component 'application'
end