class Baz::ShowcaseController < Baz::ApplicationController
  def show
    @plain_banner = Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)
  end
end
