module Torikago
  # A host-owned Rack endpoint that forwards requests to a registered module
  # without exposing the module's Rails::Engine or controller constants in the
  # main Box.
  class RackEndpoint
    def initialize(module_name, registry: nil)
      @module_name = module_name.to_sym
      @registry = registry
    end

    def call(env)
      registry.resolve(module_name).call(env)
    end

    private

    attr_reader :module_name

    def registry
      @registry || Torikago.registry
    end
  end
end
