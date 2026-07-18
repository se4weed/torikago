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
  get "jwt-checks" => Torikago.action(:foo, "Foo::JwtChecksController", :show)

  get "addresses" => Torikago.action(:foo, "Foo::AddressesController", :index),
      as: :addresses
  post "addresses/search" => Torikago.action(:foo, "Foo::AddressesController", :search),
       as: :search_addresses

  get "foo/showcase" => Torikago.action(:foo, "Foo::ShowcaseController", :show)
  get "foo/products" => Torikago.action(:foo, "Foo::ProductsController", :index)
  get "foo/baz-check" => Torikago.action(:foo, "Foo::BazChecksController", :show)

  get "bar/showcase" => Torikago.action(:bar, "Bar::ShowcaseController", :show)
  get "bar/foo-products" => Torikago.action(:bar, "Bar::FooProductsController", :index)
  get "bar/baz-check" => Torikago.action(:bar, "Bar::BazChecksController", :show)

  get "baz/showcase" => Torikago.action(:baz, "Baz::ShowcaseController", :show)
  get "baz/foo-products" => Torikago.action(:baz, "Baz::FooProductsController", :index)
end
