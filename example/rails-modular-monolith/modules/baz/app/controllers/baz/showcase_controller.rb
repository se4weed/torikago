class Baz::ShowcaseController < ApplicationController
  def show
    @plain_banner = Torikago::Gateway.call("Baz::SafeBannerQuery")
  end
end
