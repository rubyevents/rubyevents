require "test_helper"

class Static::EventTest < ActiveSupport::TestCase
  SLUG = "helveticruby-2025"

  test "import!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    ENV["SEED_SMOKE_TEST"] = "true"
    result = event.import!
    assert_equal "Helvetic Ruby 2025", result.name
  ensure
    ENV.delete("SEED_SMOKE_TEST")
  end

  test "import_event!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    result = event.import_event!
    assert_equal "Helvetic Ruby 2025", result.name
  end

  test "import_cfps!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_cfps!(event_record)
    assert event_record.cfps.exists?
  end

  test "import_videos!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_videos!(event_record)
    assert event_record.talks.exists?
  end

  test "import_sponsors!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_sponsors!(event_record)
    assert event_record.sponsors.exists?
  end

  test "import_transcripts!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_videos!(event_record)
    event.import_transcripts!(event_record)
    assert ::Talk::Transcript.exists?
  end

  test "import_involvements!" do
    event = Static::Event.find_by_slug("xoruby-portland-2025")
    event.import_event!
    event_record = event.event_record
    event.import_involvements!(event_record)
    involvements = event_record.reload.event_involvements.pluck(:id)
    event.import_involvements!(event_record)
    assert_equal involvements, event_record.reload.event_involvements.pluck(:id)
    assert_equal 6, event_record.event_involvements.count
  end

  test "today? returns false if event is in the past" do
    event = Static::Event.find_by_slug("railsconf-2025")
    assert_not event.today?
  end
end
