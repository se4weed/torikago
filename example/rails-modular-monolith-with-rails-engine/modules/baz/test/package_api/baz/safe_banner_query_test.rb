require_relative "../../../../../test/test_helper"

class BazSafeBannerQueryTest < ActiveSupport::TestCase
  test "call returns the baz banner" do
    result = Torikago::Gateway.invoke("Baz::SafeBannerQuery", :call)

    assert_equal "bazbox", result
  end
end
