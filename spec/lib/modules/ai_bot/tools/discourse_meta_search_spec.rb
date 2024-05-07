# frozen_string_literal: true
RSpec.describe DiscourseAi::AiBot::Tools::DiscourseMetaSearch do
  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_openai_api_key = "asd"
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  let(:mock_search_json) { plugin_file_from_fixtures("search.json", "search_meta").read }

  let(:mock_categories_page_1) do
    plugin_file_from_fixtures("categories_page_1.json", "search_meta").read
  end

  let(:mock_categories_page_2) do
    plugin_file_from_fixtures("categories_page_2.json", "search_meta").read
  end

  before do
    stub_request(:get, "https://meta.discourse.org/categories.json?page=1").to_return(
      status: 200,
      body: mock_categories_page_1,
      headers: {
      },
    )
  end

  before do
    stub_request(:get, "https://meta.discourse.org/categories.json?page=2").to_return(
      status: 200,
      body: mock_categories_page_2,
      headers: {
      },
    )
  end

  it "searches meta.discourse.org" do
    stub_request(:get, "https://meta.discourse.org/search.json?q=test").to_return(
      status: 200,
      body: mock_search_json,
      headers: {
      },
    )

    search = described_class.new({ search_query: "test" }, bot_user: bot_user, llm: llm)
    results = search.invoke(&progress_blk)
    expect(results[:rows].length).to eq(20)

    expect(results[:rows].first[results[:column_names].index("category")]).to eq(
      "documentation > developers",
    )
  end

  it "passes on all search parameters" do
    url =
      "https://meta.discourse.org/search.json?q=test%20category:test%20user:test%20order:test%20max_posts:1%20tags:test%20before:test%20after:test%20status:test"

    stub_request(:get, url).to_return(status: 200, body: mock_search_json, headers: {})
    params =
      described_class.signature[:parameters]
        .map do |param|
          if param[:type] == "integer"
            [param[:name], 1]
          else
            [param[:name], "test"]
          end
        end
        .to_h
        .symbolize_keys

    search = described_class.new(params, bot_user: bot_user, llm: llm)
    results = search.invoke(&progress_blk)

    expect(results[:args]).to eq(params)
  end
end
