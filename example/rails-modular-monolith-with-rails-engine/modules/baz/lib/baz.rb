module Baz
  class Engine < Rails::Engine
    config.root = File.expand_path("..", __dir__)

    # Package APIs are loaded by Torikago inside module boxes. Do not eager-load
    # them in the main box, where module-local gem versions must stay invisible.
    paths.add "app/package_api", autoload: true
  end
end
