class Foo::ShowcaseController < Foo::ApplicationController
  def show
    @dangerous_banner = Torikago::Gateway.call("Foo::DangerousAsciiArtQuery")
  end
end
