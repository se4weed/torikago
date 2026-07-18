class Bar::BazChecksController < Bar::ApplicationController
  def show
    @dependency_error = begin
      Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)

      nil
    rescue Torikago::DependencyError => error
      error
    end
  end
end
