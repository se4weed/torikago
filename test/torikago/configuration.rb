require_relative "../test_helper"

class TorikagoConfigurationTest < Minitest::Test
  def setup
    @configuration = Torikago::Configuration.new
  end

  def test_register_stores_definition_for_a_module
    @configuration.register(
      :foo,
      root: "/modules/foo",
      entrypoint: "lib/foo/box_runtime.rb",
      setup: "config/box_setup.rb",
      gemfile: "Gemfile"
    )

    definition = @configuration.fetch(:foo)

    assert_equal :foo, definition.name
    assert_equal "/modules/foo", definition.root.to_s
    assert_equal "lib/foo/box_runtime.rb", definition.entrypoint
    assert_equal "config/box_setup.rb", definition.setup
    assert_equal "Gemfile", definition.gemfile
  end

  def test_registered_distinguishes_registered_and_unregistered_modules
    @configuration.register(
      :foo,
      root: "/modules/foo",
      entrypoint: "lib/foo/box_runtime.rb"
    )

    assert @configuration.registered?(:foo)
    refute @configuration.registered?(:bar)
  end

  def test_module_names_are_normalized_between_string_and_symbol
    @configuration.register(
      "foo",
      root: "/modules/foo",
      entrypoint: "lib/foo/box_runtime.rb"
    )

    assert @configuration.registered?(:foo)
    assert @configuration.registered?("foo")
    assert_equal :foo, @configuration.fetch("foo").name
  end

  def test_fetch_fails_clearly_for_an_unknown_module
    error = assert_raises(KeyError) do
      @configuration.fetch(:missing)
    end

    assert_match(/missing/, error.message)
  end

  def test_register_rejects_duplicate_module_names
    @configuration.register(
      :foo,
      root: "/modules/foo",
      entrypoint: "lib/foo/box_runtime.rb"
    )

    error = assert_raises(ArgumentError) do
      @configuration.register(
        "foo",
        root: "/modules/another_foo",
        entrypoint: "lib/foo/alternative_runtime.rb"
      )
    end

    assert_match(/foo/, error.message)
  end
end
