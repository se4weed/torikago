class Foo::BazChecksController < ApplicationController
  def show
    @baz_banner = Torikago::CurrentExecution.with_box(:foo) do
      Torikago::Gateway.call("Baz::SafeBannerQuery")
    end
  end
end
