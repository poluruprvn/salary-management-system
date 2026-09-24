module Auth
  class Refresh
    def self.call(raw_token)
      Tokens.for(RefreshToken.claim!(raw_token.to_s))
    rescue RefreshToken::InvalidToken
      raise InvalidRefreshToken
    end
  end
end
