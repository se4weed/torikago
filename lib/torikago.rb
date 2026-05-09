require_relative "torikago/configuration"
require_relative "torikago/current_execution"
require_relative "torikago/checker"
require_relative "torikago/cli"
require_relative "torikago/engine_container"
require_relative "torikago/errors"
require_relative "torikago/gateway"
require_relative "torikago/package_api_updater"
require_relative "torikago/registry"
require_relative "torikago/version"

module Torikago
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      # Rebuild runtime collaborators after configuration changes so newly
      # registered modules are visible to future Gateway calls.
      reset_runtime_state!
      configuration
    end

    def gateway
      @gateway ||= Gateway.new(registry: registry, configuration: configuration)
    end

    def registry
      @registry ||= Registry.new(configuration: configuration)
    end

    def version
      VERSION
    end

    private

    def rails_app?
      return false unless defined?(Rails)
      return false unless Rails.respond_to?(:application)

      !Rails.application.nil?
    end

    def ruby_box_enabled?
      ENV["RUBY_BOX"] == "1"
    end

    def warn_if_ruby_box_is_disabled_in_rails!
      return unless rails_app?
      return if ruby_box_enabled?

      # The gem can run without Ruby::Box for local development, but a Rails app
      # using torikago usually expects runtime isolation to be active.
      warn "[warn] torikago is loaded in a Rails app without RUBY_BOX=1; Ruby::Box isolation is disabled."
    end

    def reset_runtime_state!
      @gateway = nil
      @registry = nil
    end
  end

  def version
    VERSION
  end
end

Torikago.send(:warn_if_ruby_box_is_disabled_in_rails!)
