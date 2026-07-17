class Foo::BazChecksController < Foo::ApplicationController
  def show
    @baz_banner = Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)
  end
end
