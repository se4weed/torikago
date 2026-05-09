# frozen_string_literal: true

module Bar
  class Widget < BarRecord
    validates :name, presence: true
  end
end
