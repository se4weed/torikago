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

  def test_invoke_loads_the_public_api_class_and_executes_call
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      result = container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})

      assert_equal ["coffee-beans", "drip-bag"], result
    end
  end

  def test_invoke_reuses_loaded_runtime_files_across_calls
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      first = container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      second = container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})

      assert_equal ["coffee-beans", "drip-bag"], first
      assert_equal ["coffee-beans", "drip-bag"], second
    end
  end

  def test_invoke_sets_the_current_box_during_execution
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      result = container.invoke("Foo::CurrentBoxQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})

      assert_equal :foo, result
      assert_nil Torikago::CurrentExecution.current_box
    end
  end

  def test_invoke_shares_root_constants_and_runtime_gateway_with_a_ruby_box
    Dir.mktmpdir("torikago-root-access") do |application_root|
      module_root = File.join(application_root, "modules/foo")
      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      root_constant_file = File.join(application_root, "root_constants.rb")
      File.write(
        root_constant_file,
        <<~RUBY
          class RootOrder
          end

          class RootCustomerQuery
            def self.call
              "root customer"
            end
          end
        RUBY
      )
      lazy_constant_file = File.join(application_root, "root_lazy_query.rb")
      File.write(
        lazy_constant_file,
        <<~RUBY
          class RootLazyQuery
            def self.call
              "lazy root"
            end
          end
        RUBY
      )
      File.write(
        File.join(package_api_dir, "root_access_query.rb"),
        <<~RUBY
          class Foo::RootAccessQuery < ::RootOrder
            def call
              [
                ::RootCustomerQuery.call,
                ::RootLazyQuery.call,
                self.class.superclass.object_id,
                Torikago::Gateway.object_id,
                Torikago::Gateway.invoke("Bar::Ping", :call)
              ]
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          module_root = ARGV.fetch(1)
          root_constant_file = ARGV.fetch(2)
          lazy_constant_file = ARGV.fetch(3)

          require "torikago"
          load root_constant_file
          autoload :RootLazyQuery, lazy_constant_file
          gateway_probe = Object.new
          gateway_probe.define_singleton_method(:invoke) { |class_name, method_name| [class_name, method_name] }
          Torikago.instance_variable_set(:@gateway, gateway_probe)

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: module_root,
            registered_roots: [module_root]
          )

          result = container.invoke("Foo::RootAccessQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
          expected = [
            "root customer",
            "lazy root",
            RootOrder.object_id,
            Torikago::Gateway.object_id,
            ["Bar::Ping", :call]
          ]
          raise "unexpected result: \#{result.inspect}" unless result == expected

          Object.send(:remove_const, :RootCustomerQuery)
          class RootCustomerQuery
            def self.call
              "reloaded root customer"
            end
          end
          reloaded_result = container.invoke("Foo::RootAccessQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
          raise "stale root constant: \#{reloaded_result.inspect}" unless reloaded_result.first == "reloaded root customer"

          puts "ok"
        RUBY
        module_root,
        root_constant_file,
        lazy_constant_file
      )
    end
  end

  def test_invoke_prefers_module_local_constants_over_root_constants
    Dir.mktmpdir("torikago-root-access") do |application_root|
      module_root = File.join(application_root, "modules/foo")
      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      root_constant_file = File.join(application_root, "root_constant.rb")
      File.write(root_constant_file, "RootPriority = \"root\"\n")
      File.write(
        File.join(package_api_dir, "priority_query.rb"),
        <<~RUBY
          RootPriority = "module"

          class Foo::PriorityQuery
            def call
              RootPriority
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          module_root = ARGV.fetch(1)
          root_constant_file = ARGV.fetch(2)

          require "torikago"
          load root_constant_file

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: module_root,
            registered_roots: [module_root]
          )

          result = container.invoke("Foo::PriorityQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
          raise "unexpected result: \#{result.inspect}" unless result == "module"

          puts "ok"
        RUBY
        module_root,
        root_constant_file
      )
    end
  end

  def test_invoke_does_not_share_constants_owned_by_a_registered_root
    Dir.mktmpdir("torikago-root-access") do |application_root|
      foo_root = File.join(application_root, "packs/foo")
      bar_root = File.join(application_root, "components/bar")
      package_api_dir = File.join(foo_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)
      FileUtils.mkdir_p(bar_root)

      registered_constant_file = File.join(bar_root, "bar_internal.rb")
      File.write(registered_constant_file, "class BarInternal; end\n")
      File.write(
        File.join(package_api_dir, "forbidden_root_query.rb"),
        <<~RUBY
          class Foo::ForbiddenRootQuery
            def call
              ::BarInternal
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          foo_root = ARGV.fetch(1)
          bar_root = ARGV.fetch(2)
          registered_constant_file = ARGV.fetch(3)

          require "torikago"
          load registered_constant_file

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: foo_root,
            registered_roots: [foo_root, bar_root]
          )

          begin
            container.invoke("Foo::ForbiddenRootQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
            raise "registered constant was unexpectedly shared"
          rescue NameError => error
            raise unless error.message.include?("BarInternal")
          end

          puts "ok"
        RUBY
        foo_root,
        bar_root,
        registered_constant_file
      )
    end
  end

  def test_invoke_does_not_resolve_a_qualified_module_constant_from_root
    Dir.mktmpdir("torikago-root-access") do |application_root|
      module_root = File.join(application_root, "modules/foo")
      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      root_constant_file = File.join(application_root, "order.rb")
      File.write(root_constant_file, "class Order; end\n")
      File.write(
        File.join(package_api_dir, "qualified_constant_query.rb"),
        <<~RUBY
          class Foo::QualifiedConstantQuery
            def call
              Foo::Order
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          module_root = ARGV.fetch(1)
          root_constant_file = ARGV.fetch(2)

          require "torikago"
          load root_constant_file

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: module_root,
            registered_roots: [module_root]
          )

          begin
            container.invoke("Foo::QualifiedConstantQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
            raise "Foo::Order unexpectedly resolved to ::Order"
          rescue NameError => error
            raise unless error.message.include?("Foo::Order")
          end

          puts "ok"
        RUBY
        module_root,
        root_constant_file
      )
    end
  end

  def test_invoke_does_not_share_a_root_namespace_with_a_registered_descendant
    Dir.mktmpdir("torikago-root-access") do |application_root|
      foo_root = File.join(application_root, "modules/foo")
      bar_root = File.join(application_root, "modules/bar")
      package_api_dir = File.join(foo_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)
      FileUtils.mkdir_p(bar_root)

      root_namespace_file = File.join(application_root, "shared_namespace.rb")
      registered_constant_file = File.join(bar_root, "bar_internal.rb")
      File.write(root_namespace_file, "module SharedNamespace; end\n")
      File.write(registered_constant_file, "class SharedNamespace::BarInternal; end\n")
      File.write(
        File.join(package_api_dir, "shared_namespace_query.rb"),
        <<~RUBY
          class Foo::SharedNamespaceQuery
            def call
              ::SharedNamespace::BarInternal
            end
          end
        RUBY
      )

      assert_ruby_box_child_process(
        <<~RUBY,
          $LOAD_PATH.unshift(ARGV.fetch(0))
          foo_root = ARGV.fetch(1)
          bar_root = ARGV.fetch(2)
          root_namespace_file = ARGV.fetch(3)
          registered_constant_file = ARGV.fetch(4)

          require "torikago"
          load root_namespace_file
          load registered_constant_file

          container = Torikago::EngineContainer.new(
            name: :foo,
            module_root: foo_root,
            registered_roots: [foo_root, bar_root]
          )

          begin
            container.invoke("Foo::SharedNamespaceQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
            raise "registered descendant was unexpectedly shared"
          rescue NameError => error
            raise unless error.message.include?("SharedNamespace")
          end

          puts "ok"
        RUBY
        foo_root,
        bar_root,
        root_namespace_file,
        registered_constant_file
      )
    end
  end

  def test_invoke_does_not_strip_bundler_env_during_public_api_execution
    with_module_root do |module_root|
      File.write(
        File.join(module_root, "app/package_api/foo/env_query.rb"),
        <<~RUBY
          class Foo::EnvQuery
            def call
              [ENV["RUBYOPT"], ENV["BUNDLER_SETUP"]]
            end
          end
        RUBY
      )

      old_rubyopt = ENV["RUBYOPT"]
      old_bundler_setup = ENV["BUNDLER_SETUP"]
      ENV["RUBYOPT"] = "-rbundler/setup -w"
      ENV["BUNDLER_SETUP"] = "true"

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        box_factory: -> { FakeBox.new }
      )

      assert_equal ["-rbundler/setup -w", "true"], container.invoke("Foo::EnvQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
    ensure
      restore_env("RUBYOPT", old_rubyopt)
      restore_env("BUNDLER_SETUP", old_bundler_setup)
    end
  end

  def test_bundler_env_stripping_is_serialized_across_containers
    first_container = Torikago::EngineContainer.new(name: :foo, module_root: Dir.pwd)
    second_container = Torikago::EngineContainer.new(name: :bar, module_root: Dir.pwd)
    first_entered = Queue.new
    release_first = Queue.new
    second_ready = Queue.new
    second_entered = Queue.new

    old_rubyopt = ENV["RUBYOPT"]
    old_bundler_setup = ENV["BUNDLER_SETUP"]
    ENV["RUBYOPT"] = "-rbundler/setup"
    ENV["BUNDLER_SETUP"] = "true"

    first_thread = Thread.new do
      first_container.send(:without_bundler_setup_env) do
        first_entered << true
        release_first.pop
      end
    end
    first_entered.pop

    second_thread = Thread.new do
      second_ready << true
      second_container.send(:without_bundler_setup_env) do
        second_entered << true
      end
    end
    second_ready.pop

    sleep 0.05
    assert_predicate second_entered, :empty?

    release_first << true
    first_thread.join
    second_thread.join

    refute_predicate second_entered, :empty?
  ensure
    first_thread&.kill if first_thread&.alive?
    second_thread&.kill if second_thread&.alive?
    restore_env("RUBYOPT", old_rubyopt)
    restore_env("BUNDLER_SETUP", old_bundler_setup)
  end

  def test_invoke_uses_a_configured_entrypoint_directory_when_present
    with_custom_entrypoint_module_root do |module_root|
      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        entrypoint: "components/public_api"
      )

      result = container.invoke("Foo::CustomEntryPointQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})

      assert_equal "custom entrypoint", result
    end
  end

  def test_invoke_does_not_load_parent_files_when_configured_entrypoint_directory_is_missing
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
        container.invoke("Foo::MissingQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      end

      assert_match(/MissingQuery/, error.message)
    end
  end

  def test_invoke_loads_plain_lib_entrypoint_by_default
    with_module_root do |module_root|
      lib_dir = File.join(module_root, "lib")
      FileUtils.mkdir_p(lib_dir)
      File.write(
        File.join(lib_dir, "foo.rb"),
        <<~RUBY
          module Foo
            PLAIN_LIB_ENTRYPOINT = "loaded"
          end
        RUBY
      )
      File.write(
        File.join(module_root, "app/package_api/foo/plain_lib_entrypoint_query.rb"),
        <<~RUBY
          class Foo::PlainLibEntrypointQuery
            def call
              Foo::PLAIN_LIB_ENTRYPOINT
            end
          end
        RUBY
      )

      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      assert_equal "loaded", container.invoke("Foo::PlainLibEntrypointQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
    end
  end

  def test_invoke_skips_only_the_module_lib_entrypoint_when_rails_engine_is_enabled
    with_module_root do |module_root|
      lib_dir = File.join(module_root, "lib")
      FileUtils.mkdir_p(File.join(lib_dir, "foo"))
      File.write(
        File.join(lib_dir, "foo.rb"),
        <<~RUBY
          raise "Rails::Engine entrypoint should be loaded by Rails, not EngineContainer"
        RUBY
      )
      File.write(
        File.join(lib_dir, "foo/support.rb"),
        <<~RUBY
          module Foo
            SUPPORT_VALUE = "ordinary lib file loaded"
          end
        RUBY
      )
      File.write(
        File.join(module_root, "app/package_api/foo/rails_engine_support_query.rb"),
        <<~RUBY
          class Foo::RailsEngineSupportQuery
            def call
              Foo::SUPPORT_VALUE
            end
          end
        RUBY
      )

      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        rails_engine: true
      )

      assert_equal "ordinary lib file loaded", container.invoke("Foo::RailsEngineSupportQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
    end
  end

  def test_invoke_prepends_explicit_gemfile_require_paths_before_loading_runtime
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

          raise "unexpected result" unless container.invoke("Foo::DependencyVersionQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {}) == "module-local"

          puts "ok"
        RUBY
        module_root,
        dependency_lib
      )
    end
  end

  def test_invoke_resolves_path_gem_require_paths_inside_ruby_box
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

          raise "unexpected result" unless container.invoke("Foo::DependencyVersionQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {}) == "module-local"

          puts "ok"
        RUBY
        module_root
      )
    end
  end

  def test_invoke_resolves_path_gem_require_paths_from_the_module_gemfile
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

          raise "unexpected result" unless container.invoke("Foo::GemfileDependencyQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {}) == "1.0.0"

          puts "ok"
        RUBY
        module_root
      )
    end
  end

  def test_invoke_resolves_exact_installed_gem_require_paths_after_a_different_version_is_active
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

  def test_invoke_reports_missing_installed_gemfile_dependencies_clearly
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
        container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      end

      assert_match(/example-gem/, error.message)
      assert_match(/foo/, error.message)
    end
  end

  def test_invoke_loads_configured_setup_before_public_api
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

      assert_equal "patched", container.invoke("Foo::SetupAwareQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
    end
  end

  def test_invoke_loads_setup_only_once
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

      assert_equal 1, container.invoke("Foo::SetupCountQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      assert_equal 1, container.invoke("Foo::SetupCountQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
    end
  end

  def test_invoke_raises_load_error_when_setup_is_missing
    with_module_root do |module_root|
      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        setup: "config/missing_setup.rb"
      )

      error = assert_raises(LoadError) do
        container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      end

      assert_match(/setup not found/, error.message)
      assert_match(/missing_setup\.rb/, error.message)
    end
  end

  def test_invoke_loads_plain_gateway_models_without_eager_loading_rails_models
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

      assert_equal ["order"], container.invoke("Foo::ListOrdersQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
    end
  end

  def test_invoke_keeps_constructor_and_method_arguments_separate
    with_module_root do |module_root|
      File.write(
        File.join(module_root, "app/package_api/foo/product_query.rb"),
        <<~RUBY
          class Foo::ProductQuery
            def initialize(prefix, page:)
              @prefix = prefix
              @page = page
            end

            def execute!(suffix, force:)
              [@prefix, @page, suffix, force, Torikago::CurrentExecution.current_box]
            end
          end
        RUBY
      )
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      result = container.invoke(
        "Foo::ProductQuery",
        :execute!,
        constructor_args: ["products"],
        constructor_kwargs: { page: 2 },
        method_args: ["refresh"],
        method_kwargs: { force: true }
      )

      assert_equal ["products", 2, "refresh", true, :foo], result
      assert_nil Torikago::CurrentExecution.current_box
    end
  end

  def test_invoke_rejects_private_methods
    with_module_root do |module_root|
      File.write(
        File.join(module_root, "app/package_api/foo/private_query.rb"),
        <<~RUBY
          class Foo::PrivateQuery
            private

            def execute!
              "should not run"
            end
          end
        RUBY
      )
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      assert_raises(NoMethodError) do
        container.invoke("Foo::PrivateQuery", :execute!, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      end
    end
  end

  def test_invoke_preserves_constructor_and_method_exceptions
    with_module_root do |module_root|
      File.write(
        File.join(module_root, "app/package_api/foo/failing_query.rb"),
        <<~RUBY
          class Foo::FailingQuery
            def initialize(fail_constructor: false)
              raise "constructor failed" if fail_constructor
            end

            def execute!
              raise "method failed"
            end
          end
        RUBY
      )
      constructor_container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)
      method_container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      constructor_error = assert_raises(RuntimeError) do
        constructor_container.invoke(
          "Foo::FailingQuery",
          :execute!,
          constructor_args: [],
          constructor_kwargs: { fail_constructor: true },
          method_args: [],
          method_kwargs: {}
        )
      end
      method_error = assert_raises(RuntimeError) do
        method_container.invoke(
          "Foo::FailingQuery",
          :execute!,
          constructor_args: [],
          constructor_kwargs: {},
          method_args: [],
          method_kwargs: {}
        )
      end

      assert_equal "constructor failed", constructor_error.message
      assert_equal "method failed", method_error.message
    end
  end

  def test_invoke_restores_current_execution_after_nested_execution
    with_module_root do |module_root|
      File.write(
        File.join(module_root, "app/package_api/foo/nested_query.rb"),
        <<~RUBY
          class Foo::NestedQuery
            def execute!
              Torikago::CurrentExecution.with_box(:bar) { :nested }
              Torikago::CurrentExecution.current_box
            end
          end
        RUBY
      )
      container = Torikago::EngineContainer.new(name: :foo, module_root: module_root)

      result = Torikago::CurrentExecution.with_box(:caller) do
        current = container.invoke("Foo::NestedQuery", :execute!, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
        [current, Torikago::CurrentExecution.current_box]
      end

      assert_equal [:foo, :caller], result
      assert_nil Torikago::CurrentExecution.current_box
    end
  end

  def test_invoke_fails_closed_when_ruby_box_creation_fails
    with_module_root do |module_root|
      old_ruby_box = ENV["RUBY_BOX"]
      ENV["RUBY_BOX"] = "1"
      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        box_factory: -> { raise "box creation failed" }
      )

      error = assert_raises(Torikago::BoxUnavailableError) do
        container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      end

      assert_equal "Ruby::Box is unavailable for module foo: box creation failed", error.message
      assert_instance_of RuntimeError, error.cause
      refute Object.const_defined?(:Foo, false)
    ensure
      restore_env("RUBY_BOX", old_ruby_box)
    end
  end

  def test_invoke_wraps_box_runtime_preparation_failures
    with_module_root do |module_root|
      old_ruby_box = ENV["RUBY_BOX"]
      ENV["RUBY_BOX"] = "1"
      failing_box = Object.new
      failing_box.define_singleton_method(:load_path) { raise "load path failed" }
      container = Torikago::EngineContainer.new(
        name: :foo,
        module_root: module_root,
        box_factory: -> { failing_box }
      )

      error = assert_raises(Torikago::BoxUnavailableError) do
        container.invoke("Foo::ListProductsQuery", :call, constructor_args: [], constructor_kwargs: {}, method_args: [], method_kwargs: {})
      end

      assert_match(/load path failed/, error.message)
      assert_instance_of RuntimeError, error.cause
      refute Object.const_defined?(:Foo, false)
    ensure
      restore_env("RUBY_BOX", old_ruby_box)
    end
  end

  private

  class FakeBox
    attr_reader :load_path

    def initialize
      @load_path = []
    end

    def require(_name)
    end

    def load(path)
      Kernel.load(path)
    end

    def const_defined?(name, inherit = true)
      Object.const_defined?(name, inherit)
    end

    def const_set(name, value)
      Object.const_set(name, value)
    end

    def const_get(name)
      Object.const_get(name)
    end
  end

  def restore_env(key, value)
    if value
      ENV[key] = value
    else
      ENV.delete(key)
    end
  end

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
