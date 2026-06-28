require_relative "../../../../test/test_helper"

class Foo::JwtChecksControllerTest < ActionDispatch::IntegrationTest
  test "show compares main app and module boxes" do
    get "/jwt-checks"

    assert_response :success
    assert_select "h1", text: "JWT Compatibility Checks"
    assert_select "section", count: 3
    assert_select "h2", text: "main app"
    assert_select "h2", text: "foo module"
    assert_select "h2", text: "bar module"
    assert_select "p", text: /JWT version:\s+3\.1\.2/, count: 2
    assert_select "p", text: /JWT version:\s+2\.10\.1/, count: 1

    assert_select "article h3", text: "JWT::EncodedToken#payload before verification", count: 3
    assert_select "article h3", text: "JWT::Claims.verify! deprecated API", count: 3
    assert_select "dd code", text: "source guard present => true", count: 2
    assert_select "dd code", text: "source guard present => false", count: 1
    assert_select "dd code", text: "JWT::Claims.verify! source present => true"
    assert_select "dd code", text: "JWT::Claims.verify! source present => false"
    assert_select "dd code", text: "safe decode path kept for both versions", count: 3
  end
end
