require 'rails_helper'

RSpec.describe StrictDateType do
  subject(:type) { described_class.new }

  it "casts an ISO string, a date and a time to a date" do
    expect(type.cast("2024-01-31")).to eq(Date.new(2024, 1, 31))
    expect(type.cast(Date.new(2024, 1, 31))).to eq(Date.new(2024, 1, 31))
    expect(type.cast(Time.utc(2024, 1, 31, 12))).to eq(Date.new(2024, 1, 31))
  end

  it "casts a number, a boolean, an impossible date and a five digit year to nil" do
    [ 20240131, true, false, "2024-02-30", "garbage", "99999-01-01" ].each do |value|
      expect(type.cast(value)).to be_nil, "expected #{value.inspect} to cast to nil"
    end
  end
end
