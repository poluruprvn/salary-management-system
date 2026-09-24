require 'rails_helper'

RSpec.describe AccessToken do
  let(:user) { create(:user) }

  describe ".encode" do
    it "signs the user id with an expiry and a jti" do
      payload = described_class.decode(described_class.encode(user))

      expect(payload["sub"]).to eq(user.id)
      expect(payload["exp"]).to eq(payload["iat"] + AccessToken::LIFETIME.to_i)
      expect(payload["jti"]).to be_present
    end
  end

  describe ".decode" do
    it "accepts a token inside its lifetime" do
      token = described_class.encode(user)

      travel_to(AccessToken::LIFETIME.from_now - 1.second) do
        expect(described_class.decode(token)["sub"]).to eq(user.id)
      end
    end

    it "raises Expired once the lifetime has passed" do
      token = described_class.encode(user)

      travel_to(AccessToken::LIFETIME.from_now + 1.second) do
        expect { described_class.decode(token) }.to raise_error(AccessToken::Expired)
      end
    end

    it "raises Invalid on a tampered payload" do
      header, payload, signature = described_class.encode(user).split(".")
      forged = Base64.urlsafe_encode64({ sub: SecureRandom.uuid }.to_json, padding: false)

      expect { described_class.decode([ header, forged, signature ].join(".")) }
        .to raise_error(AccessToken::Invalid)
    end

    it "raises Invalid on a token signed with another key" do
      token = JWT.encode({ sub: user.id, exp: 1.hour.from_now.to_i }, "not the secret", "HS256")

      expect { described_class.decode(token) }.to raise_error(AccessToken::Invalid)
    end

    it "raises Invalid on alg: none" do
      token = JWT.encode({ sub: user.id, exp: 1.hour.from_now.to_i }, nil, "none")

      expect { described_class.decode(token) }.to raise_error(AccessToken::Invalid)
    end

    it "raises Invalid on a payload that is not an object" do
      token = JWT.encode([ 1, 2 ], Rails.application.secret_key_base, "HS256")

      expect { described_class.decode(token) }.to raise_error(AccessToken::Invalid)
    end

    it "raises Invalid on a string that is not a token" do
      expect { described_class.decode("nonsense") }.to raise_error(AccessToken::Invalid)
    end
  end
end
