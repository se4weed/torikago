require_relative "../test_helper"
require "fileutils"
require "tmpdir"

class TorikagoRootConstantResolverTest < Minitest::Test
  def teardown
    Object.send(:remove_const, :RootResolverVisibleConstant) if Object.const_defined?(:RootResolverVisibleConstant, false)
    Object.send(:remove_const, :RootResolverRegisteredConstant) if Object.const_defined?(:RootResolverRegisteredConstant, false)
  end

  def test_resolve_returns_main_constant_defined_outside_registered_roots
    Dir.mktmpdir("torikago-root-resolver") do |application_root|
      registered_root = File.join(application_root, "modules/foo")
      FileUtils.mkdir_p(registered_root)
      root_file = File.join(application_root, "app_root_constant.rb")
      File.write(root_file, "class RootResolverVisibleConstant; end\n")
      load root_file

      resolver = Torikago::RootConstantResolver.new(
        registered_roots: [registered_root],
        main_box: Object
      )

      assert_same RootResolverVisibleConstant, resolver.resolve(:RootResolverVisibleConstant)
    end
  end

  def test_resolve_rejects_constants_defined_below_any_registered_root
    Dir.mktmpdir("torikago-root-resolver") do |application_root|
      registered_root = File.join(application_root, "packs/foo")
      FileUtils.mkdir_p(registered_root)
      registered_file = File.join(registered_root, "registered_constant.rb")
      File.write(registered_file, "class RootResolverRegisteredConstant; end\n")
      load registered_file

      resolver = Torikago::RootConstantResolver.new(
        registered_roots: [registered_root],
        main_box: Object
      )

      assert_same resolver.unresolved, resolver.resolve(:RootResolverRegisteredConstant)
    end
  end

  def test_resolve_returns_unresolved_for_an_unknown_constant
    resolver = Torikago::RootConstantResolver.new(
      registered_roots: [],
      main_box: Object
    )

    assert_same resolver.unresolved, resolver.resolve(:RootResolverMissingConstant)
  end
end
