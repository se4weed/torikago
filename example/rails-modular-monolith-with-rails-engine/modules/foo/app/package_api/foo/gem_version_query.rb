require "jpostcode"

class Foo::GemVersionQuery
  def call
    {
      "main_vs_module" => jwt_result,
      "module_only" => postcode_result
    }
  end

  private

  def jwt_result
    {
      "gem" => "jwt",
      "version" => jwt_version,
      "api" => "JWT source inspection",
      "result" => "foo jwt #{jwt_version} blocks unverified payload access: #{jwt_blocks_unverified_payload?}"
    }
  end

  def jwt_version
    jwt_gem_root[%r{/jwt-([^/]+)\z}, 1]
  end

  def jwt_blocks_unverified_payload?
    File.read(File.join(jwt_gem_root, "lib/jwt/encoded_token.rb")).include?("Verify the token signature before accessing the payload")
  end

  def jwt_gem_root
    @jwt_gem_root ||= $LOAD_PATH.grep(%r{/gems/jwt-[^/]+/lib\z}).first.delete_suffix("/lib")
  end

  def postcode_result
    postal_code = "013-0310"
    address = Jpostcode.find(postal_code)

    {
      "gem" => "jpostcode",
      "version" => Jpostcode::VERSION,
      "api" => "Jpostcode.find(\"#{postal_code}\")",
      "result" => "foo jpostcode #{Jpostcode::VERSION} returned #{address_result(address)}"
    }
  end

  def address_result(address)
    return "nil for 013-0310" unless address

    "#{address.prefecture} #{address.city} #{address.town} #{address.office_name}".strip
  end
end
