require "test_helper"

class Events::SchedulesHelperTest < ActionView::TestCase
  setup do
    @day1 = {"date" => "2026-07-20"}
    @day2 = {"date" => "2026-07-21"}
    @days = [@day1, @day2]
  end

  test "selects the schedule day matching today" do
    travel_to Date.new(2026, 7, 21) do
      assert_equal @day2, selected_schedule_day(@days)
    end
  end

  test "returns the first day before the event" do
    travel_to Date.new(2026, 7, 19) do
      assert_equal @day1, selected_schedule_day(@days)
    end
  end

  test "returns the first day after the event" do
    travel_to Date.new(2026, 7, 22) do
      assert_equal @day1, selected_schedule_day(@days)
    end
  end
end
