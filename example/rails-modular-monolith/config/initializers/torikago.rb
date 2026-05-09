Torikago.configure do |config|
  config.register(
    :foo,
    root: Rails.root.join("modules/foo"),
    setup: "config/box_setup.rb",
    gemfile: "Gemfile"
  )

  config.register(
    :bar,
    root: Rails.root.join("modules/bar"),
    gemfile: "Gemfile"
  )

  config.register(
    :baz,
    root: Rails.root.join("modules/baz")
  )
end
