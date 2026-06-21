class GemVersionsController < ApplicationController
  def show
    @main_result = {
      "gem" => "jwt",
      "version" => main_jwt_spec.version.to_s,
      "api" => "JWT source inspection",
      "result" => "main jwt #{main_jwt_spec.version} blocks unverified payload access: #{jwt_blocks_unverified_payload?(main_jwt_spec.full_gem_path)}"
    }
    @main_module_only_loaded = Object.const_defined?(:Jpostcode, false)
    @breaking_changes = breaking_changes
    @foo_result = Torikago::Gateway.call("Foo::GemVersionQuery")
    @bar_result = Torikago::Gateway.call("Bar::GemVersionQuery")
  end

  private

  def main_jwt_spec
    Gem::Specification.find_all_by_name("jwt", "= 3.1.2").max_by(&:version)
  end

  def jwt_blocks_unverified_payload?(gem_root)
    File.read(File.join(gem_root, "lib/jwt/encoded_token.rb")).include?("Verify the token signature before accessing the payload")
  end

  def breaking_changes
    [
      {
        "gem" => "jwt",
        "boundary" => "3.0.0",
        "change" => "JWT 3.x is a major upgrade boundary for token encoding and decoding behavior.",
        "impact" => "Modules can verify authentication-token code on JWT 2.x or 3.x before the main app upgrades."
      },
      {
        "gem" => "jpostcode",
        "boundary" => "postal data snapshot",
        "change" => "Each release packages a Japan Post postcode dataset snapshot, so a code can be missing in one module and resolvable in another.",
        "impact" => "Modules can verify address lookup behavior against their own bundled postcode data without forcing the main app to load jpostcode."
      },
      {
        "gem" => "nokogiri",
        "boundary" => "native extension note",
        "change" => "Loading multiple Nokogiri native extension versions in the same Ruby::Box process currently crashes this local Ruby::Box build.",
        "impact" => "Nokogiri remains a useful product-gem risk case, but this page keeps the live runtime demo on pure-Ruby gems until native extension isolation is safe."
      }
    ]
  end
end
