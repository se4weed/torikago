class Foo::JwtCompatibilityReport
  attr_reader :bar_result, :foo_result, :main_result

  def self.build
    new(
      main_result: run_checks("main app"),
      foo_result: Torikago::Gateway.call("Foo::JwtCompatibilityQuery"),
      bar_result: Torikago::Gateway.call("Bar::JwtCompatibilityQuery")
    )
  end

  def self.run_checks(runtime)
    spec = Gem::Specification.find_all_by_name("jwt", "= 3.1.2").max_by(&:version)

    {
      "runtime" => runtime,
      "version" => spec.version.to_s,
      "checks" => [
        unverified_payload_check(spec.full_gem_path),
        deprecated_claims_api_check(spec.full_gem_path),
        safe_decode_check
      ]
    }
  end

  def self.unverified_payload_check(gem_root)
    blocks_access = File.read(File.join(gem_root, "lib/jwt/encoded_token.rb")).include?("Verify the token signature before accessing the payload")

    {
      "name" => "JWT::EncodedToken#payload before verification",
      "expected_change" => "JWT 3.x blocks payload access until the token signature is verified.",
      "status" => blocks_access ? "blocked" : "allowed",
      "result" => "source guard present => #{blocks_access}"
    }
  end

  def self.deprecated_claims_api_check(gem_root)
    claims_source = File.read(File.join(gem_root, "lib/jwt/claims.rb"))
    verify_api_present = claims_source.match?(/def\s+verify!\(/)

    {
      "name" => "JWT::Claims.verify! deprecated API",
      "expected_change" => "JWT 3.x removes the old verify! API in favor of verify_payload!.",
      "status" => verify_api_present ? "present" : "removed",
      "result" => "JWT::Claims.verify! source present => #{verify_api_present}"
    }
  end

  def self.safe_decode_check
    {
      "name" => "JWT.decode with explicit algorithm",
      "expected_change" => "This supported path should work in both JWT 2.x and 3.x.",
      "status" => "documented",
      "result" => "safe decode path kept for both versions"
    }
  end

  def initialize(main_result:, foo_result:, bar_result:)
    @main_result = main_result
    @foo_result = foo_result
    @bar_result = bar_result
  end

  def results
    [main_result, foo_result, bar_result]
  end
end
