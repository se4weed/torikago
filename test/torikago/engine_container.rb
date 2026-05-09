require_relative "../test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

class TorikagoEngineContainerTest < Minitest::Test
  def teardown
    Object.send(:remove_const, :Foo) if Object.const_defined?(:Foo, false)
    Object.send(:remove_const, :SharedDependency) if Object.const_defined?(:SharedDependency, false)
    Object.send(:remove_const, :SetupProbe) if Object.const_defined?(:SetupProbe, false)
    Object.send(:remove_const, :VersionedFormatter) if Object.const_defined?(:VersionedFormatter, false)
  end

  def test_call_loads_the_public_api_class_and_executes_call
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      result = container.call("Foo::ListProductsQuery")

      assert_equal ["coffee-beans", "drip-bag"], result
    end
  end

  def test_call_reuses_loaded_runtime_files_across_calls
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      first = container.call("Foo::ListProductsQuery")
      second = container.call("Foo::ListProductsQuery")

      assert_equal ["coffee-beans", "drip-bag"], first
      assert_equal ["coffee-beans", "drip-bag"], second
    end
  end

  def test_call_sets_the_current_box_during_execution
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      result = container.call("Foo::CurrentBoxQuery")

      assert_equal :foo, result
      assert_nil Torikago::CurrentExecution.current_box
    end
  end

  def test_call_uses_a_configured_entrypoint_directory_when_present
    with_custom_entrypoint_module_root do |module_root|
      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        entrypoint: "components/public_api"
      )

      result = container.call("Foo::CustomEntryPointQuery")

      assert_equal "custom entrypoint", result
    end
  end

  def test_call_does_not_load_parent_files_when_configured_entrypoint_directory_is_missing
    Dir.mktmpdir("torikago-engine-container") do |module_root|
      FileUtils.mkdir_p(File.join(module_root, "app/controllers/foo"))
      File.write(
        File.join(module_root, "app/controllers/foo/widgets_controller.rb"),
        <<~RUBY
          raise "app/controllers should not be loaded as public API"
        RUBY
      )

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        entrypoint: "app/package_api"
      )

      error = assert_raises(NameError) do
        container.call("Foo::MissingQuery")
      end

      assert_match(/MissingQuery/, error.message)
    end
  end

  def test_call_prepends_explicit_gemfile_require_paths_before_loading_runtime
    with_module_root do |module_root|
      dependency_lib = File.join(module_root, "vendor/example-gem-1.2.3/lib")
      FileUtils.mkdir_p(dependency_lib)
      File.write(
        File.join(dependency_lib, "shared_dependency.rb"),
        <<~RUBY
          module SharedDependency
            VERSION = "module-local"
          end
        RUBY
      )
      File.write(File.join(module_root, "Gemfile"), "")
      File.write(
        File.join(module_root, "app/package_api/foo/dependency_version_query.rb"),
        <<~RUBY
          require "shared_dependency"

          class Foo::DependencyVersionQuery
            def call
              SharedDependency::VERSION
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          module_root = ARGV.fetch(1)
          dependency_lib = ARGV.fetch(2)

          require "torikago"

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: module_root,
            gemfile: "Gemfile",
            gemfile_dependency_loader: lambda do |path|
              raise "unexpected Gemfile path: \#{path}" unless path.to_s == File.join(module_root, "Gemfile")

              [{ name: "example-gem", requirement: "= 1.2.3", require_paths: [dependency_lib] }]
            end,
            gem_activator: lambda do |_dependency|
              raise "gem activator should not be called when Ruby::Box is active"
            end
          )

          raise "unexpected result" unless container.call("Foo::DependencyVersionQuery") == "module-local"

          puts "ok"
        RUBY
        module_root,
        dependency_lib
      )
    end
  end

  def test_call_resolves_path_gem_require_paths_inside_ruby_box
    Dir.mktmpdir("torikago-engine-container") do |module_root|
      dependency_lib = File.join(module_root, "vendor/example-gem-1.0.0/lib")
      FileUtils.mkdir_p(dependency_lib)
      File.write(
        File.join(module_root, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"

          gem "example-gem", path: "vendor/example-gem-1.0.0"
        RUBY
      )
      File.write(
        File.join(module_root, "vendor/example-gem-1.0.0/example-gem.gemspec"),
        <<~RUBY
          Gem::Specification.new do |spec|
            spec.name = "example-gem"
            spec.version = "1.0.0"
            spec.summary = "test gem"
            spec.authors = ["torikago"]
            spec.files = ["lib/shared_dependency.rb"]
            spec.require_paths = ["lib"]
          end
        RUBY
      )
      File.write(
        File.join(dependency_lib, "shared_dependency.rb"),
        <<~RUBY
          module SharedDependency
            VERSION = "module-local"
          end
        RUBY
      )

      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)
      File.write(
        File.join(package_api_dir, "dependency_version_query.rb"),
        <<~RUBY
          require "shared_dependency"

          class Foo::DependencyVersionQuery
            def call
              SharedDependency::VERSION
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          module_root = ARGV.fetch(1)

          require "torikago"

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: module_root,
            gemfile: "Gemfile"
          )

          raise "unexpected result" unless container.call("Foo::DependencyVersionQuery") == "module-local"

          puts "ok"
        RUBY
        module_root
      )
    end
  end

  def test_call_resolves_path_gem_require_paths_from_the_module_gemfile
    Dir.mktmpdir("torikago-engine-container") do |module_root|
      dependency_root = File.join(module_root, "vendor/versioned_formatter")
      dependency_lib = File.join(dependency_root, "lib")
      FileUtils.mkdir_p(dependency_lib)
      File.write(
        File.join(dependency_root, "versioned_formatter.gemspec"),
        <<~RUBY
          Gem::Specification.new do |spec|
            spec.name = "versioned_formatter"
            spec.version = "1.0.0"
            spec.summary = "test gem"
            spec.authors = ["torikago"]
            spec.files = ["lib/versioned_formatter.rb"]
            spec.require_paths = ["lib"]
          end
        RUBY
      )
      File.write(
        File.join(dependency_lib, "versioned_formatter.rb"),
        <<~RUBY
          module VersionedFormatter
            VERSION = "1.0.0"
          end
        RUBY
      )
      File.write(
        File.join(module_root, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"

          gem "versioned_formatter", path: "vendor/versioned_formatter"
        RUBY
      )

      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)
      File.write(
        File.join(package_api_dir, "gemfile_dependency_query.rb"),
        <<~RUBY
          require "versioned_formatter"

          class Foo::GemfileDependencyQuery
            def call
              VersionedFormatter::VERSION
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          module_root = ARGV.fetch(1)

          require "torikago"

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: module_root,
            gemfile: "Gemfile"
          )

          raise "unexpected result" unless container.call("Foo::GemfileDependencyQuery") == "1.0.0"

          puts "ok"
        RUBY
        module_root
      )
    end
  end

  def test_call_resolves_exact_installed_gem_require_paths_after_a_different_version_is_active
    skip("requires rake 13.3.1 and 13.4.2") unless installed_gem?("rake", "= 13.3.1") && installed_gem?("rake", "= 13.4.2")

    Dir.mktmpdir("torikago-engine-container") do |module_root|
      File.write(
        File.join(module_root, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"

          gem "rake", "= 13.3.1"
        RUBY
      )

      Kernel.send(:gem, "rake", "= 13.4.2")
      require "rake"

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        gemfile: "Gemfile"
      )

      dependencies = container.send(:load_gemfile_dependencies, Pathname(File.join(module_root, "Gemfile")))

      assert_equal "rake", dependencies.fetch(0).fetch(:name)
      assert_equal "= 13.3.1", dependencies.fetch(0).fetch(:requirement)
      assert_match(%r{/rake-13\.3\.1/lib\z}, dependencies.fetch(0).fetch(:require_paths).first)
    end
  end

  def test_call_reports_missing_installed_gemfile_dependencies_clearly
    with_module_root do |module_root|
      File.write(
        File.join(module_root, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"

          gem "example-gem", "= 9.9.9"
        RUBY
      )

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        gemfile: "Gemfile"
      )

      error = assert_raises(Torikago::GemfileOverrideError) do
        container.call("Foo::ListProductsQuery")
      end

      assert_match(/example-gem/, error.message)
      assert_match(/foo/, error.message)
    end
  end

  def test_call_loads_configured_setup_before_public_api
    with_module_root do |module_root|
      setup_dir = File.join(module_root, "config")
      FileUtils.mkdir_p(setup_dir)
      File.write(
        File.join(setup_dir, "box_setup.rb"),
        <<~RUBY
          module SetupProbe
            VALUE = "patched"
          end
        RUBY
      )

      File.write(
        File.join(module_root, "app/package_api/foo/setup_aware_query.rb"),
        <<~RUBY
          class Foo::SetupAwareQuery
            def call
              SetupProbe::VALUE
            end
          end
        RUBY
      )

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        setup: "config/box_setup.rb"
      )

      assert_equal "patched", container.call("Foo::SetupAwareQuery")
    end
  end

  def test_call_loads_setup_only_once
    with_module_root do |module_root|
      setup_dir = File.join(module_root, "config")
      FileUtils.mkdir_p(setup_dir)
      File.write(
        File.join(setup_dir, "box_setup.rb"),
        <<~RUBY
          module SetupProbe
            RUNS = (const_defined?(:RUNS) ? RUNS + 1 : 1)
          end
        RUBY
      )

      File.write(
        File.join(module_root, "app/package_api/foo/setup_count_query.rb"),
        <<~RUBY
          class Foo::SetupCountQuery
            def call
              SetupProbe::RUNS
            end
          end
        RUBY
      )

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        setup: "config/box_setup.rb"
      )

      assert_equal 1, container.call("Foo::SetupCountQuery")
      assert_equal 1, container.call("Foo::SetupCountQuery")
    end
  end

  def test_call_raises_load_error_when_setup_is_missing
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        setup: "config/missing_setup.rb"
      )

      error = assert_raises(LoadError) do
        container.call("Foo::ListProductsQuery")
      end

      assert_match(/setup not found/, error.message)
      assert_match(/missing_setup\.rb/, error.message)
    end
  end

  def test_call_loads_plain_gateway_models_without_eager_loading_rails_models
    with_module_root do |module_root|
      model_dir = File.join(module_root, "app/models/foo")
      FileUtils.mkdir_p(model_dir)
      File.write(
        File.join(model_dir, "order_store.rb"),
        <<~RUBY
          class Foo::OrderStore
            def self.all
              ["order"]
            end
          end
        RUBY
      )
      File.write(
        File.join(model_dir, "foo_record.rb"),
        <<~RUBY
          raise "ActiveRecord models should not be eager-loaded by Gateway"

          class Foo::FooRecord < ActiveRecord::Base
          end
        RUBY
      )
      File.write(
        File.join(module_root, "app/package_api/foo/list_orders_query.rb"),
        <<~RUBY
          class Foo::ListOrdersQuery
            def call
              Foo::OrderStore.all
            end
          end
        RUBY
      )

      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      assert_equal ["order"], container.call("Foo::ListOrdersQuery")
    end
  end

  private

  def with_module_root
    Dir.mktmpdir("torikago-engine-container") do |module_root|
      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      File.write(
        File.join(package_api_dir, "list_products_query.rb"),
        <<~RUBY
          class Foo::ListProductsQuery
            def call
              ["coffee-beans", "drip-bag"]
            end
          end
        RUBY
      )

      File.write(
        File.join(package_api_dir, "current_box_query.rb"),
        <<~RUBY
          class Foo::CurrentBoxQuery
            def call
              Torikago::CurrentExecution.current_box
            end
          end
        RUBY
      )
      yield module_root
    end
  end

  def with_custom_entrypoint_module_root
    Dir.mktmpdir("torikago-engine-container") do |module_root|
      package_api_dir = File.join(module_root, "components/public_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      File.write(
        File.join(package_api_dir, "custom_entry_point_query.rb"),
        <<~RUBY
          class Foo::CustomEntryPointQuery
            def call
              "custom entrypoint"
            end
          end
        RUBY
      )
      yield module_root
    end
  end

  def assert_ruby_box_child_process(script, *args)
    stdout, stderr, status = Open3.capture3(
      { "RUBY_BOX" => "1" },
      RbConfig.ruby,
      "-e",
      script,
      File.expand_path("../../lib", __dir__),
      *args
    )

    assert_predicate status, :success?, stderr
    assert_equal "ok\n", stdout
  end

  def installed_gem?(name, requirement)
    return true unless installed_specs_for(name, requirement).empty?

    gem_requirement = Gem::Requirement.new(requirement)
    Gem::Specification.dirs.any? do |specification_dir|
      Dir[File.join(specification_dir, "#{name}-*.gemspec")].any? do |gemspec_path|
        spec = Gem::Specification.load(gemspec_path)
        spec && spec.name == name && gem_requirement.satisfied_by?(spec.version)
      end
    end
  end

  def installed_specs_for(name, requirement)
    Gem::Specification.find_all_by_name(name, requirement)
  end
end
