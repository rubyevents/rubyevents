require "test_helper"

class Event::DataFileTest < ActiveSupport::TestCase
  setup do
    @event = events(:brightonruby_2024)
    @static_event = Static::Event.find_by_slug(@event.slug)
  end

  test "has_many files read through the Static::Event associations" do
    assert @event.sponsors_file.exist?
    assert @event.cfp_file.exist?
    assert @event.involvements_file.exist?
    assert @event.videos_file.exist?

    assert_equal @static_event.sponsors.map(&:attributes), @event.sponsors_file.entries
    assert_equal @static_event.cfps.map(&:attributes), @event.cfp_file.entries
    assert_equal @static_event.involvements.map(&:attributes), @event.involvements_file.entries
    assert_equal @static_event.talks.where.missing(:parent).map(&:attributes), @event.videos_file.entries
  end

  test "has_one files read through the Static::Event associations" do
    assert @event.venue.exist?
    assert @event.schedule.exist?

    assert_equal @static_event.venue.attributes, @event.venue.file
    assert_equal @static_event.schedule.attributes, @event.schedule.file
  end

  test "file_path points into the event's data folder" do
    assert_equal Rails.root.join("data", "brightonruby", "brightonruby-2024", "venue.yml"), @event.venue.file_path
  end

  test "sponsors_file exposes tiers and sponsors" do
    tiers = @static_event.sponsors.flat_map { |entry| entry["tiers"] }

    assert_equal tiers.map { |tier| tier["name"] }, @event.sponsors_file.tier_names
    assert_equal tiers.flat_map { |tier| tier["sponsors"] }, @event.sponsors_file.sponsors
  end

  test "files are missing when the event has no Static::Event" do
    event = events(:future_conference)

    assert_nil Static::Event.find_by_slug(event.slug)

    assert_not event.venue.exist?
    assert_not event.sponsors_file.exist?
    assert_equal({}, event.venue.file)
    assert_equal [], event.sponsors_file.entries
  end
end
