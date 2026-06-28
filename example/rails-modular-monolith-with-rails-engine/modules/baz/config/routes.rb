Baz::Engine.routes.draw do
  get "showcase" => "baz/showcase#show"
  get "foo-products" => "baz/foo_products#index"
end
