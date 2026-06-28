Torikago.configure do |config|
  config.register(
    :foo,
    root: Rails.root.join("modules/foo"),
    rails_engine: true,
    setup: "config/box_setup.rb",
    gemfile: "Gemfile"
  )

  config.register(
    :bar,
    root: Rails.root.join("modules/bar"),
    rails_engine: true,
    gemfile: "Gemfile"
  )

  config.register(
    :baz,
    root: Rails.root.join("modules/baz"),
    rails_engine: true
  )

  config.register(
    :qux,
    root: Rails.root.join("modules/qux")
  )
end
