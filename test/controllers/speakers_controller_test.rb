require "test_helper"

class SpeakersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @speaker = speakers(:one)
    @speaker_with_talk = speakers(:two)

    @speaker_with_talk.talks << talks(:one)
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
    assert_response :success
  end

  test "should show speaker with talks" do
    get speaker_url(@speaker_with_talk)
    assert_response :success
    assert_equal @speaker_with_talk.talks_count, assigns(:talks).length
  end

  test "should redirect to canonical speaker" do
    talk = @speaker_with_talk.talks.first
    @speaker_with_talk.assign_canonical_speaker!(canonical_speaker: @speaker)
    @speaker_with_talk.reload
    assert_equal @speaker, @speaker_with_talk.canonical
    assert @speaker.talks.ids.include?(talk.id)
    assert @speaker_with_talk.talks.empty?

    get speaker_url(@speaker_with_talk)
    assert_redirected_to speaker_url(@speaker)
  end

  test "should get edit in a remote modal" do
    get edit_speaker_url(@speaker), headers: {"Turbo-Frame" => "modal"}
    assert_response :success
    assert_template "speakers/edit"
  end

  test "should redirect to root when not in a remote modal" do
    get edit_speaker_url(@speaker)
    assert_response :redirect
    assert_redirected_to root_url
  end

  test "should create a suggestion for speaker" do
    patch speaker_url(@speaker), params: {speaker: {bio: "new bio", github: "new-github", name: "new-name", slug: "new-slug", twitter: "new-twitter", website: "new-website"}}

    @speaker.reload

    assert_redirected_to speaker_url(@speaker)
    assert_not_equal @speaker.reload.bio, "new bio"
    assert_equal 1, @speaker.suggestions.pending.count
  end

  test "admin can update directly the speaker" do
    sign_in_as users(:admin)
    patch speaker_url(@speaker), params: {speaker: {bio: "new bio", github: "new-github", name: "new-name", slug: "new-slug", twitter: "new-twitter", website: "new-website"}}

    @speaker.reload

    assert_redirected_to speaker_url(@speaker)
    assert_equal "new bio", @speaker.reload.bio
    assert_equal 0, @speaker.suggestions.pending.count
    assert_equal users(:admin).id, @speaker.suggestions.last.suggested_by_id
  end

  test "owner can update the speaker directly" do
    user = User.create!(email: "test@example.com", password: "Secret1*3*5*", github_handle: @speaker.github, verified: true)
    assert user.persisted?
    assert_equal user, @speaker.user

    sign_in_as user

    assert_no_changes -> { @speaker.suggestions.pending.count } do
      patch speaker_url(@speaker), params: {speaker: {bio: "new bio", name: "new-name", twitter: "new-twitter", website: "new-website"}}
    end

    assert_redirected_to speaker_url(@speaker)
    assert_equal "new bio", @speaker.reload.bio
    assert_equal @speaker.name, "new-name"
    assert_equal @speaker.twitter, "new-twitter"
    assert_equal @speaker.website, "https://new-website"
    assert_equal user.id, @speaker.suggestions.last.suggested_by_id
  end

  test "owner can't update own github handle or slug" do
    user = User.create!(email: "test@example.com", password: "Secret1*3*5*", github_handle: @speaker.github, verified: true)
    assert user.persisted?
    assert_equal user, @speaker.user

    sign_in_as user

    assert_difference -> { @speaker.suggestions.pending.count }, 1 do
      patch speaker_url(@speaker), params: {speaker: {github: "new-github", slug: "new-slug"}}
    end

    assert_redirected_to speaker_url(@speaker)

    suggestion = @speaker.suggestions.pending.last

    assert_equal ({"github" => "new-github", "slug" => "new-slug"}), suggestion.content
    assert_equal user.id, suggestion.suggested_by_id

    # those attributes can't be changed by the owner
    assert_not_equal @speaker.slug, "new-slug"
    assert_not_equal @speaker.github, "new-github"
  end

  test "should create a second suggestion if owner updates bio and github handle" do
    user = User.create!(email: "test@example.com", password: "Secret1*3*5*", github_handle: @speaker.github, verified: true)
    assert user.persisted?
    assert_equal user, @speaker.user

    sign_in_as user

    assert_equal 0, @speaker.suggestions.approved.count
    assert_equal 0, @speaker.suggestions.pending.count

    assert_difference -> { @speaker.suggestions.count }, 2 do
      patch speaker_url(@speaker), params: {speaker: {name: "new-name", github: "new-github"}}
    end

    assert_redirected_to speaker_url(@speaker)

    assert_equal 1, @speaker.suggestions.approved.count
    assert_equal 1, @speaker.suggestions.pending.count

    @speaker.reload

    assert_equal @speaker.name, "new-name"
    assert_not_equal @speaker.github, "new-github"
  end

  test "should get index as JSON" do
    speaker = speakers(:two)
    canonical = speakers(:jim)
    speaker.assign_canonical_speaker!(canonical_speaker: canonical)
    speaker.reload

    get speakers_url(canonical: false, with_talks: false), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    speaker_names = json_response["speakers"].map { |speaker_data| speaker_data["name"] }
    canonical_slugs = json_response["speakers"].map { |speaker_data| speaker_data["canonical_slug"] }

    assert_includes speaker_names, @speaker_with_talk.name
    assert_includes canonical_slugs, canonical.slug
  end

  test "should get index as JSON with all canonical speakers includind speakers without talks" do
    get speakers_url(with_talks: false), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    speaker_names = json_response["speakers"].map { |speaker_data| speaker_data["name"] }

    assert_equal speaker_names.count, Speaker.all.count
  end

  test "discarded speaker_talks" do
    speaker = speakers(:yaroslav)
    assert speaker.talks_count.positive?

    speaker.speaker_talks.each(&:discard)

    get speaker_url(speaker)
    assert_response :success
    assert_equal 0, assigns(:talks).count
  end
end
