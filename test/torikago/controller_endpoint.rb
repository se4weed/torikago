require_relative "../test_helper"

class TorikagoControllerEndpointTest < Minitest::Test
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
end
