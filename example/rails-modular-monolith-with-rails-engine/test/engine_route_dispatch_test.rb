require_relative "test_helper"

class EngineRouteDispatchTest < ActionDispatch::IntegrationTest
  test "a non-controller engine route is served by its Rack endpoint" do
    get "/legacy-showcase"

    assert_redirected_to "/foo/showcase"
  end
end
