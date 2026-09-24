module Api
  module V1
    class MeController < BaseController
      def show
        render json: UserSerializer.new(current_user)
      end
    end
  end
end
