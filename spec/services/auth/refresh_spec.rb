require 'rails_helper'

RSpec.describe Auth::Refresh do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, password: password) }
  let(:session) { Auth::SignIn.call(email: user.email, password: password) }

  it "rotates the row and returns a new pair" do
    original = session.refresh_token

    rotated = described_class.call(original)

    expect(rotated.refresh_token).not_to eq(original)
    expect(user.refresh_tokens.sole.token_digest).to eq(RefreshToken.digest(rotated.refresh_token))
    expect(AccessToken.decode(rotated.access_token)["sub"]).to eq(user.id)
  end

  it "refuses a replayed token" do
    described_class.call(session.refresh_token)

    expect { described_class.call(session.refresh_token) }.to raise_error(Auth::InvalidRefreshToken)
  end

  it "refuses an expired token" do
    raw = session.refresh_token
    user.refresh_tokens.sole.update!(expires_at: 1.second.ago)

    expect { described_class.call(raw) }.to raise_error(Auth::InvalidRefreshToken)
  end

  it "refuses a token that was never issued" do
    expect { described_class.call(SecureRandom.urlsafe_base64(32)) }.to raise_error(Auth::InvalidRefreshToken)
  end

  it "refuses a missing token" do
    expect { described_class.call(nil) }.to raise_error(Auth::InvalidRefreshToken)
  end
end
