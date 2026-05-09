class Foo::JwtChecksController < ApplicationController
  def show
    @report = Foo::JwtCompatibilityReport.build
  end
end
