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

  test "should show speaker" do
    get speaker_url(@speaker)
    assert_response :moved_permanently
  end

  test "should get index as JSON" do
    speaker = users(:one)
    canonical = users(:marco)
    speaker.assign_canonical_speaker!(canonical_speaker: canonical)
    speaker.reload
    assert_equal speaker.canonical, canonical
    assert_equal speaker.canonical_slug, canonical.slug

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
