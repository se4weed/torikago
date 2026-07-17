require_relative "../test_helper"
require "fileutils"
require "tmpdir"

class TorikagoRootConstantResolverTest < Minitest::Test
  def teardown
    Object.send(:remove_const, :RootResolverVisibleConstant) if Object.const_defined?(:RootResolverVisibleConstant, false)
    Object.send(:remove_const, :RootResolverRegisteredConstant) if Object.const_defined?(:RootResolverRegisteredConstant, false)
    Object.send(:remove_const, :RootResolverRegisteredAutoload) if Object.const_defined?(:RootResolverRegisteredAutoload, false)
    Object.send(:remove_const, :RootResolverSharedNamespace) if Object.const_defined?(:RootResolverSharedNamespace, false)
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

  def test_resolve_rejects_a_top_level_autoload_from_a_registered_root
    Dir.mktmpdir("torikago-root-resolver") do |application_root|
      registered_root = File.join(application_root, "modules/foo")
      FileUtils.mkdir_p(registered_root)
      registered_file = File.join(registered_root, "registered_autoload.rb")
      File.write(registered_file, "class RootResolverRegisteredAutoload; end\n")
      Object.autoload(:RootResolverRegisteredAutoload, registered_file)

      resolver = Torikago::RootConstantResolver.new(
        registered_roots: [registered_root],
        main_box: Object
      )

      assert_same resolver.unresolved, resolver.resolve(:RootResolverRegisteredAutoload)
      assert_equal registered_file, Object.autoload?(:RootResolverRegisteredAutoload, false)
    end
  end

  def test_resolve_rejects_a_root_namespace_with_a_registered_descendant
    Dir.mktmpdir("torikago-root-resolver") do |application_root|
      registered_root = File.join(application_root, "components/bar")
      FileUtils.mkdir_p(registered_root)
      root_file = File.join(application_root, "shared_namespace.rb")
      registered_file = File.join(registered_root, "internal.rb")
      File.write(root_file, "module RootResolverSharedNamespace; end\n")
      File.write(registered_file, "class RootResolverSharedNamespace::Internal; end\n")
      load root_file
      load registered_file

      resolver = Torikago::RootConstantResolver.new(
        registered_roots: [registered_root],
        main_box: Object
      )

      assert_same resolver.unresolved, resolver.resolve(:RootResolverSharedNamespace)
    end
  end

  def test_resolve_rejects_a_root_namespace_with_a_registered_autoload
    Dir.mktmpdir("torikago-root-resolver") do |application_root|
      registered_root = File.join(application_root, "components/bar")
      FileUtils.mkdir_p(registered_root)
      root_file = File.join(application_root, "shared_namespace.rb")
      registered_file = File.join(registered_root, "autoloaded_internal.rb")
      File.write(root_file, "module RootResolverSharedNamespace; end\n")
      File.write(registered_file, "class RootResolverSharedNamespace::AutoloadedInternal; end\n")
      load root_file
      RootResolverSharedNamespace.autoload(:AutoloadedInternal, registered_file)

      resolver = Torikago::RootConstantResolver.new(
        registered_roots: [registered_root],
        main_box: Object
      )

      assert_same resolver.unresolved, resolver.resolve(:RootResolverSharedNamespace)
      assert_equal registered_file, RootResolverSharedNamespace.autoload?(:AutoloadedInternal, false)
    end
  end
end
