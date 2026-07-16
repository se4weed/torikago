class Bar::FooProductsController < ApplicationController
  def index
    @products = Torikago::CurrentExecution.with_box(:bar) do
      Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)
    end
  end
end
