require "test_helper"

class Events::SchedulesHelperTest < ActionView::TestCase
  setup do
    @day1 = { "date" => "2026-07-20" }
    @day2 = { "date" => "2026-07-21" }
    @days = [@day1, @day2]
  end

  test "selects the schedule day matching today" do
    assert_equal @day2, selected_schedule_day(@days, today: "2026-07-21")
  end

  test "returns the first day before the event" do
    assert_equal @day1, selected_schedule_day(@days, today: "2026-01-01")
  end

  test "returns the first day after the event" do
    assert_equal @day1, selected_schedule_day(@days, today: "2027-01-01")
  end
end
