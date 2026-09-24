require 'rails_helper'

RSpec.describe Api::V1::BaseController do
  controller do
    skip_before_action :authenticate!

    def index
      page = paginate(Country.order(:code))
      render json: { data: page.records.map(&:code), pagination: page.metadata }
    end

    def cheaper_count
      render json: { pagination: paginate(Country.all, total: 99).metadata }
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      get "cheaper_count" => "anonymous#cheaper_count"
    end
    ("AA".."AG").each { |code| create(:country, code: code) }
  end

  def get_page(params = {})
    get :index, params: params
    response.parsed_body
  end

  it "defaults to the first 25 and reports the ends as null" do
    body = get_page

    expect(body["data"].length).to eq(7)
    expect(body["pagination"]).to eq(
      "total" => 7, "page" => 1, "per_page" => 25, "total_pages" => 1, "prev_page" => nil, "next_page" => nil
    )
  end

  it "walks first, middle and last page" do
    expect(get_page(per_page: 3, page: 1)["data"]).to eq(%w[AA AB AC])
    expect(get_page(per_page: 3, page: 1)["pagination"]).to include("prev_page" => nil, "next_page" => 2)

    expect(get_page(per_page: 3, page: 2)["data"]).to eq(%w[AD AE AF])
    expect(get_page(per_page: 3, page: 2)["pagination"]).to include("prev_page" => 1, "next_page" => 3)

    expect(get_page(per_page: 3, page: 3)["data"]).to eq(%w[AG])
    expect(get_page(per_page: 3, page: 3)["pagination"]).to include("prev_page" => 2, "next_page" => nil)
  end

  it "returns an empty page past the end, pointing back at the last real one" do
    body = get_page(per_page: 3, page: 99)

    expect(body["data"]).to be_empty
    expect(body["pagination"]).to include("total" => 7, "total_pages" => 3, "prev_page" => 3, "next_page" => nil)
  end

  it "is an empty first page with no last link when there is nothing to page" do
    Country.delete_all

    body = get_page

    expect(body["data"]).to be_empty
    expect(body["pagination"]).to include(
      "total" => 0, "total_pages" => 0, "prev_page" => nil, "next_page" => nil
    )
    expect(response.headers["Link"]).not_to include('rel="last"')
  end

  it "is an empty page rather than a 500 past what an offset can hold" do
    body = get_page(page: "99999999999999999999")

    expect(response).to have_http_status(:ok)
    expect(body["data"]).to be_empty
  end

  it "treats a blank page or per_page as absent" do
    expect(get_page(page: "", per_page: "")["pagination"]).to include("page" => 1, "per_page" => 25)
  end

  it "reads page in base 10, so a zero padded number is not octal" do
    expect(get_page(per_page: 3, page: "010")["pagination"]).to include("page" => 10)
  end

  it "clamps per_page at the cap and reports what it used" do
    expect(get_page(per_page: 1000)["pagination"]).to include("per_page" => Pagination::MAX_PER_PAGE)
  end

  it "takes a total from the caller instead of counting the relation" do
    get :cheaper_count

    expect(response.parsed_body["pagination"]).to include("total" => 99, "total_pages" => 4)
  end

  it "is 422 on a page or per_page that is not a positive integer" do
    [ { page: 0 }, { page: -1 }, { page: "abc" }, { per_page: 0 }, { per_page: "abc" } ].each do |params|
      body = get_page(params)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "code")).to eq("validation_failed")
      expect(body.dig("error", "details", 0, "field")).to eq(params.keys.first.to_s)
    end
  end

  it "sets Link and X-Total-Count, carrying the other query params into the links" do
    get :index, params: { per_page: 3, page: 2, q: "eng", "department_id" => %w[a b] }

    expect(response.headers["X-Total-Count"]).to eq("7")
    links = response.headers["Link"].split(", ")
    expect(links.map { |l| l[/rel="(\w+)"/, 1] }).to eq(%w[first prev next last])
    expect(links.find { |l| l.include?('rel="next"') }).to include("page=3", "q=eng", "department_id%5B%5D=a")
  end
end
