class Bar::FooProductsController < Bar::ApplicationController
  def index
    @products = Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)
  end
end
