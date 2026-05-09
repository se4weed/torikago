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
