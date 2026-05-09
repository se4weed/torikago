module Torikago
  # Lazily builds one EngineContainer per registered module and reuses it for
  # subsequent Gateway calls.
  class Registry
    def initialize(configuration:, &container_factory)
      @configuration = configuration
      @containers = {}
      @container_factory = container_factory || method(:build_container)
    end

    def resolve(name)
      normalized_name = name.to_sym

      @containers.fetch(normalized_name) do
        definition = @configuration.fetch(name)
        container = @container_factory.call(definition)

        @containers[definition.name] = container
      end
    end

    private

    def build_container(definition)
      EngineContainer.new(
        name: definition.name,
        module_root: definition.root,
        entrypoint: definition.entrypoint,
        setup: definition.setup,
        gemfile: definition.gemfile
      )
    end
  end
end
