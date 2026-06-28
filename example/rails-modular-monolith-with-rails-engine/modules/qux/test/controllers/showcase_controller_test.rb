require_relative "../../../../test/test_helper"

class Qux::ShowcaseControllerTest < ActionDispatch::IntegrationTest
  test "show renders from a non-engine module route" do
    get "/qux/showcase"

    assert_response :success
    assert_select "h1", text: "/qux/showcase"
    assert_select "pre", text: "quxbox"
  end
end
