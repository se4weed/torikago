module Foo
  class Engine < Rails::Engine
    config.root = File.expand_path("..", __dir__)

    paths.add "app/package_api", autoload: true
  end
end
