require "test_helper"

class PackageApiEagerLoadTest < ActiveSupport::TestCase
  test "engine package APIs are autoloaded but not host eager loaded" do
    [Foo::Engine, Bar::Engine, Baz::Engine].each do |engine|
      package_api_path = engine.root.join("app/package_api").to_s

      assert_includes engine.config.autoload_paths, package_api_path
      refute_includes engine.config.eager_load_paths, package_api_path
    end
  end

  test "module-only gems are not visible from the main box" do
    assert_raises(LoadError) { require "jpostcode" }
  end
end
