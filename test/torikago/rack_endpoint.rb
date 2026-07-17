require_relative "../test_helper"

class TorikagoRackEndpointTest < Minitest::Test
  def test_call_resolves_and_dispatches_to_the_registered_module
    received_env = nil
    container = Object.new
    container.define_singleton_method(:call) do |env|
      received_env = env
      [204, {}, []]
    end

    registry = Object.new
    registry.define_singleton_method(:resolve) do |name|
      raise "unexpected module: #{name}" unless name == :foo

      container
    end

    endpoint = Torikago::RackEndpoint.new("foo", registry: registry)
    env = { "PATH_INFO" => "/widgets" }

    assert_equal [204, {}, []], endpoint.call(env)
    assert_same env, received_env
  end
end
