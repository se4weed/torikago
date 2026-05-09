require_relative "../../../../test/test_helper"

class Baz::ShowcaseControllerTest < ActionDispatch::IntegrationTest
  test "show renders from its own box" do
    get "/baz/showcase"

    assert_response :success
    assert_select "h1", text: "/baz/showcase"
    assert_select "pre", text: "bazbox"
  end
end
