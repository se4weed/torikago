class Foo::ShowcaseController < ApplicationController
  def show
    @dangerous_banner = Torikago::Gateway.invoke("Foo::DangerousAsciiArtQuery", :call)
  end
end
