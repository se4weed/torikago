class Baz::FooProductsController < Baz::ApplicationController
  def index
    @products = Torikago::CurrentExecution.with_box(:baz) do
      Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)
    end
  end
end
