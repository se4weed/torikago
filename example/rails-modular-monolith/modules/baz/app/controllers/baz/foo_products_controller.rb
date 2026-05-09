class Baz::FooProductsController < ApplicationController
  def index
    @products = Torikago::CurrentExecution.with_box(:baz) do
      Torikago::Gateway.call("Foo::ListProductsQuery")
    end
  end
end
