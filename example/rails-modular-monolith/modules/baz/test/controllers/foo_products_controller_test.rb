require_relative "../../../../test/test_helper"

class Baz::FooProductsControllerTest < ActionDispatch::IntegrationTest
  test "index can call foo product package API through its declared dependency" do
    get "/baz/foo-products"

    assert_response :success
    assert_select "h1", text: "/baz/foo-products"
    assert_select "li", text: "coffee-beans: Coffee Beans"
    assert_select "li", text: "drip-bag: Drip Bag"
  end
end
