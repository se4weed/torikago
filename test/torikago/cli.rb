require_relative "../test_helper"
require "stringio"
require "tmpdir"
require "fileutils"
require "yaml"

class TorikagoCliTest < Minitest::Test
  def test_help_option_prints_usage
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = Torikago::CLI.new(stdout: stdout, stderr: stderr).run(["--help"])

    assert_equal 0, exit_code
    assert_match(/usage: torikago COMMAND/, stdout.string)
    assert_match(/init/, stdout.string)
    assert_match(/configured public API entrypoint/, stdout.string)
    assert_equal "", stderr.string
  end

  def test_init_interactively_generates_manifests_and_initializer
    Dir.mktmpdir("torikago-init") do |root|
      FileUtils.mkdir_p(File.join(root, "config/initializers"))
      FileUtils.mkdir_p(File.join(root, "modules/foo/app/package_api/foo"))
      FileUtils.mkdir_p(File.join(root, "modules/bar/components/public_api/bar"))

      File.write(
        File.join(root, "modules/foo/app/package_api/foo/list_products_query.rb"),
        <<~RUBY
          class Foo::ListProductsQuery
          end
        RUBY
      )

      File.write(
        File.join(root, "modules/bar/components/public_api/bar/submit_order_command.rb"),
        <<~RUBY
          class Bar::SubmitOrderCommand
          end
        RUBY
      )

      stdin = StringIO.new("modules\ncomponents/public_api\n\nY\n")
      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = Dir.chdir(root) do
        Torikago::CLI.new(stdin: stdin, stdout: stdout, stderr: stderr).run(["init"])
      end

      assert_equal 0, exit_code
      assert_equal "", stderr.string

      foo_manifest = YAML.safe_load(File.read(File.join(root, "modules/foo/package_api.yml")))
      bar_manifest = YAML.safe_load(File.read(File.join(root, "modules/bar/package_api.yml")))
      initializer = File.read(File.join(root, "config/initializers/torikago.rb"))

      assert_equal({ "allowed_callers" => [] }, foo_manifest.dig("exports", "Foo::ListProductsQuery"))
      assert_equal({ "allowed_callers" => [] }, bar_manifest.dig("exports", "Bar::SubmitOrderCommand"))
      assert_match(/root: Rails\.root\.join\("modules\/bar"\)/, initializer)
      assert_match(/entrypoint: "components\/public_api"/, initializer)
      assert_match(/root: Rails\.root\.join\("modules\/foo"\)/, initializer)
      assert_match(/entrypoint: "app\/package_api"/, initializer)
      assert_match(/Run `torikago update-package-api` now\?/, stdout.string)
      assert_match(/updated 2 package_api manifests/, stdout.string)
    end
  end

  def test_check_prints_summary_information
    with_cli_project do |root|
      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = Dir.chdir(root) do
        Torikago::CLI.new(stdout: stdout, stderr: stderr).run(["check"])
      end

      assert_equal 0, exit_code
      assert_match(/scanned 2 Ruby files/, stdout.string)
      assert_match(/found 1 Gateway\.call usages/, stdout.string)
      assert_match(/validated 2 package_api manifests/, stdout.string)
      assert_equal "", stderr.string
    end
  end

  def test_update_package_api_prints_updated_count
    with_cli_project do |root|
      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = Dir.chdir(root) do
        Torikago::CLI.new(stdout: stdout, stderr: stderr).run(["update-package-api", "bar"])
      end

      assert_equal 0, exit_code
      assert_match(/updated .*modules\/bar\/package_api\.yml/, stdout.string)
      assert_match(/updated 1 package_api manifest/, stdout.string)
      assert_equal "", stderr.string
    end
  end

  private

  def with_cli_project
    Dir.mktmpdir("torikago-cli") do |root|
      FileUtils.mkdir_p(File.join(root, "modules/foo"))
      FileUtils.mkdir_p(File.join(root, "modules/bar/app/package_api/bar"))

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

      File.write(
        File.join(root, "modules/bar/package_api.yml"),
        <<~YAML
          exports:
            Bar::SubmitOrderCommand:
              allowed_callers:
                - foo
        YAML
      )

      File.write(
        File.join(root, "modules/bar/app/package_api/bar/submit_order_command.rb"),
        <<~RUBY
          class Bar::SubmitOrderCommand
            def call
            end
          end
        RUBY
      )

      yield root
    end
  end
end
