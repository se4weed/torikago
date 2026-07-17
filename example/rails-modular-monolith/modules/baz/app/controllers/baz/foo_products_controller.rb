class Baz::FooProductsController < Baz::ApplicationController
  def index
    @products = Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)
  end
end
