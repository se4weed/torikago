require "jpostcode"

class Bar::LookupAddressQuery
  def call(postal_code)
    result = Jpostcode.find(postal_code)
    addresses = Array(result)
    first_address = addresses.first

    if first_address
      {
        "success" => true,
        "module" => "bar",
        "gem_version" => Jpostcode::VERSION,
        "postal_code" => postal_code,
        "address" => format_address(first_address),
        "prefecture" => first_address.prefecture,
        "city" => first_address.city,
        "town" => first_address.town
      }
    else
      {
        "success" => false,
        "module" => "bar",
        "gem_version" => Jpostcode::VERSION,
        "postal_code" => postal_code,
        "message" => "Address not found"
      }
    end
  end

  private

  def format_address(address)
    [address.prefecture, address.city, address.town, address.street, address.office_name].compact.join
  end
end
