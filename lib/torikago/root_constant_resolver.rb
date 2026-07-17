require "pathname"

module Torikago
  # Resolves top-level constants from the main Box while keeping constants
  # owned by registered module roots private to their respective module Box.
  class RootConstantResolver
    UNRESOLVED = Object.new.freeze

    attr_reader :unresolved

    def initialize(registered_roots:, main_box: Object)
      @registered_roots = registered_roots.map { |root| normalize_path(root) }
      @main_box = main_box
      @unresolved = UNRESOLVED
    end

    def resolve(name)
      return unresolved unless main_box.const_defined?(name, false)
      return unresolved if registered_source?(main_box.autoload?(name, false))

      source_location = main_box.const_source_location(name, false)
      return unresolved if registered_source?(source_location&.first)

      constant = main_box.const_get(name, false)
      return unresolved if constant.is_a?(Module) && registered_descendant?(constant)

      constant
    end

    private

    attr_reader :main_box, :registered_roots

    def registered_source?(source_path)
      return false unless source_path

      normalized_source = normalize_path(source_path)
      registered_roots.any? do |root|
        normalized_source == root || normalized_source.start_with?("#{root}#{File::SEPARATOR}")
      end
    end

    def registered_descendant?(namespace, visited = {})
      return false if visited[namespace]

      visited[namespace] = true
      namespace.constants(false).any? do |name|
        autoload_path = namespace.autoload?(name, false)
        next true if registered_source?(autoload_path)

        source_location = namespace.const_source_location(name, false)
        next true if registered_source?(source_location&.first)
        next false if autoload_path

        child = namespace.const_get(name, false)
        child.is_a?(Module) && registered_descendant?(child, visited)
      rescue NameError
        false
      end
    end

    def normalize_path(path)
      expanded_path = Pathname(path).expand_path
      expanded_path.exist? ? expanded_path.realpath.to_s : expanded_path.to_s
    rescue SystemCallError
      expanded_path.to_s
    end
  end
end
