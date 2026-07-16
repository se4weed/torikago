class Bar::ShowcaseController < Bar::ApplicationController
  def show
    @plain_banner = Torikago::Gateway.invoke("Bar::SafeBannerQuery", :call)
  end
end
