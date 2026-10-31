require "test_helper"

class SpeakersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @speaker = users(:zero_talks)
    @speaker_with_talk = users(:marco)
  end

  test "should get index" do
    get speakers_url
    assert_response :success

    assert_select "##{dom_id(@speaker)}", 0
    assert_select "##{dom_id(@speaker_with_talk)}", 1
  end

  test "should get index with search results" do
    get speakers_url(s: "John")
    assert_response :success
    assert_select "h1", /Speakers/i
    assert_select "h1", /search results for "John"/i
  end

  test "should show highlights and the full directory" do
    get speakers_url
    assert_response :success
    assert_select "h2", "All Speakers"
    assert_select "p", /Rubyists have shared their work on stage/
  end

  test "should hide highlights when filtering by letter" do
    get speakers_url(letter: "m")
    assert_response :success
    assert_select "p", text: /Rubyists have shared their work on stage/, count: 0
    assert_select "##{dom_id(@speaker_with_talk)}", 1
  end

  test "should get index sorted by talks and by recent activity" do
    %w[talks recent].each do |sort|
      get speakers_url(sort: sort)
      assert_response :success
      assert_select ".tab-active", (sort == "talks") ? "Most talks" : "Recently active"
      assert_select "##{dom_id(@speaker_with_talk)}", 1
    end
  end

  test "should leave out the placeholder speaker when sorting by talks" do
    placeholder = User.create!(name: Talk::StaticID::PLACEHOLDER_SPEAKER, talks_count: 999)

    get speakers_url(sort: "talks")
    assert_response :success
    assert_select "##{dom_id(placeholder)}", 0
    assert_select "##{dom_id(@speaker_with_talk)}", 1
  end

  test "should ignore unknown sorts" do
    get speakers_url(sort: "users.id; DROP TABLE users")
    assert_response :success
    assert_select ".tab-active", "A–Z"
  end

  test "should show speaker" do
    get speaker_url(@speaker)
    assert_response :moved_permanently
  end

  test "should get index as JSON" do
    speaker = users(:one)
    canonical = users(:marco)
    speaker.assign_canonical_speaker!(canonical_speaker: canonical)

    get speakers_url(canonical: false, with_talks: false), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    speaker_names = json_response["speakers"].map { |speaker_data| speaker_data["name"] }

    assert_includes speaker_names, @speaker_with_talk.name
  end

  test "should get index as JSON with all canonical speakers including speakers without talks" do
    get speakers_url(with_talks: false), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    speaker_names = json_response["speakers"].map { |speaker_data| speaker_data["name"] }

    assert_equal speaker_names.count, User.speakers.count
  end
end
