require "pathname"

module Torikago
  # Stores module definitions declared by the host application. Other runtime
  # objects treat this as the source of truth for module roots and boot options.
  class Configuration
    Definition = Struct.new(:name, :root, :entrypoint, :setup, :gemfile, keyword_init: true)

    def initialize
      @definitions = {}
    end

    def register(name, root:, entrypoint: nil, setup: nil, gemfile: nil)
      if @definitions.key?(name.to_sym)
        raise ArgumentError, "module already registered: #{name}"
      end

      @definitions[name.to_sym] = Definition.new(
        name: name.to_sym,
        root: Pathname(root),
        entrypoint: entrypoint,
        setup: setup,
        gemfile: gemfile
      )
    end

    def registered?(name)
      @definitions.key?(name.to_sym)
    end

    def each_definition(&block)
      return @definitions.each_value unless block

      @definitions.each_value(&block)
    end

    def fetch(name)
      normalized_name = name.to_sym

      @definitions.fetch(normalized_name) do
        raise KeyError, "module not registered: #{name}"
      end
    end
  end
end
