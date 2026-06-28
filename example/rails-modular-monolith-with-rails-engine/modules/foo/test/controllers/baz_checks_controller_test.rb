require_relative "../../../../test/test_helper"

class Foo::BazChecksControllerTest < ActionDispatch::IntegrationTest
  test "show can call baz package API through its declared dependency" do
    get "/foo/baz-check"

    assert_response :success
    assert_select "h1", text: "/foo/baz-check"
    assert_select "p code", text: "Baz::SafeBannerQuery"
    assert_select "pre", text: "bazbox"
  end
end
