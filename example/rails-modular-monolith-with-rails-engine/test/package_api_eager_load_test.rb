require "test_helper"

class PackageApiEagerLoadTest < ActiveSupport::TestCase
  test "engine package APIs are autoloaded but not host eager loaded" do
    [Foo::Engine, Bar::Engine, Baz::Engine].each do |engine|
      package_api_path = engine.root.join("app/package_api")
      package_api_paths = engine.paths["app/package_api"]

      assert_includes package_api_paths.paths, package_api_path
      assert_predicate package_api_paths, :autoload?
      refute_predicate package_api_paths, :eager_load?
    end
  end
end
