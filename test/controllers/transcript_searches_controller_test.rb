require "test_helper"

class TranscriptSearchesControllerTest < ActionDispatch::IntegrationTest
  test "renders the transcript search page without a query" do
    get transcript_search_path
    assert_response :success
  end

  test "renders the transcript search page with a query" do
    get transcript_search_path(q: "rails")
    assert_response :success
  end
end
