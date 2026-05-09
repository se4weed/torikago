module Torikago
  # Tracks which module is currently executing so Gateway can enforce
  # caller-specific package API permissions.
  module CurrentExecution
    STORAGE_KEY = :__torikago_current_box

    module_function

    def current_box
      Thread.current[STORAGE_KEY]
    end

    def with_box(box_name)
      previous_box = current_box
      Thread.current[STORAGE_KEY] = box_name.to_sym
      yield
    ensure
      # Gateway calls can be nested, so restore the previous caller even when a
      # package API raises.
      Thread.current[STORAGE_KEY] = previous_box
    end
  end
end
