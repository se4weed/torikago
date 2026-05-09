require_relative "../../../../../test/test_helper"

class Foo::GemVersionQueryTest < ActiveSupport::TestCase
  test "call reports foo-local gem versions" do
    result = Torikago::Gateway.call("Foo::GemVersionQuery")

    main_vs_module = result.fetch("main_vs_module")
    assert_equal "jwt", main_vs_module.fetch("gem")
    assert_equal "2.10.1", main_vs_module.fetch("version")
    assert_equal "JWT source inspection", main_vs_module.fetch("api")
    assert_equal "foo jwt 2.10.1 blocks unverified payload access: false", main_vs_module.fetch("result")

    module_only = result.fetch("module_only")
    assert_equal "jpostcode", module_only.fetch("gem")
    assert_equal "1.0.0.20250901", module_only.fetch("version")
    assert_equal "Jpostcode.find(\"013-0310\")", module_only.fetch("api")
    assert_equal "foo jpostcode 1.0.0.20250901 returned nil for 013-0310", module_only.fetch("result")
  end
end
