require "test_helper"

class Api::V1::Embed::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    series = EventSeries.create!(name: "Embed Series", slug: "embed-series")
    @event = Event.create!(name: "Embed Event", slug: "embed-event", series: series, start_date: Date.new(2025, 5, 1), end_date: Date.new(2025, 5, 2))

    @keynote_speaker = User.create!(name: "Keynote Speaker", github_handle: "embed-keynote-speaker")
    @speaker = User.create!(name: "Regular Speaker", github_handle: "embed-regular-speaker")
    @attendee = User.create!(name: "Attendee", github_handle: "embed-attendee")
    @interested = User.create!(name: "Interested", github_handle: "embed-interested")

    keynote = Talk.create!(title: "Keynote", event: @event, kind: "keynote", date: @event.start_date, video_provider: "youtube", static_id: "embed-keynote")
    UserTalk.create!(user: @keynote_speaker, talk: keynote)

    talk = Talk.create!(title: "Talk", event: @event, kind: "talk", date: @event.start_date, video_provider: "youtube", static_id: "embed-talk")
    UserTalk.create!(user: @speaker, talk: talk)

    EventParticipation.create!(user: @keynote_speaker, event: @event, role: :speaker)
    EventParticipation.create!(user: @speaker, event: @event, role: :speaker)
    EventParticipation.create!(user: @attendee, event: @event, role: :attendee)
    EventParticipation.create!(user: @interested, event: @event, role: :interested)
  end

  test "show splits keynote speakers from other speakers and excludes interested users" do
    get api_v1_embed_event_url(@event.slug)

    assert_response :success
    json = response.parsed_body

    assert_equal ["Keynote Speaker"], json["participants"]["keynote_speakers"].pluck("name")
    assert_equal ["Regular Speaker"], json["participants"]["speakers"].pluck("name")
    assert_equal ["Attendee"], json["participants"]["attendees"].pluck("name")
    assert_equal({"keynote_speakers" => 1, "speakers" => 1, "attendees" => 1, "total" => 3}, json["counts"])
  end

  test "show finds an event by a former slug" do
    @event.slug_aliases.create!(name: "Old Embed Event", slug: "old-embed-event")

    get api_v1_embed_event_url("old-embed-event")

    assert_response :success
    assert_equal "embed-event", response.parsed_body["slug"]
  end

  test "participants splits keynote speakers from other speakers and excludes interested users" do
    get participants_api_v1_embed_event_url(@event.slug)

    assert_response :success
    json = response.parsed_body

    assert_equal ["Keynote Speaker"], json["participants"]["keynote_speakers"].pluck("name")
    assert_equal ["Regular Speaker"], json["participants"]["speakers"].pluck("name")
    assert_equal ["Attendee"], json["participants"]["attendees"].pluck("name")
    assert_equal 3, json["counts"]["total"]
  end
end
