require "test_helper"

class CatalogControllerTest < ActionDispatch::IntegrationTest
  CATALOG_LINKS = {
    "Foo showcase" => "/foo/showcase",
    "Bar showcase" => "/bar/showcase",
    "Baz showcase" => "/baz/showcase",
    "Foo products API" => "/foo/products",
    "Foo -> Baz package API" => "/foo/baz-check",
    "Bar -> Baz package API rejection" => "/bar/baz-check",
    "Baz -> Foo products" => "/baz/foo-products",
    "Bar -> Foo products rejection" => "/bar/foo-products",
    "Address lookup" => "/addresses",
    "JWT compatibility checks" => "/jwt-checks",
    "Gem version boundaries" => "/gem-versions"
  }.freeze

  test "showcase advertises every demo route by label and path" do
    get "/"

    assert_response :success
    assert_select "h1", text: "Demo catalog"

    CATALOG_LINKS.each do |label, path|
      assert_select "a[href=?]", path, text: label
      assert_select "code", text: path
    end
  end
end
