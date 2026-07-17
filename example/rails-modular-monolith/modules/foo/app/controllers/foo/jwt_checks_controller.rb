class Foo::JwtChecksController < Foo::ApplicationController
  def show
    @report = Foo::JwtCompatibilityReport.build
  end
end
