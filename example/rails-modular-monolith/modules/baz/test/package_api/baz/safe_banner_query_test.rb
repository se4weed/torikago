require_relative "../../../../../test/test_helper"

class Baz::SafeBannerQueryTest < ActiveSupport::TestCase
  test "call returns the baz banner" do
    result = Torikago::Gateway.call("Baz::SafeBannerQuery")

    assert_equal "bazbox", result
  end
end
