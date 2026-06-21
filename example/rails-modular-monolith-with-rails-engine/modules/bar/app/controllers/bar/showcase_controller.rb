class Bar::ShowcaseController < Bar::ApplicationController
  def show
    @plain_banner = Torikago::Gateway.call("Bar::SafeBannerQuery")
  end
end
