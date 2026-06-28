ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
ENV["BUNDLE_NO_PLUGINS"] ||= "1"

require "tmpdir"

unless Dir.respond_to?(:tmpdir)
  class << Dir
    def tmpdir
      ENV["TMPDIR"] || "/tmp"
    end
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.

if ENV["RUBY_BOX"] == "1"
  if ENV["RUBYOPT"]&.include?("bundler/setup")
    rubyopt = ENV["RUBYOPT"].split.reject { |option| option.include?("bundler/setup") }
    rubyopt.empty? ? ENV.delete("RUBYOPT") : ENV["RUBYOPT"] = rubyopt.join(" ")
  end

  ENV.delete("BUNDLER_SETUP")
end
