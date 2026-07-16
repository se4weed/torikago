require "pathname"
require "yaml"

module Torikago
  # Runtime entrypoint for all cross-module calls. It validates the package API
  # manifest before dispatching into the target module container.
  class Gateway
    class << self
      def build(...)
        Torikago.gateway.build(...)
      end

      def invoke(...)
        Torikago.gateway.invoke(...)
      end
    end

    def initialize(registry:, configuration:, manifest_loader: nil)
      @registry = registry
      @configuration = configuration
      @manifest_loader = manifest_loader || method(:load_manifest)
      @manifests = Hash.new
    end

    def build(public_api_class_name, *constructor_args, **constructor_kwargs)
      Invocation.new(
        gateway: self,
        public_api_class_name: public_api_class_name,
        constructor_args: constructor_args,
        constructor_kwargs: constructor_kwargs
      )
    end

    def invoke(public_api_class_name, method_name, *method_args, **method_kwargs)
      dispatch(
        public_api_class_name: public_api_class_name,
        method_name: method_name,
        constructor_args: Array.new,
        constructor_kwargs: Hash.new,
        method_args: method_args,
        method_kwargs: method_kwargs
      )
    end

    # Internal interface used by Invocation. Validation deliberately precedes
    # Registry resolution so rejected calls cannot boot the target Box.
    def dispatch(public_api_class_name:, method_name:, constructor_args:, constructor_kwargs:, method_args:, method_kwargs:)
      target_module = infer_target_module(public_api_class_name)
      caller_module = CurrentExecution.current_box

      validate_public_api!(target_module, public_api_class_name, method_name, caller_module)
      registry.resolve(target_module).invoke(
        public_api_class_name,
        method_name,
        constructor_args: constructor_args,
        constructor_kwargs: constructor_kwargs,
        method_args: method_args,
        method_kwargs: method_kwargs
      )
    end

    private

    attr_reader :configuration, :manifest_loader, :manifests, :registry

    def validate_public_api!(target_module, public_api_class_name, method_name, caller_module)
      target_name = target_module.to_sym
      definition = configuration.fetch(target_name)
      manifest = manifests.fetch(target_name) do
        manifests[target_name] = manifest_loader.call(definition)
      end

      public_api_entry = exported_package_apis(manifest).fetch(public_api_class_name, nil)
      if public_api_entry.nil?
        raise PublicApiError,
              "package api export not declared for #{target_name}: #{public_api_class_name}##{method_name}"
      end

      methods = exported_methods(public_api_entry)
      if methods.empty?
        raise PublicApiError,
              "package api methods are not configured: #{public_api_class_name}##{method_name}"
      end

      unless methods.include?(method_name.to_s)
        raise PublicApiError,
              "package api method is not exported: #{public_api_class_name}##{method_name}"
      end

      return if caller_module.nil?

      caller_name = caller_module.to_sym
      # A module may always call its own public API; allowed_callers only governs
      # calls crossing from one module box into another.
      return if caller_name == target_name
      return if dependency_allowed?(public_api_entry, caller_name)

      raise DependencyError,
            "module dependency not allowed: #{caller_name} -> #{target_name}##{public_api_class_name}##{method_name}"
    end

    def load_manifest(definition)
      manifest_path = package_api_manifest_path(definition)

      unless manifest_path.exist?
        raise DependencyError,
              "package_api manifest not found for #{definition.name}: #{manifest_path}"
      end

      YAML.safe_load(manifest_path.read, permitted_classes: Array.new, aliases: false) || Hash.new
    end

    def package_api_manifest_path(definition)
      Pathname(definition.root).join("package_api.yml")
    end

    def infer_target_module(public_api_class_name)
      public_api_class_name.split("::").first.downcase.to_sym
    end

    def exported_package_apis(manifest)
      manifest.fetch("exports") { manifest.fetch("public_api", Hash.new) }
    end

    def dependency_allowed?(public_api_entry, caller_name)
      allowed_callers(public_api_entry).map { |caller| caller.to_sym }.include?(caller_name)
    end

    def exported_methods(public_api_entry)
      return Array.new unless public_api_entry.is_a?(Hash)

      methods = public_api_entry["methods"]
      return methods.map(&:to_s) if methods.is_a?(Array)

      Array.new
    end

    def allowed_callers(public_api_entry)
      return Array.new unless public_api_entry.is_a?(Hash)

      allowed = public_api_entry["allowed_callers"]
      return allowed if allowed.is_a?(Array)

      Array.new
    end
  end
end
