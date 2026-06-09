require "test_helper"

class LlmVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @talk = talks(:one)
    @speaker = users(:yaroslav)
    @event = events(:rails_world_2023)
    @topic = topics(:activerecord)
  end

  # --- .md page twins ---------------------------------------------------------

  test "talk has a markdown twin at .md" do
    get talk_path(@talk, format: :md)

    assert_response :success
    assert_equal "text/markdown", @response.media_type
    assert_includes @response.body, "# #{@talk.title}"
    assert_includes @response.body, "View this talk on RubyEvents"
  end

  test "speaker, event, and topic have markdown twins at .md" do
    get profile_path(@speaker, format: :md)
    assert_response :success
    assert_equal "text/markdown", @response.media_type
    assert_includes @response.body, "# #{@speaker.name}"

    get event_path(@event, format: :md)
    assert_response :success
    assert_equal "text/markdown", @response.media_type
    assert_includes @response.body, "# #{@event.name}"

    get topic_path(@topic, format: :md)
    assert_response :success
    assert_equal "text/markdown", @response.media_type
    assert_includes @response.body, "# #{@topic.name}"
  end

  # --- content negotiation ----------------------------------------------------

  test "Accept: text/markdown returns the markdown version of an HTML url" do
    get talk_path(@talk), headers: {"Accept" => "text/markdown"}

    assert_response :success
    assert_equal "text/markdown", @response.media_type
    assert_includes @response.body, "# #{@talk.title}"
  end

  test "an unsupported Accept type is rejected with 406" do
    get talk_path(@talk), headers: {"Accept" => "application/xml"}

    assert_response :not_acceptable
  end

  # --- alternate link + headers on the HTML page ------------------------------

  test "HTML page advertises its markdown twin via link tag and Link header" do
    get talk_path(@talk)

    assert_response :success
    assert_select "link[rel=alternate][type='text/markdown']", count: 1
    assert_match %r{rel="alternate".*type="text/markdown"}, @response.headers["Link"].to_s
    assert_includes @response.headers["Vary"].to_s, "Accept"
  end

  # --- llms.txt / llms-full.txt ----------------------------------------------

  test "llms.txt is served as plain text with the expected structure" do
    get "/llms.txt"

    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_includes @response.body, "# RubyEvents"
    assert_includes @response.body, "## Browse"
    assert_includes @response.body, "/llms-full.txt"
  end

  test "llms-full.txt is served as plain text" do
    get "/llms-full.txt"

    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_includes @response.body, "complete talk index"
  end
end
