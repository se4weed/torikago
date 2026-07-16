class Bar::ShowcaseController < ApplicationController
  def show
    @plain_banner = Torikago::Gateway.invoke("Bar::SafeBannerQuery", :call)
  end
end
