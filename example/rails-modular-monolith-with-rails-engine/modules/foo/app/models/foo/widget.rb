# frozen_string_literal: true

module Foo
  class Widget < FooRecord
    validates :name, presence: true
  end
end
