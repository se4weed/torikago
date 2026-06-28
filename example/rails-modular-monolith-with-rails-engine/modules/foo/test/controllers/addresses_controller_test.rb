require_relative "../../../../test/test_helper"

class Foo::AddressesControllerTest < ActionDispatch::IntegrationTest
  test "index renders the lookup form before a search" do
    get "/addresses"

    assert_response :success
    assert_select "h1", text: "Postal Code Lookup"
    assert_select "form[action=?][method=?]", "/addresses/search", "post"
    assert_select ".result-panel", count: 0
  end

  test "search compares the same postal code across foo and bar gem versions" do
    post "/addresses/search", params: { postal_code: "013-0310" }

    assert_response :success
    assert_select ".result-panel", count: 2
    assert_select ".result-panel:nth-of-type(1)" do
      assert_select ".module-name", text: "foo module"
      assert_select "h2", text: "jpostcode v1.0.0.20250901"
      assert_select ".address-result.missing", text: "Address not found"
    end
    assert_select ".result-panel:nth-of-type(2)" do
      assert_select ".module-name", text: "bar module"
      assert_select "h2", text: "jpostcode v1.0.0.20260507"
      assert_select ".address-result.success", text: "秋田県横手市大雄佐加里西"
    end
    assert_select ".comparison-panel .status-success", text: "No (as expected)"
  end
end
