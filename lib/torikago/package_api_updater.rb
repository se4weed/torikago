require "pathname"
require "yaml"

module Torikago
  # Regenerates package_api.yml from files under a module's public API
  # entrypoint while preserving caller permissions already chosen by humans.
  class PackageApiUpdater
    def initialize(configuration:)
      @configuration = configuration
    end

    def call(module_name = nil)
      definitions_for(module_name).each_with_object({}) do |definition, updates|
        manifest_path = definition.root.join("package_api.yml")
        existing_manifest = load_manifest(manifest_path)
        updated_manifest = build_manifest(definition, existing_manifest)

        manifest_path.write(render_manifest(updated_manifest))
        updates[definition.name] = manifest_path
      end
    end

    private

    attr_reader :configuration

    def definitions_for(module_name)
      return configuration.each_definition.to_a if module_name.nil?

      [configuration.fetch(module_name)]
    end

    def load_manifest(path)
      return {} unless path.exist?

      YAML.safe_load(path.read, permitted_classes: [], aliases: false) || {}
    end

    def build_manifest(definition, existing_manifest)
      existing_public_api = exported_package_apis(existing_manifest)

      public_api_entries = discover_public_api_classes(definition).each_with_object({}) do |class_name, entries|
        existing_entry = existing_public_api.fetch(class_name, {})

        # update-package-api owns discovery, not policy. Keep allowed_callers so
        # the command does not silently widen or narrow module dependencies.
        entries[class_name] = {
          "allowed_callers" => Array(existing_entry["allowed_callers"]).map(&:to_s)
        }
      end

      { "exports" => public_api_entries }
    end

    def exported_package_apis(manifest)
      manifest.fetch("exports") { manifest.fetch("public_api", {}) }
    end

    def render_manifest(manifest)
      <<~YAML
        # This file declares the Package APIs exported by this module.
        #
        # Each key under exports is a class that may be called through:
        #
        #   Torikago::Gateway.call("ModuleName::SomeQuery")
        #
        # allowed_callers lists other modules that may call that export. The
        # host app and the module itself are allowed implicitly.
        #
      YAML
        .then { |header| header + YAML.dump(manifest) }
    end

    def discover_public_api_classes(definition)
      Dir[public_api_root(definition).join("**/*.rb").to_s].sort.map do |path|
        relative_path = Pathname(path).relative_path_from(public_api_root(definition)).to_s
        class_name_from(relative_path)
      end
    end

    def public_api_root(definition)
      return definition.root.join("app/package_api") if definition.entrypoint.nil?

      # Match EngineContainer and Checker: directory entrypoints are roots,
      # while file entrypoints imply implementations live beside the file.
      candidate = definition.root.join(definition.entrypoint)
      return candidate if candidate.directory?
      return candidate unless candidate.extname == ".rb"

      candidate.dirname
    end

    def class_name_from(relative_path)
      relative_path.delete_suffix(".rb").split("/").map { |segment| camelize(segment) }.join("::")
    end

    def camelize(segment)
      segment.split("_").map(&:capitalize).join
    end
  end
end
