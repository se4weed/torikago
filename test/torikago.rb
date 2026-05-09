require_relative "test_helper"
require "open3"
require "rbconfig"

class TorikagoTest < Minitest::Test
  def test_version_is_available_when_module_is_included
    object = Class.new { include Torikago }.new

    assert_equal Torikago::VERSION, object.version
  end

  def test_configure_yields_the_shared_configuration
    original_configuration = Torikago.configuration

    begin
      yielded_configuration = nil

      Torikago.configure do |config|
        yielded_configuration = config
      end

      assert_same Torikago.configuration, yielded_configuration
    ensure
      Torikago.instance_variable_set(:@configuration, original_configuration)
      Torikago.instance_variable_set(:@registry, nil)
      Torikago.instance_variable_set(:@gateway, nil)
    end
  end

  def test_warns_when_loaded_in_rails_without_ruby_box
    script = <<~RUBY
      $LOAD_PATH.unshift(ARGV.fetch(0))

      module Rails
        class << self
          attr_accessor :application
        end

        self.application = Object.new
      end

      require "torikago"
    RUBY

    _stdout, stderr, status = Open3.capture3(
      { "RUBY_BOX" => nil },
      RbConfig.ruby,
      "-e",
      script,
      File.expand_path("../lib", __dir__)
    )

    assert_predicate status, :success?, stderr
    assert_match(/\[warn\].*RUBY_BOX=1/, stderr)
  end

  def test_does_not_warn_when_ruby_box_is_enabled
    with_ruby_box_env("1") do
      with_temporary_rails_constant(application: Object.new) do
        assert_output(nil, "") do
          Torikago.send(:warn_if_ruby_box_is_disabled_in_rails!)
        end
      end
    end
  end

  def test_does_not_warn_outside_rails
    with_ruby_box_env(nil) do
      assert_output(nil, "") do
        Torikago.send(:warn_if_ruby_box_is_disabled_in_rails!)
      end
    end
  end

  def test_does_not_warn_when_rails_constant_exists_but_no_application_is_booted
    with_ruby_box_env(nil) do
      with_temporary_rails_constant(application: nil) do
        assert_output(nil, "") do
          Torikago.send(:warn_if_ruby_box_is_disabled_in_rails!)
        end
      end
    end
  end

  private

  def with_ruby_box_env(value)
    original = ENV["RUBY_BOX"]
    ENV["RUBY_BOX"] = value
    yield
  ensure
    ENV["RUBY_BOX"] = original
  end

  def with_temporary_rails_constant(application:)
    had_rails = Object.const_defined?(:Rails)
    unless had_rails
      rails_module = Module.new do
        singleton_class.attr_accessor :application
      end
      rails_module.application = application
      Object.const_set(:Rails, rails_module)
    end

    Rails.application = application if Rails.respond_to?(:application=)
    yield
  ensure
    Object.send(:remove_const, :Rails) if !had_rails && Object.const_defined?(:Rails)
  end
end
