Foo::Engine.routes.draw do
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
end
