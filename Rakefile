require "rake/testtask"
require "rake/file_list"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = Rake::FileList["test/**/*.rb"].exclude("test/**/*_helper.rb")
end

task default: :test
