class Foo::ShowcaseController < Foo::ApplicationController
  def show
    @dangerous_banner = Torikago::Gateway.invoke("Foo::DangerousAsciiArtQuery", :call)
  end
end
