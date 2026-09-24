module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate!, only: [ :create, :refresh ]

      def create
        render json: tokens(Auth::SignIn.call(email: params.require(:email), password: params.require(:password)))
      end

      def refresh
        render json: tokens(Auth::Refresh.call(params.require(:refresh_token)))
      end

      def destroy
        Auth::SignOut.call(current_user)
        head :no_content
      end

      private
        def tokens(session)
          { access_token: session.access_token, expires_in: session.expires_in, refresh_token: session.refresh_token }
        end
    end
  end
end
