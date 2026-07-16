require_relative "../test_helper"

class TorikagoGatewayTest < Minitest::Test
  FakeContainer = Struct.new(:invocations) do
    def invoke(public_api_class_name, method_name, **arguments)
      invocations << [public_api_class_name, method_name, arguments]
      "result for #{public_api_class_name}##{method_name}"
    end
  end

  class FakeRegistry
    attr_reader :resolved

    def initialize(containers)
      @containers = containers
      @resolved = Array.new
    end

    def resolve(name)
      normalized_name = name.to_sym
      resolved << normalized_name
      @containers.fetch(normalized_name)
    end
  end

  def test_class_level_build_and_invoke_delegate_to_the_shared_gateway
    original_gateway = Torikago.instance_variable_get(:@gateway)
    fake_gateway = Object.new
    calls = Array.new
    fake_gateway.define_singleton_method(:build) { |*args, **kwargs| calls << [:build, args, kwargs]; "build" }
    fake_gateway.define_singleton_method(:invoke) { |*args, **kwargs| calls << [:invoke, args, kwargs]; "invoke" }
    Torikago.instance_variable_set(:@gateway, fake_gateway)

    assert_equal "build", Torikago::Gateway.build("Foo::Query", 1, page: 2)
    assert_equal "invoke", Torikago::Gateway.invoke("Foo::Query", :execute!, 3, force: true)
    assert_equal(
      [
        [:build, ["Foo::Query", 1], { page: 2 }],
        [:invoke, ["Foo::Query", :execute!, 3], { force: true }]
      ],
      calls
    )
  ensure
    Torikago.instance_variable_set(:@gateway, original_gateway)
  end

  def test_build_holds_constructor_arguments_until_invoke
    gateway, registry, container = build_gateway

    invocation = gateway.build("Foo::ProductQuery", 10, page: 2)

    assert_empty registry.resolved
    result = invocation.invoke(:execute!, 20, force: true)

    assert_equal "result for Foo::ProductQuery#execute!", result
    assert_equal [:foo], registry.resolved
    assert_equal(
      [
        [
          "Foo::ProductQuery",
          :execute!,
          {
            constructor_args: [10],
            constructor_kwargs: { page: 2 },
            method_args: [20],
            method_kwargs: { force: true }
          }
        ]
      ],
      container.invocations
    )
  end

  def test_invoke_dispatches_with_an_argumentless_constructor
    gateway, registry, container = build_gateway

    gateway.invoke("Foo::ProductQuery", :execute!, 20, force: true)

    assert_equal [:foo], registry.resolved
    assert_equal [], container.invocations.first[2].fetch(:constructor_args)
    assert_equal({}, container.invocations.first[2].fetch(:constructor_kwargs))
    assert_equal [20], container.invocations.first[2].fetch(:method_args)
    assert_equal({ force: true }, container.invocations.first[2].fetch(:method_kwargs))
  end

  def test_gateway_does_not_expose_call
    gateway, = build_gateway

    refute_respond_to Torikago::Gateway, :call
    refute_respond_to gateway, :call
  end

  def test_invoke_rejects_a_class_not_declared_in_the_manifest_before_resolving
    gateway, registry = build_gateway(exports: Hash.new)

    error = assert_raises(Torikago::PublicApiError) do
      gateway.invoke("Foo::MissingCommand", :execute!)
    end

    assert_match(/Foo::MissingCommand#execute!/, error.message)
    assert_empty registry.resolved
  end

  def test_invoke_rejects_a_method_not_declared_in_the_manifest_before_resolving
    gateway, registry = build_gateway

    error = assert_raises(Torikago::PublicApiError) do
      gateway.invoke("Foo::ProductQuery", :delete_all!)
    end

    assert_equal "package api method is not exported: Foo::ProductQuery#delete_all!", error.message
    assert_empty registry.resolved
  end

  def test_invoke_rejects_manifest_entries_without_methods
    gateway, registry = build_gateway(
      exports: { "Foo::ProductQuery" => { "allowed_callers" => [] } }
    )

    error = assert_raises(Torikago::PublicApiError) do
      gateway.invoke("Foo::ProductQuery", :execute!)
    end

    assert_match(/methods are not configured/, error.message)
    assert_empty registry.resolved
  end

  def test_invoke_rejects_manifest_entries_with_empty_methods
    gateway, registry = build_gateway(
      exports: { "Foo::ProductQuery" => { "methods" => [], "allowed_callers" => [] } }
    )

    assert_raises(Torikago::PublicApiError) do
      gateway.invoke("Foo::ProductQuery", :execute!)
    end
    assert_empty registry.resolved
  end

  def test_invoke_allows_the_host_app_without_allowed_callers
    gateway, _, container = build_gateway

    gateway.invoke("Foo::ProductQuery", :execute!)

    assert_equal 1, container.invocations.size
  end

  def test_invoke_allows_the_target_module_to_call_itself
    gateway, _, container = build_gateway

    Torikago::CurrentExecution.with_box(:foo) do
      gateway.invoke("Foo::ProductQuery", :execute!)
    end

    assert_equal 1, container.invocations.size
  end

  def test_invoke_allows_a_declared_cross_module_caller
    gateway, _, container = build_gateway(allowed_callers: ["bar"])

    Torikago::CurrentExecution.with_box(:bar) do
      gateway.invoke("Foo::ProductQuery", :execute!)
    end

    assert_equal 1, container.invocations.size
  end

  def test_invoke_rejects_an_undeclared_cross_module_caller_before_resolving
    gateway, registry = build_gateway(allowed_callers: ["admin"])

    error = assert_raises(Torikago::DependencyError) do
      Torikago::CurrentExecution.with_box(:bar) do
        gateway.invoke("Foo::ProductQuery", :execute!)
      end
    end

    assert_match(/bar -> foo#Foo::ProductQuery#execute!/, error.message)
    assert_empty registry.resolved
  end

  private

  def build_gateway(allowed_callers: [], exports: nil)
    configuration = Torikago::Configuration.new
    configuration.register(:foo, root: "/modules/foo")
    container = FakeContainer.new(Array.new)
    registry = FakeRegistry.new(foo: container)
    exports ||= {
      "Foo::ProductQuery" => {
        "methods" => ["execute!"],
        "allowed_callers" => allowed_callers
      }
    }
    gateway = Torikago::Gateway.new(
      registry: registry,
      configuration: configuration,
      manifest_loader: ->(_definition) { { "exports" => exports } }
    )

    [gateway, registry, container]
  end
end
