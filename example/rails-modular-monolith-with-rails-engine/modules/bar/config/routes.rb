Bar::Engine.routes.draw do
  get "showcase" => "bar/showcase#show"
  get "foo-products" => "bar/foo_products#index"
  get "baz-check" => "bar/baz_checks#show"
end
