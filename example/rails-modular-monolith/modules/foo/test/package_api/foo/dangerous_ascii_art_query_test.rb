require_relative "../../../../../test/test_helper"

class Foo::DangerousAsciiArtQueryTest < ActiveSupport::TestCase
  test "call uses the foo box String patch" do
    result = Torikago::Gateway.invoke("Foo::DangerousAsciiArtQuery", :call)

    assert_match(/torikago.*༼;´༎ຶ ۝ ༎ຶ༽.*box/m, result)
  end
end
