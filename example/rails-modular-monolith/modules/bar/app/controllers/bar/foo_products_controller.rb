class Bar::FooProductsController < ApplicationController
  def index
    @products = Torikago::CurrentExecution.with_box(:bar) do
      Torikago::Gateway.call("Foo::ListProductsQuery")
    end
  end
end
