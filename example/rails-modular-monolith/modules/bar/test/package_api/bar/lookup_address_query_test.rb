require_relative "../../../../../test/test_helper"

class Bar::LookupAddressQueryTest < ActiveSupport::TestCase
  test "call returns the address from the bar postcode snapshot" do
    result = Torikago::Gateway.call("Bar::LookupAddressQuery", "013-0310")

    assert_equal true, result.fetch("success")
    assert_equal "bar", result.fetch("module")
    assert_equal "1.0.0.20260507", result.fetch("gem_version")
    assert_equal "013-0310", result.fetch("postal_code")
    assert_equal "秋田県横手市大雄佐加里西", result.fetch("address")
    assert_equal "秋田県", result.fetch("prefecture")
    assert_equal "横手市", result.fetch("city")
    assert_equal "大雄佐加里西", result.fetch("town")
  end
end
