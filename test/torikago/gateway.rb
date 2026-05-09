require_relative "../test_helper"
require "fileutils"
require "tmpdir"

class TorikagoGatewayTest < Minitest::Test
  FakeContainer = Struct.new(:calls) do
    def call(public_api_class_name, *args, **kwargs)
      calls << [public_api_class_name, args, kwargs]
      "result for #{public_api_class_name}"
    end
  end

  class FakeRegistry
    def initialize(containers)
      @containers = containers
      @resolved = []
    end

    attr_reader :resolved

    def resolve(name)
      normalized_name = name.to_sym
      resolved << normalized_name
      @containers.fetch(normalized_name)
    end
  end

  def test_class_level_call_delegates_to_the_shared_gateway
    original_gateway = Torikago.instance_variable_get(:@gateway)
    fake_gateway = Object.new
    called_with = nil

    fake_gateway.define_singleton_method(:call) do |*args, **kwargs|
      called_with = [args, kwargs]
      "ok"
    end

    Torikago.instance_variable_set(:@gateway, fake_gateway)

    result = Torikago::Gateway.call("Foo::ListProductsQuery", page: 1)

    assert_equal "ok", result
    assert_equal [["Foo::ListProductsQuery"], { page: 1 }], called_with
  ensure
    Torikago.instance_variable_set(:@gateway, original_gateway)
  end

  def test_call_delegates_to_the_target_module_container
    configuration = Torikago::Configuration.new
    configuration.register(:foo, root: "/modules/foo")
    write_package_api_manifest("/modules/foo", "Foo::ListProductsQuery" => { "allowed_callers" => [] })

    container = FakeContainer.new([])
    registry = FakeRegistry.new(foo: container)
    gateway = Torikago::Gateway.new(
      registry: registry,
      configuration: configuration,
      manifest_loader: ->(_definition) { { "exports" => { "Foo::ListProductsQuery" => { "allowed_callers" => [] } } } }
    )

    result = gateway.call("Foo::ListProductsQuery", page: 1)

    assert_equal "result for Foo::ListProductsQuery", result
    assert_equal [:foo], registry.resolved
    assert_equal [["Foo::ListProductsQuery", [], { page: 1 }]], container.calls
  end

  def test_call_rejects_public_api_not_declared_in_package_api_manifest
    configuration = Torikago::Configuration.new
    configuration.register(:foo, root: "/modules/foo")
    registry = FakeRegistry.new(foo: FakeContainer.new([]))
    gateway = Torikago::Gateway.new(
      registry: registry,
      configuration: configuration,
      manifest_loader: ->(_definition) { { "exports" => {} } }
    )

    error = assert_raises(Torikago::PublicApiError) do
      gateway.call("Foo::MissingCommand")
    end

    assert_match(/Foo::MissingCommand/, error.message)
  end

  def test_call_allows_host_app_invocation_without_allowed_callers
    configuration = Torikago::Configuration.new
    configuration.register(:foo, root: "/modules/foo")
    container = FakeContainer.new([])
    registry = FakeRegistry.new(foo: container)
    gateway = Torikago::Gateway.new(
      registry: registry,
      configuration: configuration,
      manifest_loader: ->(_definition) { { "exports" => { "Foo::ListProductsQuery" => { "allowed_callers" => [] } } } }
    )

    gateway.call("Foo::ListProductsQuery")

    assert_equal [["Foo::ListProductsQuery", [], {}]], container.calls
  end

  def test_call_allows_box_dependency_declared_in_package_api_manifest
    configuration = Torikago::Configuration.new
    configuration.register(:foo, root: "/modules/foo")
    configuration.register(:bar, root: "/modules/bar")
    bar_container = FakeContainer.new([])
    registry = FakeRegistry.new(foo: FakeContainer.new([]), bar: bar_container)

    gateway = Torikago::Gateway.new(
      registry: registry,
      configuration: configuration,
      manifest_loader: lambda do |definition|
        if definition.name == :bar
          { "exports" => { "Bar::SubmitOrderCommand" => { "allowed_callers" => ["foo"] } } }
        else
          { "exports" => {} }
        end
      end
    )

    Torikago::CurrentExecution.with_box(:foo) do
      result = gateway.call("Bar::SubmitOrderCommand", order_id: 1)

      assert_equal "result for Bar::SubmitOrderCommand", result
    end

    assert_equal [["Bar::SubmitOrderCommand", [], { order_id: 1 }]], bar_container.calls
  end

  def test_call_rejects_box_dependency_not_declared_in_package_api_manifest
    configuration = Torikago::Configuration.new
    configuration.register(:foo, root: "/modules/foo")
    configuration.register(:bar, root: "/modules/bar")
    registry = FakeRegistry.new(foo: FakeContainer.new([]), bar: FakeContainer.new([]))

    gateway = Torikago::Gateway.new(
      registry: registry,
      configuration: configuration,
      manifest_loader: ->(_definition) { { "exports" => { "Bar::SubmitOrderCommand" => { "allowed_callers" => ["admin"] } } } }
    )

    error = assert_raises(Torikago::DependencyError) do
      Torikago::CurrentExecution.with_box(:foo) do
        gateway.call("Bar::SubmitOrderCommand")
      end
    end

    assert_match(/foo/, error.message)
    assert_match(/bar/i, error.message)
  end

  private

  def write_package_api_manifest(_root, _entries)
  end
end
