require_relative "../../../../../test/test_helper"

class Qux::SafeBannerQueryTest < ActiveSupport::TestCase
  test "call returns the qux banner" do
    result = Torikago::Gateway.call("Qux::SafeBannerQuery")

    assert_equal "quxbox", result
  end
end
