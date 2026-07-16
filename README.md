# torikago

`torikago` is a gem for introducing per-module runtime boundaries to Rails modular monoliths. It aims to strengthen runtime isolation with `Ruby::Box`, in addition to the structural boundaries you can already get from tools like `packwerk` and `Rails::Engine`.

With `torikago`, module-to-module calls are funneled through `Torikago::Gateway.invoke(...)`, and each module declares which Package API classes and methods it exposes and which modules may call them. This makes it easier to prevent unintended cross-module references at runtime.

![torikago architecture](docs/image.png)

## Configuration example

Register modules from your Rails app:

```ruby
Torikago.configure do |config|
  config.register(
    :foo,
    root: Rails.root.join("modules/foo"),
    entrypoint: "app/package_api",    # optional
    setup: "config/box_setup.rb",     # optional
    gemfile: "Gemfile"                # optional
  )
end
```

The main `config.register` options are:

- `root`
  - the module root directory
- `entrypoint`
  - the directory, or file under that directory, used to discover public APIs
  - defaults to `app/package_api`
- `setup`
  - a setup hook loaded before Box boot completes
  - useful for monkey patches or Box-specific initialization
- `gemfile`
  - a Gemfile used to resolve Box-specific gem require paths
  - during Box cold boot, the resolved require paths are prepended to that Box's `load_path`
  - this is intended to let module code `require` module-local gem versions without relying on main-box gem activation

On the module side, declare the Package APIs you expose and which modules may call them:

```yaml
exports:
  Foo::ListProductsQuery:
    methods:
      - call
      - execute!
    allowed_callers:
      - baz
```

Calls from the module itself and from the main box are allowed implicitly. `allowed_callers` only restricts calls coming from other modules.

For an argumentless constructor, invoke the exported public method directly:

```ruby
Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)

# arguments after the method name go to that method
Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :execute!, title: "Book")
```

Use `build` when the constructor takes arguments. `build` arguments go only to `new`; `invoke` arguments go only to the selected public method:

```ruby
Torikago::Gateway
  .build("Foo::ListProductsQuery", page: 2)
  .invoke(:execute!, per_page: 20)
```

This runs `Foo::ListProductsQuery.new(page: 2).public_send(:execute!, per_page: 20)` entirely inside the target Box. Before booting that Box, Gateway checks the class, method, and caller against `package_api.yml`. Private methods cannot be invoked and target constructor/method exceptions are propagated unchanged.

`Gateway.call` has been removed. Migrate `Gateway.call("Foo::Query", value)` to `Gateway.invoke("Foo::Query", :call, value)`, and add `methods: [call]` to its manifest entry. `update-package-api` preserves existing `methods`; newly discovered entries use `methods: []` so the public surface must be chosen explicitly.

## Example app

A minimal Rails example app lives in `example/rails-modular-monolith/`.

## Usage

### Run gem tests

```sh
bundle exec rake test
```

### Run example app tests

```sh
cd example/rails-modular-monolith
RUBY_BOX=1 bundle exec rails test
```

### Start the example app

```sh
cd example/rails-modular-monolith
RUBY_BOX=1 bundle exec rails s
```

`RUBY_BOX=1` is required to actually enable `Ruby::Box`.

## CLI

Use the CLI via `exe/torikago`:

```sh
bundle exec ruby exe/torikago --help
```

Main commands:

- `torikago init`
  - interactively generate `package_api.yml` files and `config/initializers/torikago.rb`
- `torikago check`
  - validate `Gateway.invoke` and `Gateway.build(...).invoke(...)` usage against manifests
- `torikago update-package-api [BOX]`
  - regenerate `package_api.yml` from the configured entrypoint

`torikago check` uses `Ripper` to scan static Gateway invocations and verifies:

- the class is declared in a manifest
- the invoked method is listed in the non-empty `methods` array
- the caller module is included in `allowed_callers`
- the manifest entry has a matching implementation file
- the exported public instance method is defined when it can be checked statically

## About `RUBY_BOX=1` and boot

The current example app includes a few practical boot workarounds to keep Rails startup stable under `RUBY_BOX=1`:

- disable Bundler plugins
- load `tmpdir` early
- avoid `Bundler.require(*Rails.groups)` under `RUBY_BOX=1` and require the needed gems explicitly

These are pragmatic workarounds for the current example app, not a finalized long-term contract for `torikago`.

## Current limitations

- Initial Box boot is slow
  - cold boot can take several seconds
- `Ruby::Box` itself is still experimental
  - segfaults and instability can happen
- Some gems do not cooperate well with this model
  - especially global-effect gems that influence the whole VM
- Full `Rails::Engine` confinement is still difficult to do cleanly

Common errors:

- `Torikago::DependencyError`
  - an unauthorized cross-module reference
- `Torikago::PublicApiError`
  - calling a Package API class or method that is not declared in the manifest
- `Torikago::BoxUnavailableError`
  - `RUBY_BOX=1` was requested but the target Box could not be created or prepared; Torikago does not fall back to the main process
- `Torikago::GemfileOverrideError`
  - failure while resolving or activating a Box-specific Gemfile override

So, at the moment, `torikago` is better understood as an implementation exploring how far runtime boundaries in a modular monolith can be pushed, rather than a fully production-ready finished product.
