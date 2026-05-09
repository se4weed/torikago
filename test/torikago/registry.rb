require_relative "../test_helper"

class TorikagoRegistryTest < Minitest::Test
  def setup
    @configuration = Torikago::Configuration.new
    @configuration.register(
      :foo,
      root: "/modules/foo",
      entrypoint: "lib/foo/box_runtime.rb",
      setup: "config/box_setup.rb",
      gemfile: "Gemfile"
    )
  end

  def test_resolve_returns_a_container_for_a_registered_module
    registry = Torikago::Registry.new(configuration: @configuration) do |definition|
      {
        name: definition.name,
        root: definition.root.to_s,
        entrypoint: definition.entrypoint,
        setup: definition.setup,
        gemfile: definition.gemfile
      }
    end

    container = registry.resolve(:foo)

    assert_equal :foo, container[:name]
    assert_equal "/modules/foo", container[:root]
    assert_equal "lib/foo/box_runtime.rb", container[:entrypoint]
    assert_equal "config/box_setup.rb", container[:setup]
    assert_equal "Gemfile", container[:gemfile]
  end

  def test_resolve_reuses_the_same_container_for_the_same_module
    build_count = 0

    registry = Torikago::Registry.new(configuration: @configuration) do |_definition|
      build_count += 1
      Object.new
    end

    first = registry.resolve(:foo)
    second = registry.resolve("foo")

    assert_same first, second
    assert_equal 1, build_count
  end

  def test_resolve_fails_clearly_for_an_unknown_module
    registry = Torikago::Registry.new(configuration: @configuration) do |_definition|
      Object.new
    end

    error = assert_raises(KeyError) do
      registry.resolve(:missing)
    end

    assert_match(/missing/, error.message)
  end

  def test_resolve_uses_the_container_factory_not_the_gateway
    captured_definition = nil

    registry = Torikago::Registry.new(configuration: @configuration) do |definition|
      captured_definition = definition
      Object.new
    end

    registry.resolve(:foo)

    refute_nil captured_definition
    assert_equal :foo, captured_definition.name
  end

  def test_resolve_builds_an_engine_container_by_default
    registry = Torikago::Registry.new(configuration: @configuration)

    container = registry.resolve(:foo)

    assert_instance_of Torikago::EngineContainer, container
  end
end
