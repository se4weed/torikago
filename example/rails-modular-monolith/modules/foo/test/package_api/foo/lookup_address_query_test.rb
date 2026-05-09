require_relative "../../../../../test/test_helper"

class Foo::LookupAddressQueryTest < ActiveSupport::TestCase
  test "call returns a missing result for a postcode absent from the foo snapshot" do
    result = Torikago::Gateway.call("Foo::LookupAddressQuery", "013-0310")

    assert_equal false, result.fetch("success")
    assert_equal "foo", result.fetch("module")
    assert_equal "1.0.0.20250901", result.fetch("gem_version")
    assert_equal "013-0310", result.fetch("postal_code")
    assert_equal "Address not found", result.fetch("message")
  end
end
