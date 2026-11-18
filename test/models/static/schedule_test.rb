require "test_helper"

class Static::ScheduleTest < ActiveSupport::TestCase
  include StaticDataSandbox

  SCHEDULE = <<~YAML
    ---
    days:
      - name: "Day 1"
        date: "2024-05-01"
        grid:
          - start_time: "09:00"
            end_time: "10:00"
            slots: 1

          - start_time: "14:40"
            end_time: "15:10"
            slots: 1

          - start_time: "14:40"
            end_time: "15:10"
            slots: 1

      - name: "Day 2"
        date: "2024-05-02"
        grid:
          - start_time: "09:00"
            end_time: "17:00"
            slots: 1
  YAML

  test "days and their grid rows are nested records" do
    with_schedule do |schedule|
      assert_equal ["Day 1", "Day 2"], schedule.days.map { |day| day["name"] }

      row = schedule.days.first.grid.last

      assert_instance_of Static::Schedule::Row, row
      assert_equal "Day 1", row.day["name"]
      assert_equal "days[0].grid[2]", row.selector
      assert_equal 14, row.source_line
    end
  end

  test "grid rows can be changed and destroyed" do
    with_schedule do |schedule, path|
      first, duplicate = schedule.days.first.grid.to_a.last(2)

      first["slots"] = 2
      duplicate.destroy
      schedule.save!

      document = Yerba.parse_file(path)

      assert_equal [1, 2], document.value_at("days[0].grid[].slots")
      assert_equal [1], document.value_at("days[1].grid[].slots")
    end
  end

  private

  def with_schedule
    with_static_data_dir do |root|
      path = File.join(root, "data/testconf/testconf-2024/schedule.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, SCHEDULE)

      yield Static::Schedule.in_file(path).first, path
    end
  end
end
