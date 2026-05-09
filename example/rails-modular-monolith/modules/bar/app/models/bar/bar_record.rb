# frozen_string_literal: true

module Bar
  class BarRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.table_name_prefix
      "bar_"
    end
  end
end
