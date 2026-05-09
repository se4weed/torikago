require "fileutils"
require "pathname"
require "yaml"

module Torikago
  # Small command dispatcher used by the gem executable. Commands intentionally
  # delegate to service objects so the CLI stays thin and easy to test.
  class CLI
    HELP_TEXT = <<~TEXT.freeze
      usage: torikago COMMAND [ARGS]

      commands:
        init
            interactively generate package_api.yml files and config/initializers/torikago.rb
        check
            validate Gateway.call usage against package_api.yml
        update-package-api [BOX]
            regenerate package_api.yml entries from the configured public API entrypoint
        help, --help, -h
            show this help
    TEXT

    def initialize(stdin: $stdin, stdout: $stdout, stderr: $stderr)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv)
      command = argv.shift

      case command
      when nil, "help", "--help", "-h"
        stdout.print(HELP_TEXT)
        0
      when "init"
        run_init
      when "check"
        run_check
      when "update-package-api"
        run_update_package_api(argv.shift)
      else
        stderr.puts("unknown command: #{command}")
        stderr.print(HELP_TEXT)
        1
      end
    end

    private

    attr_reader :stderr, :stdin, :stdout

    def run_init
      modules_root_input = ask("Modules directory", default: "modules")
      modules_root = Pathname(modules_root_input)
      module_directories = discover_module_directories(modules_root)

      if module_directories.empty?
        stderr.puts("no modules found under #{modules_root}")
        return 1
      end

      configuration = Configuration.new

      module_directories.each do |module_root|
        module_name = module_root.basename.to_s
        entrypoint = ask("Public API directory for #{module_name}", default: "app/package_api")

        configuration.register(
          module_name.to_sym,
          root: module_root.to_s,
          entrypoint: entrypoint,
          gemfile: module_root.join("Gemfile").exist? ? "Gemfile" : nil
        )

        manifest_path = module_root.join("package_api.yml")
        manifest = manifest_path.exist? ? load_yaml_file(manifest_path) : { "exports" => {} }
        manifest_path.write(render_package_api_manifest(manifest))
        stdout.puts("generated #{manifest_path}")
      end

      initializer_path = Pathname("config/initializers/torikago.rb")
      FileUtils.mkdir_p(initializer_path.dirname)
      initializer_path.write(render_initializer(configuration))
      stdout.puts("generated #{initializer_path}")

      if yes?(ask("Run `torikago update-package-api` now?", default: "Y"))
        updates = PackageApiUpdater.new(configuration: configuration).call
        updates.each_value { |path| stdout.puts("updated #{path}") }
        stdout.puts("updated #{updates.size} package_api manifest#{'s' unless updates.size == 1}")
      end

      0
    end

    def run_check
      result = Checker.new(
        configuration: discover_configuration,
        source_roots: [Pathname("app"), Pathname("modules")]
      ).call

      if result.ok?
        stdout.puts(
          "ok: scanned #{result.scanned_file_count} Ruby files, " \
          "found #{result.gateway_call_count} Gateway.call usages, " \
          "validated #{result.manifest_count} package_api manifests"
        )
        0
      else
        result.errors.each { |error| stderr.puts(error) }
        stderr.puts(
          "failed: scanned #{result.scanned_file_count} Ruby files, " \
          "found #{result.gateway_call_count} Gateway.call usages, " \
          "validated #{result.manifest_count} package_api manifests, " \
          "#{result.errors.size} errors"
        )
        1
      end
    end

    def run_update_package_api(module_name)
      updates = PackageApiUpdater.new(configuration: discover_configuration).call(module_name)
      updates.each_value { |path| stdout.puts("updated #{path}") }
      stdout.puts("updated #{updates.size} package_api manifest#{'s' unless updates.size == 1}")
      0
    end

    def discover_configuration
      if File.exist?("config/environment.rb")
        # In Rails apps, prefer the application's configured module registry
        # over filesystem guessing.
        require File.expand_path("config/environment")
        return Torikago.configuration
      end

      # Outside Rails, use the conventional modules/* layout as a lightweight
      # fallback so check/update-package-api can run in early prototypes.
      Configuration.new.tap do |configuration|
        Dir["modules/*"].sort.each do |module_root|
          configuration.register(File.basename(module_root).to_sym, root: module_root)
        end
      end
    end

    def ask(prompt, default: nil)
      stdout.print("#{prompt}")
      stdout.print(" [#{default}]") if default
      stdout.print(": ")

      input = stdin.gets&.strip
      return default if input.nil? || input.empty?

      input
    end

    def discover_module_directories(modules_root)
      Dir[modules_root.join("*").to_s].map { |path| Pathname(path) }.select(&:directory?).sort
    end

    def load_yaml_file(path)
      YAML.safe_load(path.read, permitted_classes: [], aliases: false) || {}
    end

    def render_initializer(configuration)
      lines = [
        "# This file registers torikago runtime boundaries for your Rails app.",
        "#",
        "# Each config.register call defines one module root. Calls between modules",
        "# should go through Torikago::Gateway.call(\"Module::ExportedApi\") instead",
        "# of reaching across module constants directly.",
        "#",
        "# Options:",
        "#",
        "#   root:",
        "#     Filesystem root for the module.",
        "#",
        "#   entrypoint:",
        "#     Directory containing exported Package API classes. The conventional",
        "#     default is app/package_api.",
        "#",
        "#   gemfile:",
        "#     Optional module-local Gemfile. When Ruby::Box isolation is enabled,",
        "#     torikago prepends that module's resolved gem require paths inside the",
        "#     module Box.",
        "#",
        "#   setup:",
        "#     Optional setup file loaded before Package API files. Use this for",
        "#     explicit module boot behavior such as carefully scoped monkey patches.",
        "#",
        "# Package API permissions live in each module's package_api.yml under exports.",
        "# After changing Package API files, run:",
        "#",
        "#   bin/torikago update-package-api",
        "#",
        "# To validate Gateway.call usage against package_api.yml, run:",
        "#",
        "#   bin/torikago check",
        "",
        "Torikago.configure do |config|"
      ]

      configuration.each_definition do |definition|
        lines << "  config.register("
        lines << "    :#{definition.name},"
        lines << "    root: Rails.root.join(\"#{definition.root.to_s}\"),"
        lines << "    entrypoint: #{definition.entrypoint.inspect}#{definition.gemfile ? "," : ""}"
        lines << "    gemfile: #{definition.gemfile.inspect}" if definition.gemfile
        lines << "  )"
        lines << ""
      end

      lines << "end"
      lines.join("\n")
    end

    def render_package_api_manifest(manifest)
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

    def yes?(input)
      input.to_s.strip.empty? || %w[Y y yes YES].include?(input)
    end
  end
end
