require "test_helper"

class PackageApiEagerLoadTest < ActiveSupport::TestCase
  test "registered module runtime paths and constants stay out of the host Rails app" do
    %i[foo bar baz].each do |module_name|
      definition = Torikago.configuration.fetch(module_name)
      module_root = definition.root.to_s

      refute Object.const_defined?(module_name.to_s.camelize, false)
      refute Rails.application.config.autoload_paths.any? { |path| path.to_s.start_with?(module_root) }
      refute Rails.application.config.eager_load_paths.any? { |path| path.to_s.start_with?(module_root) }
    end
  end
end
