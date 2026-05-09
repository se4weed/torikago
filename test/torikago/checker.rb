require_relative "../test_helper"
require "fileutils"
require "tmpdir"

class TorikagoCheckerTest < Minitest::Test
  def test_check_returns_no_errors_for_declared_calls
    with_project do |root, configuration|
      FileUtils.mkdir_p(File.join(root, "modules/foo"))
      File.write(
        File.join(root, "modules/foo/service.rb"),
        <<~RUBY
          class FooService
            def call
              Torikago::Gateway.call("Bar::SubmitOrderCommand")
            end
          end
        RUBY
      )

      checker = Torikago::Checker.new(
        configuration: configuration,
        source_roots: [File.join(root, "modules")]
      )

      result = Dir.chdir(root) { checker.call }

      assert result.ok?
      assert_equal [], result.errors
      assert_equal 2, result.scanned_file_count
      assert_equal 1, result.gateway_call_count
      assert_equal 2, result.manifest_count
    end
  end

  def test_check_reports_undeclared_calls_and_missing_public_api_files
    with_project do |root, configuration|
      FileUtils.mkdir_p(File.join(root, "modules/foo"))
      File.write(
        File.join(root, "modules/foo/service.rb"),
        <<~RUBY
          class FooService
            def call
              Torikago::Gateway.call("Bar::MissingCommand")
            end
          end
        RUBY
      )

      File.write(
        File.join(root, "modules/bar/package_api.yml"),
        <<~YAML
          exports:
            Bar::MissingCommand:
              allowed_callers:
                - foo
        YAML
      )

      checker = Torikago::Checker.new(
        configuration: configuration,
        source_roots: [File.join(root, "modules")]
      )

      result = Dir.chdir(root) { checker.call }

      refute result.ok?
      assert_equal 1, result.errors.size
      assert_match(/matching file/, result.errors.first)
    end
  end

  def test_check_uses_a_configured_entrypoint_directory_when_matching_manifest_files
    with_project(entrypoint: "components/public_api") do |root, configuration|
      FileUtils.mkdir_p(File.join(root, "modules/foo"))
      File.write(
        File.join(root, "modules/foo/service.rb"),
        <<~RUBY
          class FooService
            def call
              Torikago::Gateway.call("Bar::SubmitOrderCommand")
            end
          end
        RUBY
      )

      checker = Torikago::Checker.new(
        configuration: configuration,
        source_roots: [File.join(root, "modules")]
      )

      result = Dir.chdir(root) { checker.call }

      assert result.ok?
      assert_equal [], result.errors
    end
  end

  def test_check_does_not_match_manifest_entries_against_parent_when_configured_entrypoint_directory_is_missing
    Dir.mktmpdir("torikago-checker") do |root|
      foo_root = File.join(root, "modules/foo")
      FileUtils.mkdir_p(File.join(foo_root, "app/models/foo"))
      File.write(File.join(foo_root, "app/models/foo/widget.rb"), "")
      File.write(
        File.join(foo_root, "package_api.yml"),
        <<~YAML
          exports:
            Models::Foo::Widget:
              allowed_callers: []
        YAML
      )

      configuration = Torikago::Configuration.new
      configuration.register(:foo, root: foo_root, entrypoint: "app/package_api")

      checker = Torikago::Checker.new(
        configuration: configuration,
        source_roots: [File.join(root, "modules")]
      )

      result = Dir.chdir(root) { checker.call }

      refute result.ok?
      assert_equal 1, result.errors.size
      assert_match(/matching file/, result.errors.first)
    end
  end

  private

  def with_project(entrypoint: nil)
    Dir.mktmpdir("torikago-checker") do |root|
      foo_root = File.join(root, "modules/foo")
      bar_root = File.join(root, "modules/bar")
      public_api_root = entrypoint ? File.join(bar_root, entrypoint, "bar") : File.join(bar_root, "app/package_api/bar")
      FileUtils.mkdir_p(public_api_root)

      File.write(
        File.join(bar_root, "package_api.yml"),
        <<~YAML
          exports:
            Bar::SubmitOrderCommand:
              allowed_callers:
                - foo
        YAML
      )

      File.write(
        File.join(public_api_root, "submit_order_command.rb"),
        <<~RUBY
          class Bar::SubmitOrderCommand
            def call
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
