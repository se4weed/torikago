class Foo::PostcodeLookup
  SAMPLE_POSTAL_CODE = "013-0310"

  attr_reader :bar_result, :foo_result, :postal_code

  def initialize(postal_code)
    @postal_code = postal_code.presence || SAMPLE_POSTAL_CODE
  end

  def call
    @foo_result = Torikago::Gateway.call("Foo::LookupAddressQuery", postal_code)
    @bar_result = Torikago::Gateway.call("Bar::LookupAddressQuery", postal_code)
    self
  end

  def searched?
    foo_result || bar_result
  end

  def versions_match?
    return false unless searched?

    foo_result["gem_version"] == bar_result["gem_version"]
  end

  def addresses_match?
    return false unless foo_result&.dig("address") && bar_result&.dig("address")

    foo_result["address"] == bar_result["address"]
  end
end
