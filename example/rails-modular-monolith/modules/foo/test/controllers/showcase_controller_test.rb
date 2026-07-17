require_relative "../../../../test/test_helper"

class FooShowcaseControllerTest < ActionDispatch::IntegrationTest
  test "show uses its box-local gems and String monkey patch" do
    get "/foo/showcase"

    assert_response :success
    assert_select "h1", text: "/foo/showcase"
    assert_select ".jpostcode-version", text: "1.0.0.20250901"
    assert_select "pre", /torikago.*༼;´༎ຶ ۝ ༎ຶ༽.*box/m
  end
end
