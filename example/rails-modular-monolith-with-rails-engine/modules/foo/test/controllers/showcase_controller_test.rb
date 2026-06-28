require_relative "../../../../test/test_helper"

class Foo::ShowcaseControllerTest < ActionDispatch::IntegrationTest
  test "show runs with its box-local String monkey patch" do
    get "/foo/showcase"

    assert_response :success
    assert_select "h1", text: "/foo/showcase"
    assert_select "pre", /torikago.*༼;´༎ຶ ۝ ༎ຶ༽.*box/m
  end
end
