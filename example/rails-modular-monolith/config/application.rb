require_relative "boot"

require "tmpdir"

unless Dir.respond_to?(:tmpdir)
  class << Dir
    def tmpdir
      ENV["TMPDIR"] || "/tmp"
    end
  end
end

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
if ENV["RUBY_BOX"] == "1"
  require "torikago"
  require "propshaft"
else
  Bundler.require(*Rails.groups)
end

module RailsModularMonorith
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    Rails.root.glob("modules/*/app/controllers").each do |path|
      config.autoload_paths << path.to_s
    end

    Rails.root.glob("modules/*/app/models").each do |path|
      config.autoload_paths << path.to_s
    end

    Rails.root.glob("modules/*/app/views").each do |path|
      config.paths["app/views"] << path.to_s
    end
  end
end
