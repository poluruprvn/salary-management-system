module Auth
  class SignOut
    def self.call(user)
      user.refresh_tokens.delete_all
    end
  end
end
