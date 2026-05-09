module Torikago
  class Error < StandardError
  end

  class DependencyError < Error
  end

  class BoxUnavailableError < Error
  end

  class PublicApiError < Error
  end

  class GemfileOverrideError < Error
  end
end
