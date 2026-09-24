require "rails_helper"

# == Schema Information
#
# Table name: refresh_tokens
#
#  id           :uuid             not null, primary key
#  expires_at   :datetime         not null
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :uuid             not null
#
# Indexes
#
#  index_refresh_tokens_on_expires_at    (expires_at)
#  index_refresh_tokens_on_token_digest  (token_digest) UNIQUE
#  index_refresh_tokens_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe RefreshToken do
  let(:user) { create(:user) }

  describe ".issue!" do
    it "returns the raw token once and stores only its digest" do
      token = described_class.issue!(user)

      expect(token.raw_token).to be_present
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(token.raw_token))
      expect(described_class.find(token.id).raw_token).to be_nil
    end

    it "does not let a caller set the raw token" do
      expect { described_class.new.raw_token = "forged" }.to raise_error(NoMethodError)
    end

    it "expires thirty days out" do
      token = described_class.issue!(user)

      expect(token.expires_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe ".active" do
    it "excludes expired rows" do
      live = create(:refresh_token, user: user)
      create(:refresh_token, :expired, user: user)

      expect(described_class.active).to contain_exactly(live)
    end
  end

  describe ".claim!" do
    it "rotates the row and keeps the user" do
      token = described_class.issue!(user)

      replacement = described_class.claim!(token.raw_token)

      expect(replacement.user).to eq(user)
      expect(replacement.raw_token).not_to eq(token.raw_token)
      expect(described_class.where(id: token.id)).to be_empty
      expect(user.refresh_tokens.reload).to contain_exactly(replacement)
    end

    it "rotates one session without signing the others out" do
      other = described_class.issue!(user)
      token = described_class.issue!(user)

      replacement = described_class.claim!(token.raw_token)

      expect(user.refresh_tokens.reload).to contain_exactly(other, replacement)
    end

    it "refuses a token that was already claimed" do
      token = described_class.issue!(user)
      described_class.claim!(token.raw_token)

      expect { described_class.claim!(token.raw_token) }.to raise_error(described_class::InvalidToken)
    end

    it "refuses an unknown token" do
      expect { described_class.claim!("nonsense") }.to raise_error(described_class::InvalidToken)
    end

    it "refuses an expired token and leaves no replacement" do
      token = described_class.issue!(user)
      token.update!(expires_at: 1.day.ago)

      expect { described_class.claim!(token.raw_token) }.to raise_error(described_class::InvalidToken)
      expect(user.refresh_tokens.reload).to be_empty
    end

    it "sweeps every expired row on the way through" do
      other = create(:refresh_token, :expired)
      token = described_class.issue!(user)

      described_class.claim!(token.raw_token)

      expect(described_class.where(id: other.id)).to be_empty
    end
  end
end
