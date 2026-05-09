require_relative "../../../../test/test_helper"

class Foo::ProductsControllerTest < ActionDispatch::IntegrationTest
  EXPECTED_PRODUCTS = [
    { "id" => "coffee-beans", "name" => "Coffee Beans" },
    { "id" => "drip-bag", "name" => "Drip Bag" }
  ].freeze

  test "index returns the package API result as JSON" do
    get "/foo/products"

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal({ "data" => EXPECTED_PRODUCTS }, response.parsed_body)
  end
end
