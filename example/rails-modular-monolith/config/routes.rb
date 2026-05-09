Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root to: "catalog#showcase"

  get "gem-versions" => "gem_versions#show"
  get "jwt-checks" => "foo/jwt_checks#show"

  resources :addresses, only: [:index], controller: "foo/addresses" do
    collection do
      post :search
    end
  end

  scope path: "foo" do
    get "showcase" => "foo/showcase#show"
    get "products" => "foo/products#index"
    get "baz-check" => "foo/baz_checks#show"
  end

  scope path: "bar" do
    get "showcase" => "bar/showcase#show"
    get "foo-products" => "bar/foo_products#index"
    get "baz-check" => "bar/baz_checks#show"
  end

  scope path: "baz" do
    get "showcase" => "baz/showcase#show"
    get "foo-products" => "baz/foo_products#index"
  end
end
