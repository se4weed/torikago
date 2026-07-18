class Foo::AddressesController < Foo::ApplicationController
  def index
    @lookup = Foo::PostcodeLookup.new(params[:postal_code])
  end

  def search
    if params[:postal_code].blank?
      redirect_to "/addresses", alert: "Postal code is required"
      return
    end

    @lookup = Foo::PostcodeLookup.new(params[:postal_code])
    @lookup.call
    render :index
  end
end
