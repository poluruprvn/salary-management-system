require 'rails_helper'

RSpec.describe Api::V1::BaseController do
  controller do
    skip_before_action :authenticate!

    def not_found
      raise ActiveRecord::RecordNotFound.new(nil, "Employee")
    end

    def record_invalid
      User.create!(name: "", email: "not an address", password: "x")
    end

    def not_unique
      raise ActiveRecord::RecordNotUnique, "PG::UniqueViolation"
    end

    def unknown_sort_key
      raise UnknownSortKey, "salary"
    end
  end

  before do
    routes.draw do
      get "not_found" => "anonymous#not_found"
      get "record_invalid" => "anonymous#record_invalid"
      get "not_unique" => "anonymous#not_unique"
      get "unknown_sort_key" => "anonymous#unknown_sort_key"
    end
  end

  it "is 404 naming the model" do
    get :not_found

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body["error"]).to eq(
      "code" => "not_found", "message" => "Employee not found", "details" => []
    )
  end

  it "is 422 with one detail per invalid field" do
    get :record_invalid

    expect(response).to have_http_status(:unprocessable_content)
    body = response.parsed_body["error"]
    expect(body["code"]).to eq("validation_failed")
    expect(body["details"]).to contain_exactly(
      { "field" => "name", "message" => "can't be blank" },
      { "field" => "email", "message" => "is invalid" }
    )
    expect(body["message"]).to include("Name can't be blank", "Email is invalid")
  end

  it "is 422 with no details when the index rather than a validation refuses the write" do
    get :not_unique

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq(
      "code" => "validation_failed", "message" => "A record with these values already exists", "details" => []
    )
  end

  it "is 422 naming the sort key, not the error class" do
    get :unknown_sort_key

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq(
      "code" => "validation_failed",
      "message" => "salary is not a sortable key",
      "details" => [ { "field" => "sort", "message" => "salary is not a sortable key" } ]
    )
  end
end
