require "rails_helper"

# == Schema Information
#
# Table name: users
#
#  id              :uuid             not null, primary key
#  email           :string           not null
#  name            :string           not null
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_lower_email  (lower((email)::text)) UNIQUE
#
RSpec.describe User do
  it { is_expected.to have_many(:refresh_tokens).dependent(:delete_all) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:email) }

  it "downcases the email before validation" do
    user = create(:user, email: "Ada@Example.com")

    expect(user.email).to eq("ada@example.com")
  end

  it "normalizes the email on update too, not only on create" do
    user = create(:user)
    user.update!(email: "  Ada@Example.com  ")

    expect(user.reload.email).to eq("ada@example.com")
  end

  it "authenticates with the password it was created with" do
    user = create(:user, password: "a good long passphrase")

    expect(user.authenticate("a good long passphrase")).to eq(user)
    expect(user.authenticate("wrong")).to be(false)
  end

  it "rejects an address that is not an email" do
    expect(build(:user, email: "not an email")).not_to be_valid
    expect(build(:user, email: "ada lovelace@example.com")).not_to be_valid
    expect(build(:user, email: "@example.com")).not_to be_valid
    expect(build(:user, email: "ada.lovelace+hr@example.co.uk")).to be_valid
  end

  # URI::MailTo allows a bare host, so an intranet address is not rejected for missing a TLD.
  it "accepts an address with no dot in the host" do
    expect(build(:user, email: "ada@example")).to be_valid
  end

  it "reports only the blank error for a missing email, not the format one" do
    record = build(:user, email: "")

    record.valid?
    expect(record.errors[:email]).to contain_exactly("can't be blank")
  end

  it "does not carry a password reset token" do
    expect(User.new).not_to respond_to(:password_reset_token)
  end

  it "rejects an email already taken in a different case" do
    create(:user, email: "ada@example.com")
    duplicate = build(:user, email: "ADA@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "strips the email, so surrounding space is not a second account" do
    create(:user, email: "ada@example.com")
    duplicate = build(:user, email: "  ada@example.com  ")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "rejects it in the index too when the validation is skipped" do
    create(:user, email: "ada@example.com")
    duplicate = build(:user, email: "ADA@example.com")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
