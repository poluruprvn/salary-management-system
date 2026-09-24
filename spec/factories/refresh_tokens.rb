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
FactoryBot.define do
  factory :refresh_token do
    user
    token_digest { RefreshToken.digest(SecureRandom.urlsafe_base64(32)) }
    expires_at { RefreshToken::LIFETIME.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
