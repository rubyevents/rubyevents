require "test_helper"

class EventCheckIn::CsvImportTest < ActiveSupport::TestCase
  setup do
    @event = events(:future_conference)
  end

  test "imports CSV with unique connect_ids" do
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,2026-03-13 14:00:00 UTC
      DEF456,test-event,url,2026-03-13 15:00:00 UTC
      GHI789,test-event,url,2026-03-13 16:00:00 UTC
    CSV

    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 3, result[:created]
    assert_equal 0, result[:skipped]
    assert_equal 0, result[:errored]
    assert_equal 3, EventCheckIn.where(event: @event).count
  end

  test "uppercases connect_ids regardless of CSV casing" do
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      abc123,test-event,url,2026-03-13 14:00:00 UTC
    CSV

    EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal "ABC123", EventCheckIn.last.connect_id
  end

  test "deduplicates connect_ids keeping earliest timestamp" do
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,2026-03-13 17:00:00 UTC
      ABC123,test-event,url,2026-03-13 14:00:00 UTC
      ABC123,test-event,url,2026-03-13 16:00:00 UTC
    CSV

    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 1, result[:created]
    vep = EventCheckIn.find_by(connect_id: "ABC123", event: @event)
    assert_equal Time.parse("2026-03-13 14:00:00 UTC"), vep.checked_in_at
  end

  test "re-importing same CSV reports all as duplicates" do
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,2026-03-13 14:00:00 UTC
      DEF456,test-event,url,2026-03-13 15:00:00 UTC
    CSV

    EventCheckIn.import_from_csv(event: @event, csv_content: csv)
    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 0, result[:created]
    assert_equal 2, result[:skipped]
    assert_equal 0, result[:errored]
  end

  test "overlapping CSVs report correct created and skipped counts" do
    csv1 = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,2026-03-13 14:00:00 UTC
    CSV

    csv2 = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,2026-03-13 14:00:00 UTC
      DEF456,test-event,url,2026-03-13 15:00:00 UTC
    CSV

    EventCheckIn.import_from_csv(event: @event, csv_content: csv1)
    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv2)

    assert_equal 1, result[:created]
    assert_equal 1, result[:skipped]
  end

  test "skips rows with blank connect_id" do
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      ,test-event,url,2026-03-13 14:00:00 UTC
      ABC123,test-event,url,2026-03-13 15:00:00 UTC
    CSV

    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 1, result[:created]
    assert_equal 1, result[:errored]
  end

  test "skips rows with unparseable created_at" do
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,not-a-date
      DEF456,test-event,url,2026-03-13 15:00:00 UTC
    CSV

    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 1, result[:created]
    assert_equal 1, result[:errored]
  end

  test "empty CSV returns zero counts" do
    csv = "connect_id,event,scan_type,created_at\n"

    result = EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 0, result[:created]
    assert_equal 0, result[:skipped]
    assert_equal 0, result[:errored]
  end

  test "imports associate records with the specified event" do
    other_event = events(:wnb_rb_meetup)
    csv = <<~CSV
      connect_id,event,scan_type,created_at
      ABC123,test-event,url,2026-03-13 14:00:00 UTC
    CSV

    EventCheckIn.import_from_csv(event: @event, csv_content: csv)

    assert_equal 1, EventCheckIn.where(event: @event).count
    assert_equal 0, EventCheckIn.where(event: other_event).count
  end
end
