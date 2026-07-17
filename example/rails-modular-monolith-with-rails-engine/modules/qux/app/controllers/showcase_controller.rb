class ShowcaseController < Qux::ApplicationController
  def show
    @current_box = Torikago::CurrentExecution.current_box
    @plain_banner = Torikago::Gateway.invoke("Qux::SafeBannerQuery", :call)
  end
end
