class Bar::ShowcaseController < Bar::ApplicationController
  def show
    @jpostcode_version = Jpostcode::VERSION
    @plain_banner = Torikago::Gateway.invoke("Bar::SafeBannerQuery", :call)
  end
end
