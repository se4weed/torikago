require_relative "../../../../../test/test_helper"

class Foo::ListProductsQueryTest < ActiveSupport::TestCase
  test "call returns the public product list" do
    result = Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)

    assert_equal [
      { "id" => "coffee-beans", "name" => "Coffee Beans" },
      { "id" => "drip-bag", "name" => "Drip Bag" }
    ], result
  end

  test "build sends constructor arguments separately from execute arguments" do
    result = Torikago::Gateway
      .build("Foo::ListProductsQuery", page: 2)
      .invoke(:execute!, per_page: 1)

    assert_equal [{ "id" => "drip-bag", "name" => "Drip Bag" }], result
  end
end
