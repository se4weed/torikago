class Qux::ShowcaseController < ApplicationController
  def show
    @plain_banner = Torikago::Gateway.call("Qux::SafeBannerQuery")
  end
end
