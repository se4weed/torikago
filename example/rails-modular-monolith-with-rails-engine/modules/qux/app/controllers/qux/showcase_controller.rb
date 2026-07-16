class Qux::ShowcaseController < ApplicationController
  def show
    @plain_banner = Torikago::Gateway.invoke("Qux::SafeBannerQuery", :call)
  end
end
