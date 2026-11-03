module Torikago
  # A host-owned Rack-compatible route endpoint that dispatches directly to a
  # controller class loaded inside a registered module runtime. It is not Rack
  # middleware. The host router never resolves the controller constant.
  # Deprecated: use a module-owned Rails::Engine and RackEndpoint for HTTP routes.
  class ControllerEndpoint
    def initialize(module_name, controller_name, action_name, registry: nil)
      @module_name = module_name.to_sym
      @controller_name = controller_name.to_s
      @action_name = action_name.to_sym
      @registry = registry
      warn "[DEPRECATION] Torikago.action and Torikago::ControllerEndpoint are deprecated. " \
           "Define HTTP routes in a module-owned Rails::Engine, register it with rails_engine: true, " \
           "and mount Torikago::RackEndpoint instead. Gateway-only modules do not require Rails::Engine."
    end

    def call(env)
      registry.resolve(module_name).dispatch_controller(
        env,
        controller_name: controller_name,
        action_name: action_name
      )
    end

    private

    attr_reader :action_name, :controller_name, :module_name

    def registry
      @registry || Torikago.registry
    end
  end
end
