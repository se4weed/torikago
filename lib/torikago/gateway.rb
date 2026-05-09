require "pathname"
require "yaml"

module Torikago
  # Runtime entrypoint for all cross-module calls. It validates the package API
  # manifest before dispatching into the target module container.
  class Gateway
    class << self
      def call(...)
        Torikago.gateway.call(...)
      end
    end

    def initialize(registry:, configuration:, manifest_loader: nil)
      @registry = registry
      @configuration = configuration
      @manifest_loader = manifest_loader || method(:load_manifest)
      @manifests = {}
    end

    def call(public_api_class_name, *args, **kwargs)
      target_module = infer_target_module(public_api_class_name)
      caller_module = CurrentExecution.current_box

      # Validation happens before resolving the container so denied calls do not
      # accidentally boot or load the target module.
      validate_public_api!(target_module, public_api_class_name, caller_module)
      registry.resolve(target_module).call(public_api_class_name, *args, **kwargs)
    end

    private

    attr_reader :configuration, :manifest_loader, :manifests, :registry

    def validate_public_api!(target_module, public_api_class_name, caller_module)
      target_name = target_module.to_sym
      definition = configuration.fetch(target_name)
      manifest = manifests.fetch(target_name) do
        manifests[target_name] = manifest_loader.call(definition)
      end

      public_api_entry = exported_package_apis(manifest).fetch(public_api_class_name, nil)
      if public_api_entry.nil?
        raise PublicApiError, "package api export not declared for #{target_name}: #{public_api_class_name}"
      end

      return if caller_module.nil?

      caller_name = caller_module.to_sym
      # A module may always call its own public API; allowed_callers only governs
      # calls crossing from one module box into another.
      return if caller_name == target_name
      return if dependency_allowed?(public_api_entry, caller_name)

      raise DependencyError,
            "module dependency not allowed: #{caller_name} -> #{target_name}##{public_api_class_name}"
    end

    def load_manifest(definition)
      manifest_path = package_api_manifest_path(definition)

      unless manifest_path.exist?
        raise DependencyError,
              "package_api manifest not found for #{definition.name}: #{manifest_path}"
      end

      YAML.safe_load(manifest_path.read, permitted_classes: [], aliases: false) || {}
    end

    def package_api_manifest_path(definition)
      Pathname(definition.root).join("package_api.yml")
    end

    def infer_target_module(public_api_class_name)
      public_api_class_name.split("::").first.downcase.to_sym
    end

    def exported_package_apis(manifest)
      manifest.fetch("exports") { manifest.fetch("public_api", {}) }
    end

    def dependency_allowed?(public_api_entry, caller_name)
      Array(public_api_entry["allowed_callers"]).map(&:to_sym).include?(caller_name)
    end
  end
end
