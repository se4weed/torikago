class Bar::ShowcaseController < ApplicationController
  def show
    @plain_banner = Torikago::Gateway.call("Bar::SafeBannerQuery")
  end
end
