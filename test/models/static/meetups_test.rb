# frozen_string_literal: true

require "test_helper"

class Static::MeetupsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "a meetup's folder and id are its series and date" do
    with_meetup_group do |root|
      meetup = Static::Event.find_by_slug("testrb-2026-01-14")

      assert_equal File.join(root, "data/testrb/testrb-2026-01-14/event.yml"), meetup.file_path
      assert_equal "testrb", meetup.series.slug
      assert_equal "testrb-2026-01-14", meetup.talks.first.event.slug
    end
  end

  test "series nest in folders" do
    with_meetup_group(parent: "testorg") do |root|
      series = Static::EventSeries.find_by_slug("testrb")
      parent = Static::EventSeries.find_by_slug("testorg")

      assert_equal "testorg/testrb", series.directory
      assert_equal parent, series.parent
      assert_equal [series], parent.children
      assert_equal [parent], series.ancestors
      assert_equal ["testrb-2026-01-14"], series.events.map { |event| event["id"] }
      assert_equal "testrb", Static::Event.find_by_slug("testrb-2026-01-14").series.slug

      created = Static::Event.create(series_slug: "testrb", title: "Test.rb February 2026", slug: "testrb-2026-02-11", kind: "meetup", location: "Bern, Switzerland", timezone: "Europe/Zurich", videos_file: false)

      assert_equal File.join(root, "data/testorg/testrb/testrb-2026-02-11/event.yml"), created.file_path
      assert_not File.exist?(File.join(root, "data/testorg/testrb/testrb-2026-02-11/videos.yml"))
    end
  end

  test "a nested series' own files don't belong to an event" do
    with_meetup_group(parent: "testorg") do |root|
      File.write(File.join(root, "data/testorg/testrb/involvements.yml"), Yerba::Document.from([{"name" => "Organizer", "users" => [{"name" => "Ada", "from" => "2018"}]}]).to_s)

      assert_empty Static::Involvement.all.to_a
      assert_equal ["Organizer"], Static::EventSeries.find_by_slug("testrb").involvements.map { |involvement| involvement["name"] }
      assert_equal ["Ada"], Static::SeriesInvolvement.all.first.users.names
    end
  end

  test "importing a meetup turns the talk it replaces into an alias, and keeps the talks that moved" do
    with_meetup_group(old_talk_ids: ["testrb-meetup-january-2026"]) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      edition = ::Talk.create!(title: "Test.rb Meetup January 2026", static_id: "testrb-meetup-january-2026", event: group, date: "2026-01-14", video_provider: "children", video_id: "testrb-meetup-january-2026")
      moved = ::Talk.create!(title: "Opening", static_id: "opening-testrb-2026", event: group, parent_talk: edition, date: "2026-01-14", video_provider: "not_recorded", video_id: "opening-testrb-2026")
      edition_slug = edition.slug

      with_seed_smoke_test { Static::Event.find_by_slug("testrb-2026-01-14").import! }

      meetup = ::Event.find_by!(slug: "testrb-2026-01-14")

      assert_equal meetup, moved.reload.event
      assert_nil moved.parent_talk_id
      assert_nil ::Talk.find_by(id: edition.id)
      assert_equal meetup, ::Alias.find_by(aliasable_type: "Event", slug: edition_slug)&.aliasable
    end
  end

  test "importing a meetup turns watched marks on the talk it replaces into attendances" do
    with_meetup_group(old_talk_ids: ["testrb-meetup-january-2026"]) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      edition = ::Talk.create!(title: "Test.rb Meetup January 2026", static_id: "testrb-meetup-january-2026", event: group, date: "2026-01-14", video_provider: "children", video_id: "testrb-meetup-january-2026")
      watcher, bookmarker = users(:one), users(:two)
      edition.watched_talks.create!(user: watcher, watched: true, watched_on: "in_person", watched_at: Time.current)
      edition.watched_talks.create!(user: bookmarker, watched: false, watched_at: Time.current)

      with_seed_smoke_test { Static::Event.find_by_slug("testrb-2026-01-14").import! }

      meetup = ::Event.find_by!(slug: "testrb-2026-01-14")

      assert_equal "attendee", ::EventParticipation.find_by(user: watcher, event: meetup)&.role
      assert_nil ::EventParticipation.find_by(user: bookmarker, event: meetup)
      assert_nil ::Talk.find_by(id: edition.id)
    end
  end

  test "importing a meetup whose recording was cut into its talks marks those talks as watched" do
    with_meetup_group(old_talk_ids: ["testrb-meetup-january-2026"]) do |root|
      videos = File.join(root, "data", "testrb", "testrb-2026-01-14", "videos.yml")
      File.write(videos, Yerba::Document.from([{"id" => "opening-testrb-2026", "title" => "Opening", "date" => "2026-01-14", "start_cue" => "01:00", "end_cue" => "20:00", "published_at" => "2026-01-20", "video_provider" => "youtube", "video_id" => "abc123", "description" => "", "speakers" => ["Ada Lovelace"]}]).to_s)

      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      recording = ::Talk.create!(title: "Test.rb Meetup January 2026", static_id: "testrb-meetup-january-2026", event: group, date: "2026-01-14", video_provider: "youtube", video_id: "abc123", meta_talk: true)
      ::Talk.create!(title: "Opening", static_id: "opening-testrb-2026", event: group, parent_talk: recording, date: "2026-01-14", video_provider: "parent", video_id: "opening-testrb-2026")
      viewer = users(:one)
      recording.watched_talks.create!(user: viewer, watched: true, watched_on: "youtube", watched_at: Time.current, feeling: "inspired")
      viewer.default_watch_list.talks << recording

      with_seed_smoke_test { Static::Event.find_by_slug("testrb-2026-01-14").import! }

      meetup = ::Event.find_by!(slug: "testrb-2026-01-14")
      opening = ::Talk.find_by!(static_id: "opening-testrb-2026")

      assert_nil ::Talk.find_by(id: recording.id)
      assert_equal ["youtube", "abc123", 60, 1200], [opening.video_provider, opening.video_id, opening.start_seconds, opening.end_seconds]
      assert_equal "inspired", opening.watched_talks.find_by(user: viewer, watched: true)&.feeling
      assert_equal [opening], viewer.watch_lists.first.reload.talks.to_a
      assert_nil ::EventParticipation.find_by(user: viewer, event: meetup)
    end
  end

  test "importing a meetup leaves a talk alone that only shares an old id" do
    with_meetup_group(old_talk_ids: ["testrb-meetup-january-2026"]) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      talk = ::Talk.create!(title: "Keynote", static_id: "testrb-meetup-january-2026", event: group, date: "2026-01-14", video_provider: "youtube", video_id: "xyz789")

      with_seed_smoke_test { Static::Event.find_by_slug("testrb-2026-01-14").import! }

      assert ::Talk.exists?(id: talk.id)
    end
  end

  test "importing a series merges the events in old_event_ids into it" do
    with_meetup_group(series_attributes: {"old_event_ids" => ["testrb-meetup"]}) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      group.cfps.create!(name: "Talk at Test.rb", link: "https://example.com/cfp")

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      assert_nil ::Event.find_by(slug: "testrb-meetup")
      assert_equal ["Talk at Test.rb"], series.reload.cfps.map(&:name)
      assert_equal series, ::EventSeries.find_by_slug_or_alias("testrb-meetup")
      assert ::Event.exists?(slug: "testrb-2026-01-14")
    end
  end

  test "merging a group event moves its attendees to the meetup before they marked it" do
    with_meetup_group(series_attributes: {"old_event_ids" => ["testrb-meetup"]}) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      december = ::Event.create!(name: "Test.rb December 2025", slug: "testrb-2025-12-10", kind: :meetup, series: series, start_date: "2025-12-10", end_date: "2025-12-10")
      march = ::Event.create!(name: "Test.rb March 2026", slug: "testrb-2026-03-11", kind: :meetup, series: series, start_date: "2026-03-11", end_date: "2026-03-11")
      after_january, before_any = users(:one), users(:two)
      group.event_participations.create!(user: after_january, role: "attendee", created_at: Time.zone.parse("2026-02-01"))
      group.event_participations.create!(user: before_any, role: "attendee", created_at: Time.zone.parse("2025-06-01"))

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      january = ::Event.find_by!(slug: "testrb-2026-01-14")

      assert_nil ::Event.find_by(slug: "testrb-meetup")
      assert_equal "attendee", ::EventParticipation.find_by(user: after_january, event: january)&.role
      assert_equal "attendee", ::EventParticipation.find_by(user: before_any, event: december)&.role
      refute ::EventParticipation.exists?(user: after_january, event: march)
    end
  end

  test "merging a group event moves interest to the next meetup and check-ins to the meetup of their day" do
    with_meetup_group(series_attributes: {"old_event_ids" => ["testrb-meetup"]}) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      march = ::Event.create!(name: "Test.rb March 2026", slug: "testrb-2026-03-11", kind: :meetup, series: series, start_date: "2026-03-11", end_date: "2026-03-11")
      interested = users(:one)
      group.event_participations.create!(user: interested, role: "interested", created_at: Time.zone.parse("2026-02-01"))
      ::EventCheckIn.create!(event: group, connect_id: "connect-1", checked_in_at: Time.zone.parse("2026-01-14 19:00"))

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      january = ::Event.find_by!(slug: "testrb-2026-01-14")

      assert_nil ::Event.find_by(slug: "testrb-meetup")
      assert_equal "interested", ::EventParticipation.find_by(user: interested, event: march)&.role
      assert_equal [january], ::EventCheckIn.where(connect_id: "connect-1").map(&:event)
    end
  end

  test "a group event whose participants have no meetup to move to isn't merged" do
    with_meetup_group(series_attributes: {"old_event_ids" => ["testrb-meetup"]}) do |root|
      FileUtils.rm_rf(File.join(root, "data/testrb/testrb-2026-01-14"))
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      group.event_participations.create!(user: users(:one), role: "attendee")

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      assert ::Event.exists?(slug: "testrb-meetup")
      assert ::EventParticipation.exists?(user: users(:one), event: group)
    end
  end

  test "a group event with only speakers and no meetups is merged" do
    with_meetup_group(series_attributes: {"old_event_ids" => ["testrb-meetup"]}) do |root|
      FileUtils.rm_rf(File.join(root, "data/testrb/testrb-2026-01-14"))
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      group.event_participations.create!(user: users(:one), role: "speaker")

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      assert_nil ::Event.find_by(slug: "testrb-meetup")
      assert_equal series, ::EventSeries.find_by_slug_or_alias("testrb-meetup")
    end
  end

  test "merging a group event moves its speakers to the meetups they spoke at" do
    with_meetup_group(series_attributes: {"old_event_ids" => ["testrb-meetup"]}) do
      series = ::EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
      group = ::Event.create!(name: "Test.rb Meetup", slug: "testrb-meetup", kind: :meetup, series: series)
      meetup = ::Event.create!(name: "Test.rb January 2026", slug: "testrb-2026-01-14", kind: :meetup, series: series, start_date: "2026-01-14", end_date: "2026-01-14")
      talk = ::Talk.create!(title: "Earlier talk", static_id: "earlier-testrb-2026", event: meetup, date: "2026-01-14", video_provider: "not_recorded", video_id: "earlier-testrb-2026")
      speaker = users(:one)
      talk.user_talks.create!(user: speaker)
      group.event_participations.create!(user: speaker, role: "speaker")

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      assert_nil ::Event.find_by(slug: "testrb-meetup")
      assert_equal "speaker", ::EventParticipation.find_by(user: speaker, event: meetup)&.role
    end
  end

  test "importing a series keeps its organizers and the period they organized it" do
    with_meetup_group do |root|
      File.write(File.join(root, "data/testrb/involvements.yml"), Yerba::Document.from([{"name" => "Organizer", "users" => ["Ada Lovelace", {"name" => "Grace Hopper", "from" => "2018", "to" => "2022-06"}]}]).to_s)

      with_seed_smoke_test { Static::EventSeries.find_by_slug("testrb").import! }

      involvements = ::EventSeries.find_by!(slug: "testrb").event_involvements.includes(:involvementable).order(:position)
      grace = involvements.find { |involvement| involvement.involvementable.name == "Grace Hopper" }

      assert_equal ["Ada Lovelace", "Grace Hopper"], involvements.map { |involvement| involvement.involvementable.name }
      assert_equal Date.new(2018, 1, 1), grace.started_on
      assert_equal Date.new(2022, 6, 30), grace.ended_on
      assert_equal "2018 - Jun 2022", grace.period_label
      assert_equal 2, involvements.active_on(Date.new(2020, 5, 1)).count
      assert_equal 1, involvements.active_on(Date.new(2023, 5, 1)).count
    end
  end

  private

  def with_seed_smoke_test
    ENV["SEED_SMOKE_TEST"] = "true"
    yield
  ensure
    ENV.delete("SEED_SMOKE_TEST")
  end

  def with_meetup_group(parent: nil, old_talk_ids: nil, series_attributes: {})
    with_static_data_dir do |root|
      parent_directory = File.join(root, "data", *parent)

      if parent
        FileUtils.mkdir_p(parent_directory)
        File.write(File.join(parent_directory, "series.yml"), Yerba::Document.from({"id" => parent, "name" => parent.titleize, "kind" => "organisation"}).to_s)
      end

      series_directory = File.join(parent_directory, "testrb")
      meetup_directory = File.join(series_directory, "testrb-2026-01-14")
      FileUtils.mkdir_p(meetup_directory)

      File.write(File.join(series_directory, "series.yml"), Yerba::Document.from({"id" => "testrb", "name" => "Test.rb", "kind" => "meetup", "location" => "Bern, Switzerland", "timezone" => "Europe/Zurich"}.merge(series_attributes)).to_s)
      File.write(File.join(meetup_directory, "event.yml"), Yerba::Document.from({"id" => "testrb-2026-01-14", "title" => "Test.rb January 2026", "kind" => "meetup", "location" => "Bern, Switzerland", "timezone" => "Europe/Zurich", "start_date" => "2026-01-14", "end_date" => "2026-01-14", "old_talk_ids" => old_talk_ids}.compact).to_s)
      File.write(File.join(meetup_directory, "videos.yml"), Yerba::Document.from([{"id" => "opening-testrb-2026", "title" => "Opening", "date" => "2026-01-14", "video_provider" => "not_recorded", "video_id" => "opening-testrb-2026", "description" => "", "speakers" => ["Ada Lovelace"]}]).to_s)

      yield root
    end
  end
end
