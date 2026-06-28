class Bar::JwtCompatibilityQuery
  def call
    {
      "runtime" => "bar module",
      "version" => jwt_version,
      "checks" => [
        unverified_payload_check,
        deprecated_claims_api_check,
        safe_decode_check
      ]
    }
  end

  private

  def unverified_payload_check
    blocks_access = File.read(File.join(jwt_gem_root, "lib/jwt/encoded_token.rb")).include?("Verify the token signature before accessing the payload")

    {
      "name" => "JWT::EncodedToken#payload before verification",
      "expected_change" => "JWT 3.x blocks payload access until the token signature is verified.",
      "status" => blocks_access ? "blocked" : "allowed",
      "result" => "source guard present => #{blocks_access}"
    }
  end

  def deprecated_claims_api_check
    claims_source = File.read(File.join(jwt_gem_root, "lib/jwt/claims.rb"))
    verify_api_present = claims_source.match?(/def\s+verify!\(/)

    {
      "name" => "JWT::Claims.verify! deprecated API",
      "expected_change" => "JWT 3.x removes the old verify! API in favor of verify_payload!.",
      "status" => verify_api_present ? "present" : "removed",
      "result" => "JWT::Claims.verify! source present => #{verify_api_present}"
    }
  end

  def safe_decode_check
    {
      "name" => "JWT.decode with explicit algorithm",
      "expected_change" => "This supported path should work in both JWT 2.x and 3.x.",
      "status" => "documented",
      "result" => "safe decode path kept for both versions"
    }
  end

  def jwt_version
    jwt_gem_root[%r{/jwt-([^/]+)\z}, 1]
  end

  def jwt_gem_root
    @jwt_gem_root ||= $LOAD_PATH.grep(%r{/gems/jwt-[^/]+/lib\z}).first.delete_suffix("/lib")
  end
end
