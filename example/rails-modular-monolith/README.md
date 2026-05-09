# rails-modular-monolith

This is the example Rails app for `torikago`.

It demonstrates a Rails-first modular monolith where:

- the host Rails app calls module public APIs through `Torikago::Gateway.call(...)`
- each module declares its public surface in `package_api.yml`
- a module can run setup code before its public API is loaded

## Layout

- `modules/foo`
  - example module with a `setup` hook that monkey-patches `String#+`
- `modules/bar`
  - example module with query / command style public APIs
- `config/initializers/torikago.rb`
  - registers module roots and their runtime settings

## Running

`Ruby::Box` must be enabled when running this example.

```sh
RUBY_BOX=1 bundle exec rails s
```

## Testing

```sh
RUBY_BOX=1 bundle exec rails test
```

## Notes About Boot

Under `RUBY_BOX=1`, this example currently uses a few pragmatic boot workarounds so Rails and Bundler start reliably:

- Bundler plugins are disabled
- `tmpdir` is loaded and guarded early
- when `RUBY_BOX=1`, app boot avoids `Bundler.require(*Rails.groups)` and requires the needed gems explicitly

These are current integration workarounds for the example app, not a finalized long-term contract for `torikago` itself.
