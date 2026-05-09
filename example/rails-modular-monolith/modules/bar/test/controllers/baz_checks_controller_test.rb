require_relative "../../../../test/test_helper"

class Bar::BazChecksControllerTest < ActionDispatch::IntegrationTest
  test "show renders a dependency boundary error when it calls baz" do
    get "/bar/baz-check"

    assert_response :success
    assert_select "h1", text: "/bar/baz-check"
    assert_select "p", /rejected by the dependency boundary/
    assert_select "pre", text: "module dependency not allowed: bar -> baz#Baz::SafeBannerQuery"
  end
end
