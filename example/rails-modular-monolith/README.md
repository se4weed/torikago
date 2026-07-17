# rails-modular-monolith

This is the example Rails app for `torikago`.

It demonstrates a Rails-first modular monolith where:

- the host Rails app calls module public methods through `Torikago::Gateway.invoke(...)` or `build(...).invoke(...)`
- each module declares its public classes, methods, and callers in `package_api.yml`
- a module can run setup code before its public API is loaded
- host-owned routes dispatch module controllers through `Torikago.action(...)`
- controllers, models, views, and Package APIs execute in the registered module Box without a `Rails::Engine`

## Layout

- `modules/foo`
  - example module with a `setup` hook that monkey-patches `String#+`
- `modules/bar`
  - example module with query / command style public APIs
- `config/initializers/torikago.rb`
  - registers module roots and their runtime settings
- `config/routes.rb`
  - maps host routes to Box-owned controllers with an explicit module name

The module runtime directories are not added to the host application's
autoload, eager-load, or view paths. The registered module name and root identify
ownership; Rails::Engine is not required. Real Rails controllers currently need
the namespace derived from the registered module name. Non-namespaced controller
support is tracked in https://github.com/se4weed/torikago/issues/15.

## Running

`Ruby::Box` must be enabled when running this example.

```sh
bin/install-module-dependencies
bundle exec bin/box-rails s
```

`bin/install-module-dependencies` loads the Torikago configuration and runs
`bundle install` for every registered module that declares a `gemfile`.

## Testing

```sh
bundle exec bin/box-rails test test modules/foo/test modules/bar/test modules/baz/test
```

## Notes About Boot

Under `RUBY_BOX=1`, this example currently uses a few pragmatic boot workarounds so Rails and Bundler start reliably:

- Bundler plugins are disabled
- `tmpdir` is loaded and guarded early
- when `RUBY_BOX=1`, app boot avoids `Bundler.require(*Rails.groups)` and requires the needed gems explicitly

These are current integration workarounds for the example app, not a finalized long-term contract for `torikago` itself.
