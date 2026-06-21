module Bar
  class WidgetsController < ApplicationController
    def index
      render json: {
        engine: "bar",
        model: Widget.name,
        table_name: Widget.table_name,
        count: Widget.count,
        runtime: "inline"
      }
    end
  end
end
