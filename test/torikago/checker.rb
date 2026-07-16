require_relative "../test_helper"
require "fileutils"
require "tmpdir"

class TorikagoCheckerTest < Minitest::Test
  def test_check_detects_one_line_gateway_invoke
    with_project do |root, configuration|
      write_caller(root, 'Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :execute!)')

      result = check(root, configuration)

      assert result.ok?, result.errors.join("\n")
      assert_equal 1, result.gateway_call_count
      assert_equal 0, result.dynamic_gateway_call_count
    end
  end

  def test_check_detects_multiline_build_and_invoke
    with_project do |root, configuration|
      write_caller(
        root,
        <<~RUBY
          Torikago::Gateway
            .build("Bar::SubmitOrderCommand", account_id: 1)
            .invoke(:execute!, force: true)
        RUBY
      )

      result = check(root, configuration)

      assert result.ok?, result.errors.join("\n")
      assert_equal 1, result.gateway_call_count
    end
  end

  def test_check_reports_a_method_not_declared_in_the_manifest
    with_project do |root, configuration|
      write_caller(root, 'Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :delete_all!)')

      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("Bar::SubmitOrderCommand#delete_all! is not exported") })
    end
  end

  def test_check_reports_an_unauthorized_caller
    with_project(allowed_callers: []) do |root, configuration|
      write_caller(root, 'Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :execute!)')

      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("foo is not allowed to call Bar::SubmitOrderCommand#execute!") })
    end
  end

  def test_check_reports_manifest_entries_without_methods
    with_project(methods: nil) do |root, configuration|
      write_caller(root, 'Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :execute!)')

      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("must declare a non-empty methods array") })
    end
  end

  def test_check_reports_manifest_entries_with_empty_methods
    with_project(methods: []) do |root, configuration|
      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("must declare a non-empty methods array") })
    end
  end

  def test_check_reports_missing_public_api_files
    with_project do |root, configuration|
      FileUtils.rm_f(File.join(root, "modules/bar/app/package_api/bar/submit_order_command.rb"))

      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("does not have a matching file") })
    end
  end

  def test_check_reports_exported_methods_missing_from_the_implementation
    with_project(implementation_method: :call) do |root, configuration|
      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("#execute! is exported but no public instance method definition was found") })
    end
  end

  def test_check_does_not_treat_private_methods_as_public_implementations
    with_project(implementation_visibility: :private) do |root, configuration|
      result = check(root, configuration)

      refute result.ok?
      assert(result.errors.any? { |error| error.include?("no public instance method definition") })
    end
  end

  def test_check_skips_dynamic_gateway_arguments_and_counts_them_separately
    with_project do |root, configuration|
      write_caller(root, "Torikago::Gateway.invoke(class_name, method_name)")

      result = check(root, configuration)

      assert result.ok?, result.errors.join("\n")
      assert_equal 0, result.gateway_call_count
      assert_equal 1, result.dynamic_gateway_call_count
    end
  end

  def test_check_uses_a_configured_entrypoint_directory
    with_project(entrypoint: "components/public_api") do |root, configuration|
      write_caller(root, 'Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :execute!)')

      result = check(root, configuration)

      assert result.ok?, result.errors.join("\n")
    end
  end

  private

  def check(root, configuration)
    checker = Torikago::Checker.new(
      configuration: configuration,
      source_roots: [File.join(root, "modules")]
    )
    Dir.chdir(root) { checker.call }
  end

  def write_caller(root, invocation)
    FileUtils.mkdir_p(File.join(root, "modules/foo"))
    File.write(
      File.join(root, "modules/foo/service.rb"),
      <<~RUBY
        class FooService
          def call
            #{invocation}
          end
        end
      RUBY
    )
  end

  def with_project(entrypoint: nil, methods: ["execute!"], allowed_callers: ["foo"], implementation_method: :execute!, implementation_visibility: :public)
    Dir.mktmpdir("torikago-checker") do |root|
      foo_root = File.join(root, "modules/foo")
      bar_root = File.join(root, "modules/bar")
      public_api_root = entrypoint ? File.join(bar_root, entrypoint, "bar") : File.join(bar_root, "app/package_api/bar")
      FileUtils.mkdir_p(foo_root)
      FileUtils.mkdir_p(public_api_root)

      methods_yaml = methods.nil? ? "" : "    methods:\n#{methods.map { |method| "      - #{method}" }.join("\n")}\n"
      File.write(
        File.join(bar_root, "package_api.yml"),
        <<~YAML
          exports:
            Bar::SubmitOrderCommand:
          #{methods_yaml}    allowed_callers:
          #{allowed_callers.map { |caller| "      - #{caller}" }.join("\n")}
        YAML
      )

      visibility = implementation_visibility == :public ? "" : "  #{implementation_visibility}\n\n"
      File.write(
        File.join(public_api_root, "submit_order_command.rb"),
        <<~RUBY
          class Bar::SubmitOrderCommand
          #{visibility}  def #{implementation_method}
            end
          end
        RUBY
      )

      configuration = Torikago::Configuration.new
      configuration.register(:foo, root: foo_root)
      configuration.register(:bar, root: bar_root, entrypoint: entrypoint)

      yield root, configuration
    end
  end
end
