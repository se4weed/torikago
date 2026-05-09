require "pathname"
require "yaml"

module Torikago
  # Lightweight static checks for explicit Gateway calls and package API
  # manifests. This is intentionally conservative; runtime enforcement still
  # lives in Gateway.
  class Checker
    Result = Struct.new(
      :errors,
      :scanned_file_count,
      :gateway_call_count,
      :manifest_count,
      keyword_init: true
    ) do
      def ok?
        errors.empty?
      end
    end

    CALL_PATTERN = /
      Torikago::Gateway\.call\(
      \s*
      ["'](?<class_name>[A-Z][A-Za-z0-9:]+)["']
    /x.freeze

    def initialize(configuration:, source_roots:)
      @configuration = configuration
      @source_roots = Array(source_roots).map { |root| Pathname(root) }
      @manifests = {}
    end

    def call
      errors = []
      gateway_call_count = 0
      scanned_files = source_files

      scanned_files.each do |path|
        gateway_call_count += scan_gateway_calls(path, errors)
      end

      manifest_count = 0
      configuration.each_definition do |definition|
        manifest_count += 1
        validate_manifest_entries(definition, errors)
      end

      Result.new(
        errors: errors,
        scanned_file_count: scanned_files.size,
        gateway_call_count: gateway_call_count,
        manifest_count: manifest_count
      )
    end

    private

    attr_reader :configuration, :manifests, :source_roots

    def source_files
      source_roots.flat_map { |root| Dir[root.join("**/*.rb").to_s] }.sort.uniq
    end

    def scan_gateway_calls(path, errors)
      content = File.read(path)
      call_count = 0
      content.to_enum(:scan, CALL_PATTERN).each do
        call_count += 1
        class_name = Regexp.last_match[:class_name]
        # Public API names are expected to start with their owning module
        # namespace, e.g. Foo::ListProductsQuery targets the :foo box.
        target_box = infer_box_name(class_name)
        manifest_entry = public_api_entry_for(target_box, class_name)
        caller_box = infer_caller_box_from_path(path)

        if manifest_entry.nil?
          errors << "#{path}: #{class_name} is not declared in #{target_box}/package_api.yml exports"
          next
        end

        next if caller_box.nil?
        next if caller_box == target_box

        allowed_callers = Array(manifest_entry["allowed_callers"]).map(&:to_s)
        next if allowed_callers.include?(caller_box.to_s)

        errors << "#{path}: #{caller_box} is not allowed to call #{class_name}"
      end

      call_count
    end

    def validate_manifest_entries(definition, errors)
      exported_package_apis(load_manifest(definition)).each_key do |class_name|
        # The manifest is the contract, but the checker also catches stale
        # entries whose implementation file has been deleted or moved.
        expected_path = expected_public_api_path(definition, class_name)
        next if expected_path.exist?

        errors << "#{definition.root.join('package_api.yml')}: #{class_name} does not have a matching file at #{expected_path}"
      end
    end

    def public_api_entry_for(box_name, class_name)
      exported_package_apis(load_manifest(configuration.fetch(box_name)))[class_name]
    rescue KeyError
      nil
    end

    def load_manifest(definition)
      manifests.fetch(definition.name) do
        manifest_path = definition.root.join("package_api.yml")
        manifests[definition.name] =
          if manifest_path.exist?
            YAML.safe_load(manifest_path.read, permitted_classes: [], aliases: false) || {}
          else
            {}
          end
      end
    end

    def expected_public_api_path(definition, class_name)
      relative_path = class_name.split("::").map { |segment| underscore(segment) }.join("/")
      public_api_root(definition).join("#{relative_path}.rb")
    end

    def infer_box_name(class_name)
      class_name.split("::").first.downcase.to_sym
    end

    def infer_caller_box_from_path(path)
      # This path heuristic matches the Rails modular-monolith layout that
      # torikago is designed around: modules/<box-name>/...
      path.match(%r{/modules/(?<box>[a-z0-9_]+)/})&.named_captures&.fetch("box", nil)&.to_sym
    end

    def exported_package_apis(manifest)
      manifest.fetch("exports") { manifest.fetch("public_api", {}) }
    end

    def underscore(name)
      word = name.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.downcase
    end

    def public_api_root(definition)
      return definition.root.join("app/package_api") if definition.entrypoint.nil?

      # entrypoint may point at either a directory or a single boot file. For a
      # file entrypoint, package API implementations live next to that file.
      candidate = definition.root.join(definition.entrypoint)
      return candidate if candidate.directory?
      return candidate unless candidate.extname == ".rb"

      candidate.dirname
    end
  end
end
