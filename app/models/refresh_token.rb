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
class RefreshToken < ApplicationRecord
  InvalidToken = Class.new(StandardError)

  LIFETIME = 30.days

  belongs_to :user

  scope :active, -> { where(expires_at: Time.current..) }
  scope :expired, -> { where(expires_at: ..Time.current) }

  # Set only on the row issue! just minted. Never loaded back from the database.
  attr_reader :raw_token

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def self.issue!(user)
    raw = SecureRandom.urlsafe_base64(32)
    token = create!(user: user, token_digest: digest(raw), expires_at: LIFETIME.from_now)
    token.instance_variable_set(:@raw_token, raw)
    token
  end

  # Every refresh rotates. The lock makes the swap exclusive: of two concurrent claims on one
  # token the loser re-reads after the delete, finds nothing, and is refused.
  def self.claim!(raw)
    expired.delete_all

    transaction do
      token = active.lock.find_by(token_digest: digest(raw))
      raise InvalidToken unless token

      token.delete
      issue!(token.user)
    end
  end
end
