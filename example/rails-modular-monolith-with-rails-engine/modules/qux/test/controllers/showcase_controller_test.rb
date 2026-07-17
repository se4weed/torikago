require_relative "../../../../test/test_helper"

class QuxShowcaseControllerTest < ActionDispatch::IntegrationTest
  test "show runs its controller in the module box without a Rails Engine" do
    get "/qux/showcase"

    assert_response :success
    assert_select "h1", text: "/qux/showcase"
    assert_select ".current-box", text: "qux"
    assert_select "pre", text: "quxbox"
    if Ruby::Box.enabled?
      refute Object.const_defined?(:Qux, false)
      refute Object.const_defined?(:ShowcaseController, false)
    end
  end
end
