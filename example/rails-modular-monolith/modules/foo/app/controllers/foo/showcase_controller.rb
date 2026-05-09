class Foo::ShowcaseController < ApplicationController
  def show
    @dangerous_banner = Torikago::Gateway.call("Foo::DangerousAsciiArtQuery")
  end
end
