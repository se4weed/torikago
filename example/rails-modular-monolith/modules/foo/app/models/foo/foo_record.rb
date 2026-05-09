# frozen_string_literal: true

module Foo
  class FooRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.table_name_prefix
      "foo_"
    end
  end
end
