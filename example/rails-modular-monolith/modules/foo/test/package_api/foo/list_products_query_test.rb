require_relative "../../../../../test/test_helper"

class Foo::ListProductsQueryTest < ActiveSupport::TestCase
  test "call returns the public product list" do
    result = Torikago::Gateway.call("Foo::ListProductsQuery")

    assert_equal [
      { "id" => "coffee-beans", "name" => "Coffee Beans" },
      { "id" => "drip-bag", "name" => "Drip Bag" }
    ], result
  end
end
