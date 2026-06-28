require "test_helper"

class GemVersionsControllerTest < ActionDispatch::IntegrationTest
  test "show renders module-local product gem boundaries" do
    get "/gem-versions"

    assert_response :success
    assert_select "h1", text: "Module Gem Versions"
    assert_select "h2", text: "Main vs module product gem"
    assert_select "h2", text: "Module-only product gem"
    assert_select "h2", text: "Historical breaking changes"

    assert_in_order [
      "main", "3.1.2", "main jwt 3.1.2 blocks unverified payload access: true",
      "foo module", "2.10.1", "foo jwt 2.10.1 blocks unverified payload access: false",
      "bar module", "3.1.2", "bar jwt 3.1.2 blocks unverified payload access: true"
    ]

    assert_in_order [
      "foo module", "1.0.0.20250901", "foo jpostcode 1.0.0.20250901 returned nil for 013-0310",
      "bar module", "1.0.0.20260507", "bar jpostcode 1.0.0.20260507"
    ]

    assert_includes response.body, "秋田県 横手市 大雄佐加里西"
    assert_select "article h3", text: "jpostcode postal data snapshot"
    assert_select "article h3", text: "nokogiri native extension note"
  end

  private

  def assert_in_order(expected_fragments)
    cursor = 0

    expected_fragments.each do |fragment|
      index = response.body.index(fragment, cursor)
      assert index, "Expected #{fragment.inspect} after byte offset #{cursor}"
      cursor = index + fragment.length
    end
  end
end
