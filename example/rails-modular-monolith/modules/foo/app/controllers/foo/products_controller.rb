class Foo::ProductsController < ApplicationController
  def index
    render json: {
      data: Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)
    }
  end
end
