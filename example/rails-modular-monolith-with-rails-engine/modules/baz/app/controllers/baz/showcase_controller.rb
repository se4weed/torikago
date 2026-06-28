class Baz::ShowcaseController < Baz::ApplicationController
  def show
    @plain_banner = Torikago::Gateway.call("Baz::SafeBannerQuery")
  end
end
