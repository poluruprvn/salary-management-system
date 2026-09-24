module Authentication
  extend ActiveSupport::Concern

  BEARER = /\ABearer (?<token>\S+)\z/i

  included do
    before_action :authenticate!
  end

  private
    # Audited::Sweeper reads this off the controller to stamp the actor on every audit row.
    attr_reader :current_user

    def authenticate!
      @current_user = User.find_by(id: AccessToken.decode(bearer_token)["sub"])
      raise AccessToken::Invalid unless @current_user
    end

    def bearer_token
      match = BEARER.match(request.authorization.to_s)
      raise AccessToken::Invalid unless match

      match[:token]
    end
end
