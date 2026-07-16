module Torikago
  # Describes one package API invocation without resolving or booting its Box.
  class Invocation
    def initialize(gateway:, public_api_class_name:, constructor_args:, constructor_kwargs:)
      @gateway = gateway
      @public_api_class_name = public_api_class_name
      @constructor_args = constructor_args.freeze
      @constructor_kwargs = constructor_kwargs.freeze
    end

    def invoke(method_name, *method_args, **method_kwargs)
      gateway.dispatch(
        public_api_class_name: public_api_class_name,
        method_name: method_name,
        constructor_args: constructor_args,
        constructor_kwargs: constructor_kwargs,
        method_args: method_args,
        method_kwargs: method_kwargs
      )
    end

    private

    attr_reader :constructor_args, :constructor_kwargs, :gateway, :public_api_class_name
  end
end
