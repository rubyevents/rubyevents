require "test_helper"

class Static::EventTest < ActiveSupport::TestCase
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
