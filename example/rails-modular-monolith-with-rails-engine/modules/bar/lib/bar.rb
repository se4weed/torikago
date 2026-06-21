module Bar
  class Engine < Rails::Engine
    config.root = File.expand_path("..", __dir__)

    paths.add "app/package_api", eager_load: true, autoload: true
  end
end
