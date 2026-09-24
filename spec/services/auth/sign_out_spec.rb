require 'rails_helper'

RSpec.describe Auth::SignOut do
  it "deletes every refresh token the user holds" do
    user = create(:user)
    create_list(:refresh_token, 3, user: user)
    other = create(:refresh_token)

    described_class.call(user)

    expect(user.refresh_tokens.reload).to be_empty
    expect(RefreshToken.exists?(other.id)).to be(true)
  end
end
