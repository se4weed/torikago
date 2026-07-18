require_relative "../../../../../test/test_helper"

class BarSafeBannerQueryTest < ActiveSupport::TestCase
  test "call does not inherit the foo box String patch" do
    result = Torikago::Gateway.invoke("Bar::SafeBannerQuery", :call)

    assert_equal "torikagobox", result
  end
end
