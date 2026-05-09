require_relative "../test_helper"
require "fileutils"
require "tmpdir"
require "yaml"

class TorikagoPackageApiUpdaterTest < Minitest::Test
  def test_update_package_api_creates_manifest_from_package_api_files
    Dir.mktmpdir("torikago-package-api-updater") do |module_root|
      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      File.write(File.join(package_api_dir, "user_create_command.rb"), "")
      File.write(File.join(package_api_dir, "user_find_query.rb"), "")

      configuration = Torikago::Configuration.new
      configuration.register(:foo, root: module_root)

      updates = Torikago::PackageApiUpdater.new(configuration: configuration).call
      manifest = YAML.safe_load(File.read(File.join(module_root, "package_api.yml")))

      assert_equal [Pathname(File.join(module_root, "package_api.yml"))], updates.values
      assert_equal(
        {
          "exports" => {
            "Foo::UserCreateCommand" => { "allowed_callers" => [] },
            "Foo::UserFindQuery" => { "allowed_callers" => [] }
          }
        },
        manifest
      )
    end
  end

  def test_update_package_api_preserves_existing_allowed_callers
    Dir.mktmpdir("torikago-package-api-updater") do |module_root|
      package_api_dir = File.join(module_root, "app/package_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      File.write(File.join(package_api_dir, "user_create_command.rb"), "")
      File.write(
        File.join(module_root, "package_api.yml"),
        <<~YAML
          exports:
            Foo::UserCreateCommand:
              allowed_callers:
                - bar
        YAML
      )

      configuration = Torikago::Configuration.new
      configuration.register(:foo, root: module_root)

      Torikago::PackageApiUpdater.new(configuration: configuration).call(:foo)
      manifest = YAML.safe_load(File.read(File.join(module_root, "package_api.yml")))

      assert_equal ["bar"], manifest.dig("exports", "Foo::UserCreateCommand", "allowed_callers")
    end
  end

  def test_update_package_api_uses_a_configured_entrypoint_directory
    Dir.mktmpdir("torikago-package-api-updater") do |module_root|
      package_api_dir = File.join(module_root, "components/public_api/foo")
      FileUtils.mkdir_p(package_api_dir)

      File.write(File.join(package_api_dir, "user_create_command.rb"), "")

      configuration = Torikago::Configuration.new
      configuration.register(:foo, root: module_root, entrypoint: "components/public_api")

      Torikago::PackageApiUpdater.new(configuration: configuration).call(:foo)
      manifest = YAML.safe_load(File.read(File.join(module_root, "package_api.yml")))

      assert_equal(
        { "allowed_callers" => [] },
        manifest.dig("exports", "Foo::UserCreateCommand")
      )
    end
  end

  def test_update_package_api_does_not_scan_parent_when_configured_entrypoint_directory_is_missing
    Dir.mktmpdir("torikago-package-api-updater") do |module_root|
      FileUtils.mkdir_p(File.join(module_root, "app/models/foo"))
      File.write(File.join(module_root, "app/models/foo/widget.rb"), "")

      configuration = Torikago::Configuration.new
      configuration.register(:foo, root: module_root, entrypoint: "app/package_api")

      Torikago::PackageApiUpdater.new(configuration: configuration).call(:foo)
      manifest = YAML.safe_load(File.read(File.join(module_root, "package_api.yml")))

      assert_equal({ "exports" => {} }, manifest)
    end
  end
end
