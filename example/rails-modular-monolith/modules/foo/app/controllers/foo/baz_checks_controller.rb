class Foo::BazChecksController < ApplicationController
  def show
    @baz_banner = Torikago::CurrentExecution.with_box(:foo) do
      Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)
    end
  end
end
