require_relative "../test_helper"

class TorikagoVersionTest < Minitest::Test
  def test_has_a_version_number
    refute_nil ::Torikago::VERSION
  end

  def test_version_uses_semver_like_format
    assert_match(/\A\d+\.\d+\.\d+\z/, ::Torikago::VERSION)
  end
end
