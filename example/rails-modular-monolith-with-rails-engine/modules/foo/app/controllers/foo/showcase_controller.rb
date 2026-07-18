class Foo::ShowcaseController < Foo::ApplicationController
  def show
    @jpostcode_version = Jpostcode::VERSION
    @dangerous_banner = Torikago::Gateway.invoke("Foo::DangerousAsciiArtQuery", :call)
  end
end
