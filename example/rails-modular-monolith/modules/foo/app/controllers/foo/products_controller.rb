class Foo::ProductsController < ApplicationController
  def index
    render json: {
      data: Torikago::Gateway.call("Foo::ListProductsQuery")
    }
  end
end
