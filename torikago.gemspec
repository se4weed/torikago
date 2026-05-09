require_relative "lib/torikago/version"

Gem::Specification.new do |spec|
  spec.name = "torikago"
  spec.version = Torikago::VERSION

  spec.authors = ["se4weed"]
  spec.email = ["se4weed@gmail.com"]

  spec.summary = "Runtime isolation for modular monoliths built around Ruby::Box"
  spec.description = <<~DESCRIPTION
    torikago is a Ruby gem for modular monolith runtime isolation. It boots
    module-scoped runtimes with Ruby::Box and routes host app and inter-module
    communication through explicit gateway and registry objects.
  DESCRIPTION
  spec.homepage = "https://github.com/se4weed/torikago"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 4.0.3"

  spec.files = Dir[
    "LICENSE.txt",
    "README.md",
    "README.ja.md",
    "lib/**/*.rb",
    "docs/**/*.md",
    "test/**/*.rb"
  ]
  spec.extra_rdoc_files = ["README.ja.md"]
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = ["torikago"]

  spec.metadata = {
    "rubygems_mfa_required" => "true"
  }
end
