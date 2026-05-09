require "minitest/autorun"

ENV["RUBY_BOX"] = "1"
ENV["RAILS_ENV"] = "test"

lib_dir = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require "torikago"
