class Baz::ShowcaseController < ApplicationController
  def show
    @plain_banner = Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)
  end
end
