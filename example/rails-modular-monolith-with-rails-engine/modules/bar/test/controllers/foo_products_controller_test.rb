require_relative "../../../../test/test_helper"

class Bar::FooProductsControllerTest < ActionDispatch::IntegrationTest
  test "index raises a dependency boundary error when it calls foo products" do
    error = assert_raises(Torikago::DependencyError) do
      get "/bar/foo-products"
    end

    assert_equal "module dependency not allowed: bar -> foo#Foo::ListProductsQuery", error.message
  end
end
