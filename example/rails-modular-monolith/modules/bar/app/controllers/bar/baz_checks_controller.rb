class Bar::BazChecksController < ApplicationController
  def show
    @dependency_error = begin
      Torikago::CurrentExecution.with_box(:bar) do
        Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)
      end

      nil
    rescue Torikago::DependencyError => error
      error
    end
  end
end
