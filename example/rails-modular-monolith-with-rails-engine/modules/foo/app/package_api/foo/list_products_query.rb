class Foo::ListProductsQuery
  PRODUCTS = [
    { "id" => "coffee-beans", "name" => "Coffee Beans" },
    { "id" => "drip-bag", "name" => "Drip Bag" }
  ].freeze

  def initialize(page: 1)
    @page = page
  end

  def call
    PRODUCTS
  end

  def execute!(per_page: PRODUCTS.length)
    PRODUCTS.slice((@page - 1) * per_page, per_page) || []
  end
end
