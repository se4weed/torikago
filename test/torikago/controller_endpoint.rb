require_relative "../test_helper"
require "open3"
require "rbconfig"

class TorikagoControllerEndpointTest < Minitest::Test
  def test_direct_construction_warns_once_without_per_request_warnings
    warning = endpoint_warning(<<~RUBY)
      container = Object.new
      def container.dispatch_controller(env, controller_name:, action_name:)
        [200, {}, ["ok"]]
      end
      registry = Object.new
      registry.define_singleton_method(:resolve) { |name| container }
      endpoint = Torikago::ControllerEndpoint.new(
        :foo, "Foo::WidgetsController", :show, registry: registry
      )
      2.times { endpoint.call({}) }
    RUBY

    assert_includes warning, "[DEPRECATION]"
    assert_includes warning, "Torikago::ControllerEndpoint"
    assert_includes warning, "rails_engine: true"
    assert_includes warning, "Torikago::RackEndpoint"
    assert_includes warning, "Gateway-only modules do not require Rails::Engine"
    assert_equal 1, warning.lines.size
  end

  def test_action_warns_once_and_returns_a_compatible_endpoint
    warning = endpoint_warning(<<~RUBY)
      endpoint = Torikago.action(:foo, "Foo::WidgetsController", :show)
      raise "unexpected endpoint" unless endpoint.is_a?(Torikago::ControllerEndpoint)
    RUBY

    assert_includes warning, "Torikago.action"
    assert_equal 1, warning.lines.size
  end

  def test_call_dispatches_to_a_box_owned_controller
    received = nil
    container = Object.new
    container.define_singleton_method(:dispatch_controller) do |env, controller_name:, action_name:|
      received = [env, controller_name, action_name]
      [200, { "content-type" => "text/plain" }, ["ok"]]
    end

    registry = Object.new
    registry.define_singleton_method(:resolve) do |name|
      raise "unexpected module: #{name}" unless name == :foo

      container
    end

    endpoint = Torikago::ControllerEndpoint.new(
      "foo",
      "WidgetsController",
      "show",
      registry: registry
    )
    env = { "PATH_INFO" => "/widgets/7" }

    assert_equal [200, { "content-type" => "text/plain" }, ["ok"]], endpoint.call(env)
    assert_equal [env, "WidgetsController", :show], received
  end

  private

  # Capture at the process boundary: Ruby::Box has its own stderr objects.
  def endpoint_warning(script)
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__),
      "-rtorikago", "-e", script
    )
    assert_predicate status, :success?, stderr
    assert_empty stdout
    # Ruby itself prints an experimental-feature notice when Box is enabled.
    stderr.lines.reject { |line| line.include?("Ruby::Box is experimental") || line.start_with?("See https://docs.ruby-lang.org/") }.join
  end
end
