module Auth
  Tokens = Data.define(:access_token, :expires_in, :refresh_token) do
    def self.for(refresh_token)
      new(access_token: AccessToken.encode(refresh_token.user),
          expires_in: AccessToken::LIFETIME.to_i, refresh_token: refresh_token.raw_token)
    end
  end
end
