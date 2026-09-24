require 'rails_helper'

RSpec.describe Auth::SignIn do
  let!(:user) { create(:user, email: "hr@example.com", password: "correct horse battery staple") }

  it "returns a usable pair and stores the refresh token as a digest" do
    session = described_class.call(email: "hr@example.com", password: "correct horse battery staple")

    expect(AccessToken.decode(session.access_token)["sub"]).to eq(user.id)
    expect(session.expires_in).to eq(AccessToken::LIFETIME.to_i)
    expect(user.refresh_tokens.sole.token_digest).to eq(RefreshToken.digest(session.refresh_token))
  end

  it "matches the email the way the column is normalized" do
    expect { described_class.call(email: "  HR@Example.com ", password: "correct horse battery staple") }
      .not_to raise_error
  end

  it "raises on a wrong password" do
    expect { described_class.call(email: "hr@example.com", password: "wrong") }
      .to raise_error(Auth::InvalidCredentials)
  end

  it "raises on an unknown email" do
    expect { described_class.call(email: "nobody@example.com", password: "correct horse battery staple") }
      .to raise_error(Auth::InvalidCredentials)
  end

  it "raises on a blank email without querying for nil" do
    expect { described_class.call(email: nil, password: "correct horse battery staple") }
      .to raise_error(Auth::InvalidCredentials)
  end

  it "writes no refresh token when it raises" do
    expect { described_class.call(email: "hr@example.com", password: "wrong") rescue nil }
      .not_to change(RefreshToken, :count)
  end
end
