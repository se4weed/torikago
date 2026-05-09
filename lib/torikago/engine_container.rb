require "pathname"

module Torikago
  # Owns the runtime for one registered module. When Ruby::Box is available it
  # loads the module into an isolated Box; otherwise it falls back to the host
  # process for development and tests.
  class EngineContainer
    def initialize(name:, module_root:, entrypoint: nil, setup: nil, gemfile: nil, box_factory: nil, gemfile_dependency_loader: nil, gem_activator: nil)
      @name = name
      @module_root = Pathname(module_root)
      @entrypoint = entrypoint
      @setup = setup
      @gemfile = gemfile
      @box_factory = box_factory
      @gemfile_dependency_loader = gemfile_dependency_loader || method(:load_gemfile_dependencies)
      @gem_activator = gem_activator || method(:activate_gem_dependency)
    end

    def call(public_api_class_name, *args, **kwargs)
      CurrentExecution.with_box(name) do
        public_api_class = resolve_public_api_class(public_api_class_name)
        public_api_class.new.call(*args, **kwargs)
      end
    end

    private

    attr_reader :box_factory, :entrypoint, :gem_activator, :gemfile, :gemfile_dependency_loader, :module_root, :name, :setup

    def boot_runtime!
      return if @booted

      files = runtime_files
      gemfile_dependencies
      if isolated_box_enabled?
        # The Box starts with an independent load path and constant table, so
        # boot has to copy enough host context before loading module code.
        prepare_box!
        prepend_gemfile_require_paths_to_box!
        load_setup_hook_into_box!
        ensure_root_namespace_in_box!

        files.each do |path|
          box.load(path)
        end
      else
        # Non-Box mode preserves the same public behavior while giving up
        # runtime isolation. This keeps local development usable on normal Ruby.
        apply_gemfile_overrides!
        load_setup_hook!
        ensure_root_namespace!

        files.each do |path|
          load path
        end
      end

      @booted = true
    end

    def load_setup_hook!
      path = setup_path
      return unless path

      unless path.exist?
        raise LoadError, "setup not found for #{name}: #{path}"
      end

      load path.to_s
    end

    def apply_gemfile_overrides!
      path = gemfile_path
      return unless path

      gemfile_dependencies.each do |dependency|
        gem_activator.call(dependency)
      rescue Gem::LoadError => e
        raise GemfileOverrideError,
              "failed to activate #{dependency.fetch(:name)} (#{dependency.fetch(:requirement)}) for #{name}: #{e.message}"
      end
    end

    def prepend_gemfile_require_paths_to_box!
      paths = gemfile_dependencies.flat_map { |dependency| Array(dependency[:require_paths] || dependency["require_paths"]) }
      return if paths.empty?
      return unless box.respond_to?(:load_path)

      # Put module-specific gems ahead of the host load path so the Box resolves
      # dependency versions from the module Gemfile first.
      box.load_path.replace(paths.map(&:to_s) + box.load_path)
    end

    def gemfile_dependencies
      path = gemfile_path
      return [] unless path

      @gemfile_dependencies ||= gemfile_dependency_loader.call(path)
    end

    def resolve_public_api_class(class_name)
      boot_runtime!
      root = isolated_box_enabled? ? box : Object
      # const_get is evaluated inside the Box object when isolation is enabled,
      # which keeps public API constants out of the host Object namespace.
      class_name.split("::").reduce(root) { |context, segment| context.const_get(segment) }
    end

    def runtime_files
      @runtime_files ||= [
        *library_files,
        *gateway_model_files,
        *Dir[public_api_root.join("**/*.rb").to_s].sort
      ]
    end

    def public_api_root
      configured_entrypoint = entrypoint
      return module_root.join("app/package_api") if configured_entrypoint.nil?

      candidate = module_root.join(configured_entrypoint)
      return candidate if candidate.directory?
      return candidate unless candidate.extname == ".rb"

      candidate.dirname
    end

    def gemfile_path
      return unless gemfile

      module_root.join(gemfile)
    end

    def setup_path
      return unless setup

      module_root.join(setup)
    end

    def ensure_root_namespace!
      namespace = camelize(name.to_s)
      return if Object.const_defined?(namespace, false)

      Object.const_set(namespace, Module.new)
    end

    def ensure_root_namespace_in_box!
      namespace = camelize(name.to_s)
      return if box.const_defined?(namespace, false)

      box.const_set(namespace, Module.new)
    end

    def isolated_box_enabled?
      return true if box_factory

      ruby_box_runtime_available?
    end

    def box
      @box ||= if box_factory
                 box_factory.call
               else
                 Ruby::Box.new
               end
    end

    def prepare_box!
      return if @box_prepared

      box.load_path.replace($LOAD_PATH.dup) if box.respond_to?(:load_path)
      if box.respond_to?(:require)
        box.require("torikago/current_execution")
      end
      @box_prepared = true
    end

    def gateway_model_files
      # Package APIs may depend on small PORO-style models. Active Record models
      # are skipped because Rails owns their loading and database connection.
      Dir[module_root.join("app/models/**/*.rb").to_s].sort.reject do |path|
        rails_model_file?(path)
      end
    end

    def rails_model_file?(path)
      source = File.read(path)
      source.match?(/ActiveRecord::Base|<\s+\w+Record\b|^\s*validates\s/m)
    end

    def load_setup_hook_into_box!
      path = setup_path
      return unless path

      unless path.exist?
        raise LoadError, "setup not found for #{name}: #{path}"
      end

      box.load(path.to_s)
    end

    def library_files
      all_files = Dir[module_root.join("lib/**/*.rb").to_s].sort
      monkey_patch_files = Dir[module_root.join("lib/monkey_patches/**/*.rb").to_s]

      # Monkey patches are only loaded through the explicit setup hook so a
      # module has to opt in to global-ish runtime changes.
      all_files - monkey_patch_files
    end

    def ruby_box_runtime_available?
      return @ruby_box_runtime_available unless @ruby_box_runtime_available.nil?

      @ruby_box_runtime_available = if ENV["RUBY_BOX"] == "1"
                                      begin
                                        Ruby::Box.new
                                        true
                                      rescue RuntimeError
                                        false
                                      end
                                    else
                                      false
                                    end
    end

    def camelize(segment)
      segment.split("_").map(&:capitalize).join
    end

    def load_gemfile_dependencies(path)
      unless path.exist?
        raise GemfileOverrideError, "gemfile not found for #{name}: #{path}"
      end

      # Prefer cheap local parsing for path and exact-version dependencies, then
      # fall back to Bundler for more complex Gemfiles.
      path_gem_dependencies = load_path_gem_dependencies(path)
      return path_gem_dependencies unless path_gem_dependencies.empty?

      installed_gem_dependencies = load_installed_gem_dependencies(path)
      return installed_gem_dependencies unless installed_gem_dependencies.empty?

      require "bundler"

      lockfile = Pathname("#{path}.lock")
      definition = Bundler::Definition.build(path.to_s, lockfile.exist? ? lockfile.to_s : nil, nil)

      specs_by_name = definition.specs.each_with_object({}) do |spec, specs|
        specs[spec.name] ||= spec
      end

      definition.dependencies.filter_map do |dependency|
        spec = specs_by_name.fetch(dependency.name, nil)
        next unless spec

        requirement = dependency.requirement.to_s
        {
          name: dependency.name,
          requirement: requirement,
          require_paths: spec.full_require_paths
        }
      end
    rescue Bundler::BundlerError => e
      raise GemfileOverrideError, "failed to load gemfile for #{name}: #{e.message}"
    end

    def load_path_gem_dependencies(path)
      path.dirname.then do |gemfile_root|
        path.read.scan(/^\s*gem\s+["']([^"']+)["']\s*,\s*path:\s*["']([^"']+)["']/).filter_map do |gem_name, relative_path|
          gem_root = gemfile_root.join(relative_path)
          gemspec_path = gem_root.join("#{gem_name}.gemspec")
          gemspec_path = Dir[gem_root.join("*.gemspec").to_s].sort.first unless gemspec_path.exist?
          next unless gemspec_path

          spec = Gem::Specification.load(gemspec_path.to_s)
          next unless spec

          {
            name: spec.name,
            requirement: "= #{spec.version}",
            require_paths: spec.require_paths.map { |require_path| gem_root.join(require_path).to_s }
          }
        end
      end
    end

    def load_installed_gem_dependencies(path)
      dependencies = exact_version_gemfile_dependencies(path)
      return [] if dependencies.empty?

      dependencies.filter_map do |dependency|
        specs = installed_specs_for(dependency.fetch(:name), dependency.fetch(:requirement))
        spec = specs.max_by(&:version)
        unless spec
          raise GemfileOverrideError,
                "failed to load gemfile for #{name}: Could not find gem '#{dependency.fetch(:name)} (#{dependency.fetch(:requirement)})' in locally installed gems."
        end

        {
          name: spec.name,
          requirement: dependency.fetch(:requirement),
          require_paths: spec.full_require_paths
        }
      end
    end

    def installed_specs_for(gem_name, requirement)
      specs = Gem::Specification.find_all_by_name(gem_name, requirement)
      return specs unless specs.empty?

      gem_requirement = Gem::Requirement.new(requirement)
      Gem::Specification.dirs.flat_map do |specification_dir|
        Dir[File.join(specification_dir, "#{gem_name}-*.gemspec")].filter_map do |gemspec_path|
          spec = Gem::Specification.load(gemspec_path)
          next unless spec
          next unless spec.name == gem_name
          next unless gem_requirement.satisfied_by?(spec.version)

          spec
        end
      end
    end

    def exact_version_gemfile_dependencies(path)
      path.read.each_line.filter_map do |line|
        match = line.match(/^\s*gem\s+["']([^"']+)["']\s*,\s*["']=\s*([^"']+)["']/)
        next unless match

        {
          name: match[1],
          requirement: "= #{match[2]}"
        }
      end
    end

    def activate_gem_dependency(dependency)
      Kernel.send(:gem, dependency.fetch(:name), dependency.fetch(:requirement))
    end
  end
end
