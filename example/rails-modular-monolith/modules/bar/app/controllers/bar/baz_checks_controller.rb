class Bar::BazChecksController < ApplicationController
  def show
    @dependency_error = begin
      Torikago::CurrentExecution.with_box(:bar) do
        Torikago::Gateway.call("Baz::SafeBannerQuery")
      end

      nil
    rescue Torikago::DependencyError => error
      error
    end
  end
end
