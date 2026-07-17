# rails-modular-monolith-with-rails-engine

This is the Rails example app for `torikago` with `Rails::Engine` modules and one plain module mixed together.

It demonstrates a Rails-first modular monolith where:

- the host Rails app calls module public methods through `Torikago::Gateway.invoke(...)` or `build(...).invoke(...)`
- each module declares its public classes, methods, and callers in `package_api.yml`
- a module can run setup code before its public API is loaded
- a module can run its engine routes, controllers, models, and Package APIs in the same Box
- another module can skip `Rails::Engine`, use a host app route, and still run its controller in a Torikago Box

## Layout

- `modules/foo`
  - example module with a `setup` hook that monkey-patches `String#+`
- `modules/bar`
  - example module with query / command style public APIs
- `config/initializers/torikago.rb`
  - registers module roots and uses `rails_engine: true` for foo, bar, and baz
- `modules/{foo,bar,baz}/lib/*.rb`
  - defines each Rails::Engine module's entrypoint
- `modules/{foo,bar,baz}/config/routes.rb`
  - defines module-local HTTP routes mounted by the host app
- `modules/qux`
  - plain module without a `Rails::Engine`
  - the host route uses `Torikago.action(...)`, so its controller is resolved and
    executed inside the Qux Box instead of being autoloaded in the main Box
  - the example uses `Qux::ShowcaseController`; the namespace is a code
    organization choice rather than the source of module ownership

## Compared With The Non-Engine Example

This app defines `Foo::Engine`, `Bar::Engine`, and `Baz::Engine` inside their
module Boxes. The host app mounts `Torikago::RackEndpoint` instances from
`config/routes.rb`, so it never resolves those engine or controller constants.
It also registers `qux` without `rails_engine: true` to show that Rails::Engine
and non-Engine modules can coexist while keeping both Package APIs and
controllers in their module Box.

See `../rails-modular-monolith` for the same app organized without
`Rails::Engine`, using host app routes and host app module autoload paths.

## Running

`Ruby::Box` must be enabled when running this example.

```sh
bundle exec bin/box-rails s
```

## Testing

```sh
bundle exec bin/box-rails test
```

## Notes About Boot

Under `RUBY_BOX=1`, this example currently uses a few pragmatic boot workarounds so Rails and Bundler start reliably:

- Bundler plugins are disabled
- `tmpdir` is loaded and guarded early
- when `RUBY_BOX=1`, app boot avoids `Bundler.require(*Rails.groups)` and requires the needed gems explicitly

These are current integration workarounds for the example app, not a finalized long-term contract for `torikago` itself.
