require_relative "../../../../test/test_helper"

class BarShowcaseControllerTest < ActionDispatch::IntegrationTest
  test "show is isolated from foo setup side effects" do
    get "/bar/showcase"

    assert_response :success
    assert_select "h1", text: "/bar/showcase"
    assert_select ".jpostcode-version", text: "1.0.0.20260507"
    assert_select "pre", text: "torikagobox"
    refute_includes response.body, "༼;´༎ຶ ۝ ༎ຶ༽"
  end
end
