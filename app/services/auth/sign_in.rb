module Auth
  class SignIn
    def self.call(email:, password:)
      user = User.find_by(email: email.to_s)
      raise InvalidCredentials unless (user || dummy_user).authenticate(password)

      Tokens.for(RefreshToken.issue!(user))
    end

    # Hash even when the email is unknown, so a miss costs the same as a wrong password.
    def self.dummy_user
      @dummy_user ||= User.new(password: SecureRandom.hex)
    end
    private_class_method :dummy_user
  end
end
