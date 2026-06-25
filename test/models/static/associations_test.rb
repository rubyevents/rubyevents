require "test_helper"

class Static::AssociationsTest < ActiveSupport::TestCase
  test "event.talks returns a collection" do
    event = Static::Event.find_by_slug("rubyconf-2026")

    assert_instance_of Yerba::Record::Collection, event.talks
    assert event.talks.count > 0
  end

  test "event.talks.first returns a Talk" do
    event = Static::Event.find_by_slug("rubyconf-2026")
    talk = event.talks.first

    assert_instance_of Static::Talk, talk
    assert talk["id"].present?
    assert talk["title"].present?
  end

  test "event.talks.find_by finds by id" do
    event = Static::Event.find_by_slug("rubyconf-2026")
    talk = event.talks.find_by(id: event.talks.first["id"])

    assert_not_nil talk
    assert_equal event.talks.first["title"], talk["title"]
  end

  test "event.cfps returns a collection" do
    event = Static::Event.all.detect { |e| e.cfps.exist? && e.cfps.count > 0 }

    skip "No event with CFPs in test data" unless event

    assert_instance_of Yerba::Record::Collection, event.cfps
    assert event.cfps.first["link"].present?
  end

  test "event.talks returns empty collection for missing videos.yml" do
    event = Static::Event.all.detect { |e| !e.talks.exist? }

    skip "All events have videos.yml" unless event

    assert_equal 0, event.talks.count
    assert event.talks.empty?
  end

  test "event.venue returns a Venue" do
    event = Static::Event.all.detect { |e| e.venue }

    skip "No event with venue in test data" unless event

    assert_instance_of Static::Venue, event.venue
    assert event.venue.name.present?
  end

  test "event.venue returns nil for missing venue.yml" do
    event = Static::Event.all.detect { |e| e.venue.nil? }

    skip "All events have venue.yml" unless event

    assert_nil event.venue
  end

  test "event.schedule returns a Schedule" do
    event = Static::Event.all.detect { |e| e.schedule }

    skip "No event with schedule in test data" unless event

    assert_instance_of Static::Schedule, event.schedule
  end

  test "build_venue returns an unsaved record" do
    event = Static::Event.all.detect { |e| e.venue.nil? }

    skip "All events have venue.yml" unless event

    venue = event.build_venue(name: "Test Venue")

    assert_equal "Test Venue", venue.name
    assert venue.new_record?
    assert_not_nil venue.persist_path
    assert venue.persist_path.end_with?("venue.yml")
  end

  test "create_venue creates the file and returns the record" do
    tmp_dir = Dir.mktmpdir
    event_dir = File.join(tmp_dir, "test-series", "test-event")
    FileUtils.mkdir_p(event_dir)

    File.write(File.join(event_dir, "event.yml"), "---\ntitle: Test\nkind: conference\n")

    document = Yerba::Record::Document.new(File.join(event_dir, "event.yml"))
    event = Static::Event.new(document: document)
    event.define_singleton_method(:event_dir) { event_dir }

    assert_nil event.venue

    venue = event.create_venue(
      name: "New Venue",
      address: {street: "123 Main St", city: "Portland", country: "US", country_code: "US", display: "123 Main St, Portland, US"},
      coordinates: {latitude: 45.5, longitude: -122.6}
    )

    assert_equal "New Venue", venue.name
    assert File.exist?(File.join(event_dir, "venue.yml"))
  ensure
    FileUtils.rm_rf(tmp_dir)
  end

  test "event.series returns the EventSeries" do
    event = Static::Event.find_by_slug("rubyconf-2026")

    assert_instance_of Static::EventSeries, event.series
    assert_equal "RubyConf", event.series.name
  end

  test "talk.event returns the Event" do
    talk = Static::Talk.all.first

    assert_instance_of Static::Event, talk.event
    assert talk.event.title.present?
  end

  test "talk.event_slug is derived from file path" do
    talk = Static::Talk.all.first

    assert talk.event_slug.present?
    assert_equal talk.event.slug, talk.event_slug
  end

  test "cfp.event returns the Event" do
    cfp = Static::CFP.all.first

    assert_instance_of Static::Event, cfp.event
  end

  test "series.events returns events" do
    series = Static::EventSeries.find_by_slug("rubyconf")

    assert series.events.count > 0
    assert series.events.all? { |event| event.series_slug == "rubyconf" }
  end

  test "talk.series returns the EventSeries through event" do
    talk = Static::Talk.all.first

    assert_instance_of Static::EventSeries, talk.series
    assert_equal talk.event.series.name, talk.series.name
  end

  test "talk.speakers returns a ReferencesProxy" do
    event = Static::Event.find_by_slug("rubyconf-2026")
    talk = event.talks.first

    assert talk.speakers.respond_to?(:each)
    assert talk.speakers.respond_to?(:names)
  end
end
