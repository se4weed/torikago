require_relative "../../../../../test/test_helper"

class Bar::GemVersionQueryTest < ActiveSupport::TestCase
  test "call reports bar-local gem versions" do
    result = Torikago::Gateway.call("Bar::GemVersionQuery")

    main_vs_module = result.fetch("main_vs_module")
    assert_equal "jwt", main_vs_module.fetch("gem")
    assert_equal "3.1.2", main_vs_module.fetch("version")
    assert_equal "JWT source inspection", main_vs_module.fetch("api")
    assert_equal "bar jwt 3.1.2 blocks unverified payload access: true", main_vs_module.fetch("result")

    module_only = result.fetch("module_only")
    assert_equal "jpostcode", module_only.fetch("gem")
    assert_equal "1.0.0.20260507", module_only.fetch("version")
    assert_equal "Jpostcode.find(\"013-0310\")", module_only.fetch("api")
    assert_includes module_only.fetch("result"), "bar jpostcode 1.0.0.20260507 returned"
    assert_includes module_only.fetch("result"), "秋田県 横手市 大雄佐加里西"
  end
end
