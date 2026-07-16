require "pathname"
require "ripper"
require "yaml"

module Torikago
  # Lightweight static checks for explicit Gateway calls and package API
  # manifests. This is intentionally conservative; runtime enforcement still
  # lives in Gateway.
  class Checker
    class Result
      attr_accessor :dynamic_gateway_call_count, :errors, :scanned_file_count, :gateway_call_count, :manifest_count

      def initialize(errors: Array.new, scanned_file_count: 0, gateway_call_count: 0, dynamic_gateway_call_count: 0, manifest_count: 0)
        @errors = errors
        @scanned_file_count = scanned_file_count
        @gateway_call_count = gateway_call_count
        @dynamic_gateway_call_count = dynamic_gateway_call_count
        @manifest_count = manifest_count
      end

      def ok?
        errors.empty?
      end
    end

    GatewayCall = Struct.new(:class_name, :method_name, keyword_init: true)

    class GatewayCallExtractor
      attr_reader :calls, :dynamic_call_count

      def initialize(source)
        @sexp = Ripper.sexp(source)
        @calls = Array.new
        @dynamic_call_count = 0
      end

      def call
        walk(sexp)
        self
      end

      private

      attr_reader :sexp

      def walk(node)
        return unless node.is_a?(Array)

        extract(node) if node.first == :method_add_arg
        node.each { |child| walk(child) if child.is_a?(Array) }
      end

      def extract(node)
        call_node = node[1]
        return unless call_node&.first == :call
        return unless token_value(call_node[3]) == "invoke"

        receiver = call_node[1]
        arguments = arguments_from(node[2])

        if gateway_constant?(receiver)
          record(string_literal(arguments[0]), symbol_literal(arguments[1]))
        elsif build_call?(receiver)
          build_arguments = arguments_from(receiver[2])
          record(string_literal(build_arguments[0]), symbol_literal(arguments[0]))
        end
      end

      def record(class_name, method_name)
        if class_name && method_name
          calls << GatewayCall.new(class_name: class_name, method_name: method_name)
        else
          @dynamic_call_count += 1
        end
      end

      def build_call?(node)
        return false unless node&.first == :method_add_arg

        call_node = node[1]
        call_node&.first == :call &&
          token_value(call_node[3]) == "build" &&
          gateway_constant?(call_node[1])
      end

      def gateway_constant?(node)
        constant_name(node) == "Torikago::Gateway"
      end

      def constant_name(node)
        return unless node.is_a?(Array)

        case node.first
        when :var_ref, :const_ref, :top_const_ref
          token_value(node[1])
        when :const_path_ref
          [constant_name(node[1]), token_value(node[2])].compact.join("::")
        end
      end

      def arguments_from(node)
        return Array.new unless node&.first == :arg_paren

        args_add_block = node[1]
        return Array.new unless args_add_block&.first == :args_add_block

        args_add_block[1] || Array.new
      end

      def string_literal(node)
        return unless node&.first == :string_literal

        content = node[1]
        parts = content&.first == :string_content ? content.drop(1) : Array.new
        return unless parts.length == 1 && parts.first&.first == :@tstring_content

        token_value(parts.first)
      end

      def symbol_literal(node)
        return unless node&.first == :symbol_literal

        symbol = node[1]
        token = symbol&.first == :symbol ? symbol[1] : nil
        token_value(token)&.to_sym
      end

      def token_value(token)
        token[1] if token.is_a?(Array) && token.first.to_s.start_with?("@")
      end
    end

    def initialize(configuration:, source_roots:)
      @configuration = configuration
      @source_roots = Array(source_roots).map { |root| Pathname(root) }
      @manifests = Hash.new
    end

    def call
      errors = Array.new
      gateway_call_count = 0
      dynamic_gateway_call_count = 0
      scanned_files = source_files

      scanned_files.each do |path|
        static_count, dynamic_count = scan_gateway_calls(path, errors)
        gateway_call_count += static_count
        dynamic_gateway_call_count += dynamic_count
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
        dynamic_gateway_call_count: dynamic_gateway_call_count,
        manifest_count: manifest_count
      )
    end

    private

    attr_reader :configuration, :manifests, :source_roots

    def source_files
      source_roots.flat_map { |root| Dir[root.join("**/*.rb").to_s] }.sort.uniq
    end

    def scan_gateway_calls(path, errors)
      extraction = GatewayCallExtractor.new(File.read(path)).call
      extraction.calls.each do |gateway_call|
        class_name = gateway_call.class_name
        method_name = gateway_call.method_name

        # Public API names are expected to start with their owning module
        # namespace, e.g. Foo::ListProductsQuery targets the :foo box.
        target_box = infer_box_name(class_name)
        manifest_entry = public_api_entry_for(target_box, class_name)
        caller_box = infer_caller_box_from_path(path)

        if manifest_entry.nil?
          errors << "#{path}: #{class_name}##{method_name} is not declared in #{target_box}/package_api.yml exports"
          next
        end

        methods = exported_methods(manifest_entry)
        if !methods.empty? && !methods.include?(method_name.to_s)
          errors << "#{path}: #{class_name}##{method_name} is not exported by #{target_box}/package_api.yml"
          next
        end

        next if caller_box.nil?
        next if caller_box == target_box

        allowed_callers = allowed_callers(manifest_entry).map { |caller| caller.to_s }
        next if allowed_callers.include?(caller_box.to_s)

        errors << "#{path}: #{caller_box} is not allowed to call #{class_name}##{method_name}"
      end

      [extraction.calls.size, extraction.dynamic_call_count]
    end

    def validate_manifest_entries(definition, errors)
      manifest_path = definition.root.join("package_api.yml")
      exported_package_apis(load_manifest(definition)).each do |class_name, manifest_entry|
        methods = exported_methods(manifest_entry)
        if methods.empty?
          errors << "#{manifest_path}: #{class_name} must declare a non-empty methods array"
        end

        # The manifest is the contract, but the checker also catches stale
        # entries whose implementation file has been deleted or moved.
        expected_path = expected_public_api_path(definition, class_name)
        unless expected_path.exist?
          errors << "#{manifest_path}: #{class_name} does not have a matching file at #{expected_path}"
          next
        end

        next if methods.empty?

        implemented_methods, dynamic_definition = public_instance_methods(expected_path, class_name)
        next if dynamic_definition

        methods.each do |method_name|
          next if implemented_methods.include?(method_name)

          errors << "#{expected_path}: #{class_name}##{method_name} is exported but no public instance method definition was found"
        end
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
            YAML.safe_load(manifest_path.read, permitted_classes: Array.new, aliases: false) || Hash.new
          else
            Hash.new
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
      manifest.fetch("exports") { manifest.fetch("public_api", Hash.new) }
    end

    def allowed_callers(manifest_entry)
      return Array.new unless manifest_entry.is_a?(Hash)

      allowed = manifest_entry["allowed_callers"]
      return allowed if allowed.is_a?(Array)

      Array.new
    end

    def exported_methods(manifest_entry)
      return Array.new unless manifest_entry.is_a?(Hash)

      methods = manifest_entry["methods"]
      return methods.map(&:to_s) if methods.is_a?(Array)

      Array.new
    end

    def public_instance_methods(path, class_name)
      sexp = Ripper.sexp(File.read(path))
      methods = Array.new
      dynamic_definition = false

      visit_definitions = lambda do |node, namespace|
        next unless node.is_a?(Array)

        case node.first
        when :program
          Array(node[1]).each { |child| visit_definitions.call(child, namespace) }
        when :module
          name = qualified_constant_name(node[1], namespace)
          visit_definitions.call(node[2], name)
        when :class
          name = qualified_constant_name(node[1], namespace)
          if name == class_name
            class_body_methods(node[3]).tap do |result|
              methods.concat(result.fetch(:methods))
              dynamic_definition ||= result.fetch(:dynamic)
            end
          else
            visit_definitions.call(node[3], name)
          end
        when :bodystmt
          Array(node[1]).each { |child| visit_definitions.call(child, namespace) }
        else
          node.each { |child| visit_definitions.call(child, namespace) if child.is_a?(Array) }
        end
      end

      visit_definitions.call(sexp, nil)
      [methods.uniq, dynamic_definition]
    end

    def class_body_methods(body)
      visibility = :public
      methods = Array.new
      dynamic = false
      statements = body&.first == :bodystmt ? Array(body[1]) : Array.new

      statements.each do |statement|
        visibility_name = bare_call_name(statement)
        case visibility_name
        when "public"
          visibility = :public
          next
        when "private"
          visibility = :private
          next
        when "protected"
          visibility = :protected
          next
        end

        if statement&.first == :def
          methods << statement[1][1].to_s if visibility == :public
        elsif contains_call?(statement, "define_method")
          dynamic = true
        end
      end

      { methods: methods, dynamic: dynamic }
    end

    def bare_call_name(node)
      return unless node&.first == :vcall

      token = node[1]
      token[1] if token&.first == :@ident
    end

    def contains_call?(node, method_name)
      return false unless node.is_a?(Array)
      return true if %i[vcall fcall].include?(node.first) && node.dig(1, 1) == method_name

      node.any? { |child| child.is_a?(Array) && contains_call?(child, method_name) }
    end

    def qualified_constant_name(node, namespace)
      name = constant_name(node)
      return name if name&.include?("::") || namespace.nil?

      "#{namespace}::#{name}"
    end

    def constant_name(node)
      return unless node.is_a?(Array)

      case node.first
      when :var_ref, :const_ref, :top_const_ref
        node.dig(1, 1)
      when :const_path_ref
        [constant_name(node[1]), node.dig(2, 1)].compact.join("::")
      end
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
