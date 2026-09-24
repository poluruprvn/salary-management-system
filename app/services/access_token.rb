module AccessToken
  Invalid = Class.new(StandardError)
  Expired = Class.new(StandardError)

  ALGORITHM = "HS256"
  LIFETIME = 15.minutes

  class << self
    def encode(user)
      now = Time.current
      payload = { sub: user.id, iat: now.to_i, exp: (now + LIFETIME).to_i, jti: SecureRandom.uuid }
      JWT.encode(payload, signing_key, ALGORITHM)
    end

    # An alg: none token skips the signature check, so the allowed algorithm list is what refuses it.
    # The gem already defaults to HS256; passing it keeps decode matched to encode if ALGORITHM moves.
    def decode(token)
      payload, = JWT.decode(token, signing_key, true, algorithm: ALGORITHM)
      raise Invalid unless payload.is_a?(Hash)

      payload
    rescue JWT::ExpiredSignature
      raise Expired
    rescue JWT::Error, ArgumentError => e
      # The cause is the only thing that tells a rotated signing key apart from ordinary bad tokens.
      Rails.logger.info { "access token rejected: #{e.class}" }
      raise Invalid
    end

    private
      def signing_key
        Rails.application.secret_key_base
      end
  end
end
