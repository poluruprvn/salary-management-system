module Api
  module V1
    class BaseController < ApplicationController
      abstract!

      include ErrorHandling
      include Authentication
      include Pagination
    end
  end
end
