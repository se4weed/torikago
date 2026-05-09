require_relative "../../../../../test/test_helper"

class Foo::JwtCompatibilityQueryTest < ActiveSupport::TestCase
  test "call reports JWT 2 compatibility checks" do
    result = Torikago::Gateway.call("Foo::JwtCompatibilityQuery")

    assert_equal "foo module", result.fetch("runtime")
    assert_equal "2.10.1", result.fetch("version")

    checks = result.fetch("checks")
    assert_equal [
      "JWT::EncodedToken#payload before verification",
      "JWT::Claims.verify! deprecated API",
      "JWT.decode with explicit algorithm"
    ], checks.map { |check| check.fetch("name") }
    assert_equal "source guard present => false", checks.fetch(0).fetch("result")
    assert_equal "JWT::Claims.verify! source present => true", checks.fetch(1).fetch("result")
    assert_equal "safe decode path kept for both versions", checks.fetch(2).fetch("result")
  end
end
