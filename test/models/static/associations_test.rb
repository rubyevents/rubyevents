require "test_helper"

class Static::AssociationsTest < ActiveSupport::TestCase
  test "event.videos returns a collection" do
    event = Static::Event.find_by_slug("rubyconf-2026")

    assert_instance_of Yerba::Record::Collection, event.videos
    assert event.videos.count > 0
  end

  test "event.videos.first returns a Video entry" do
    event = Static::Event.find_by_slug("rubyconf-2026")
    video = event.videos.first

    assert_instance_of Static::Video, video
    assert video["id"].present?
    assert video["title"].present?
  end

  test "event.videos.find_by finds by id" do
    event = Static::Event.find_by_slug("rubyconf-2026")
    video = event.videos.find_by(id: event.videos.first["id"])

    assert_not_nil video
    assert_equal event.videos.first["title"], video["title"]
  end

  test "video.speakers returns a list" do
    event = Static::Event.find_by_slug("rubyconf-2026")
    video = event.videos.first

    assert video.speakers.respond_to?(:each)
  end

  test "video.talks returns Talk entries for meta-videos" do
    event = Static::Event.all.detect do |e|
      e.videos.exist? && e.videos.any? { |v| v["video_provider"] == "children" }
    end

    skip "No meta-video found in test data" unless event

    meta = event.videos.find { |v| v["video_provider"] == "children" }
    talks = meta.talks

    assert talks.is_a?(Array)
    assert talks.first.is_a?(Static::Video) if talks.any?
  end

  test "event.cfps returns a collection" do
    event = Static::Event.all.detect { |e| e.cfps.exist? && e.cfps.count > 0 }

    skip "No event with CFPs in test data" unless event

    assert_instance_of Yerba::Record::Collection, event.cfps
    assert event.cfps.first["link"].present?
  end

  test "event.venue returns a Venue entry" do
    event = Static::Event.all.detect { |e| e.venue.document.exist? }

    skip "No event with venue in test data" unless event

    venue = event.venue
    assert_instance_of Yerba::Record::Base, venue
    assert venue.name.present?
  end

  test "venue.address returns a hash" do
    event = Static::Event.all.detect do |e|
      e.venue.document.exist? && e.venue["address"].present?
    end

    skip "No event with venue address in test data" unless event

    assert event.venue.address.respond_to?(:key?)
  end

  test "event.sponsors returns a collection" do
    event = Static::Event.all.detect { |e| e.sponsors.exist? && e.sponsors.count > 0 }

    skip "No event with sponsors in test data" unless event

    sponsor = event.sponsors.first
    assert_instance_of Yerba::Record::Base, sponsor
    assert sponsor.tiers.respond_to?(:each)
  end

  test "event.involvements returns a collection" do
    event = Static::Event.all.detect { |e| e.involvements.exist? && e.involvements.count > 0 }

    skip "No event with involvements in test data" unless event

    involvement = event.involvements.first
    assert_instance_of Yerba::Record::Base, involvement
    assert involvement["name"].present?
    assert involvement.users.respond_to?(:each)
  end

  test "event.schedule returns a Schedule entry" do
    event = Static::Event.all.detect { |e| e.schedule.document.exist? }

    skip "No event with schedule in test data" unless event

    schedule = event.schedule
    assert_instance_of Yerba::Record::Base, schedule
    assert schedule.days.respond_to?(:each)
  end
end
