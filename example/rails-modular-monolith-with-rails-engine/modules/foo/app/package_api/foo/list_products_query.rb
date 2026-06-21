class Foo::ListProductsQuery
  PRODUCTS = [
    { "id" => "coffee-beans", "name" => "Coffee Beans" },
    { "id" => "drip-bag", "name" => "Drip Bag" }
  ].freeze

  def call
    PRODUCTS
  end
end
