# frozen_string_literal: true

module Foo
  class WidgetsController < ApplicationController
    def index
      render json: {
        engine: "foo",
        model: Widget.name,
        table_name: Widget.table_name,
        count: Widget.count
      }
    end
  end
end
