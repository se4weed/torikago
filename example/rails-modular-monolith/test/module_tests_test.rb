require "test_helper"

Rails.root.glob("modules/*/test/**/*_test.rb").sort.each do |path|
  require path
end
