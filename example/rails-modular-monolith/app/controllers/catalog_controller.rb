class CatalogController < ApplicationController
  def showcase
    @links = [
      {
        path: "/foo/showcase",
        title: "Foo showcase",
        description: "Shows that the String#+ monkey patch installed by the foo box setup only affects code running inside that box."
      },
      {
        path: "/bar/showcase",
        title: "Bar showcase",
        description: "Shows that the bar box does not inherit the foo monkey patch and runs behind a separate runtime boundary."
      },
      {
        path: "/baz/showcase",
        title: "Baz showcase",
        description: "Shows baz box behavior and the explicit dependency path it is allowed to use."
      },
      {
        path: "/foo/products",
        title: "Foo products API",
        description: "Returns the foo product list as JSON through Foo::ListProductsQuery."
      },
      {
        path: "/foo/baz-check",
        title: "Foo -> Baz package API",
        description: "Calls Baz::SafeBannerQuery from the foo box to show an allowed package API dependency."
      },
      {
        path: "/bar/baz-check",
        title: "Bar -> Baz package API rejection",
        description: "Calls Baz::SafeBannerQuery from the bar box and shows the denied package API dependency."
      },
      {
        path: "/baz/foo-products",
        title: "Baz -> Foo products",
        description: "Calls the allowed Foo::ListProductsQuery from the baz box and renders the gateway result."
      },
      {
        path: "/bar/foo-products",
        title: "Bar -> Foo products rejection",
        description: "Attempts to call an unauthorized foo API from the bar box and shows the dependency boundary rejection."
      },
      {
        path: "/addresses",
        title: "Address lookup",
        description: "Compares the same postal code across different jpostcode versions loaded inside the foo and bar boxes."
      },
      {
        path: "/jwt-checks",
        title: "JWT compatibility checks",
        description: "Checks JWT versions and API compatibility across the main app, foo box, and bar box."
      },
      {
        path: "/gem-versions",
        title: "Gem version boundaries",
        description: "Shows module-local gem versions and upgrade boundaries worth testing with runtime isolation."
      }
    ]
  end

  def products
    render json: {
      data: Torikago::Gateway.call("Foo::ListProductsQuery")
    }
  end
end
