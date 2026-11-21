# frozen_string_literal: true

require "test_helper"

class Static::ScheduleDuplicateTimeSlotsValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "valid when every row of a day has its own time" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "10:00"
              slots: 2

            - start_time: "10:00"
              end_time: "11:00"
              slots: 1
    YAML

    with_schedule(raw) { |schedule| assert_empty duplicate_errors(schedule) }
  end

  test "valid when the same time shows up on different days" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "10:00"
              slots: 1

        - name: "Day 2"
          date: "2026-05-08"
          grid:
            - start_time: "09:00"
              end_time: "10:00"
              slots: 1
    YAML

    with_schedule(raw) { |schedule| assert_empty duplicate_errors(schedule) }
  end

  test "valid when a talk row and an items row share a time" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "12:00"
              end_time: "13:00"
              slots: 1
              items:
                - "Lunch"

            - start_time: "12:00"
              end_time: "13:00"
              slots: 1
    YAML

    with_schedule(raw) { |schedule| assert_empty duplicate_errors(schedule) }
  end

  test "flags every repeated row and points at the first one" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "14:40"
              end_time: "15:10"
              slots: 1

            - start_time: "14:40"
              end_time: "15:10"
              slots: 1

            - start_time: "14:40"
              end_time: "15:10"
              slots: 1
    YAML

    with_schedule(raw) do |schedule|
      errors = duplicate_errors(schedule)

      assert_equal 2, errors.size
      assert_equal [10, 14], errors.map { |error| schedule.error_location(error).start_line }
      assert errors.all? { |error| error.message.include?(%(slots at 14:40-15:10 on "Day 1" repeat the start_time and end_time of the row on line 6)) }
      assert errors.all? { |error| error.message.include?("bin/rails validate:fix") }
    end
  end

  test "does not suggest the fix when the duplicate rows are not next to each other" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "16:00"
              end_time: "16:30"
              slots: 1
              items:
                - "Break"

            - start_time: "16:30"
              end_time: "17:00"
              slots: 1

            - start_time: "16:00"
              end_time: "16:30"
              slots: 1
              items:
                - "Break"
    YAML

    with_schedule(raw) do |schedule, path|
      errors = duplicate_errors(schedule)

      assert_equal 1, errors.size
      assert_includes errors.first.message, "Fix the time if it's a typo"
      assert_not_includes errors.first.message, "validate:fix"
      assert_empty fix(path)
    end
  end

  test "does not suggest the fix when the duplicate rows have different descriptions" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "10:00"
              slots: 1
              description: "Main hall"

            - start_time: "09:00"
              end_time: "10:00"
              slots: 1
              description: "Side hall"
    YAML

    with_schedule(raw) do |schedule, path|
      assert_equal 1, duplicate_errors(schedule).size
      assert_empty fix(path)
    end
  end

  test "fix merges adjacent talk rows into one row with the summed slots" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "14:40"
              end_time: "15:10"
              slots: 1

            - start_time: "14:40"
              end_time: "15:10"
              slots: 2

            - start_time: "15:30"
              end_time: "16:00"
              slots: 1
    YAML

    with_schedule(raw) do |_schedule, path|
      assert_equal [1], fix(path).map(&:last)

      grid = Yerba.parse_file(path).to_h.dig("days", 0, "grid")

      assert_equal 2, grid.size
      assert_equal({"start_time" => "14:40", "end_time" => "15:10", "slots" => 3}, grid.first)
      assert_empty duplicate_errors(Static::Schedule.in_file(path).first)
    end
  end

  test "fix merges adjacent item rows and keeps the items and their quote style" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 0"
          date: "2026-05-06"
          grid:
            - start_time: "16:00"
              end_time: "19:00"
              slots: 1
              items:
                - title: "Early registration"
                  description: |-
                    Grab your badge early.

            - start_time: "16:00"
              end_time: "19:00"
              slots: 2
              items:
                - title: "Pre-conference meetup"
                  description: |-
                    Meet other attendees.
                - "Drinks"
    YAML

    with_schedule(raw) do |_schedule, path|
      fix(path)

      grid = Yerba.parse_file(path).to_h.dig("days", 0, "grid")

      assert_equal 1, grid.size
      assert_equal 3, grid.first["slots"]
      assert_equal ["Early registration", "Pre-conference meetup", "Drinks"], grid.first["items"].map { |item| item.is_a?(Hash) ? item["title"] : item }
      assert_includes File.read(path), "description: |-\n              Meet other attendees."
    end
  end

  test "fix merges the duplicates of several days" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "10:00"
              slots: 1

            - start_time: "09:00"
              end_time: "10:00"
              slots: 1

        - name: "Day 2"
          date: "2026-05-08"
          grid:
            - start_time: "09:00"
              end_time: "10:00"
              slots: 1

            - start_time: "09:00"
              end_time: "10:00"
              slots: 1

            - start_time: "09:00"
              end_time: "10:00"
              slots: 1
    YAML

    with_schedule(raw) do |_schedule, path|
      assert_equal [3], fix(path).map(&:last)

      days = Yerba.parse_file(path).to_h["days"]

      assert_equal [[2], [3]], days.map { |day| day["grid"].map { |row| row["slots"] } }
    end
  end

  test "runs when a schedule is saved" do
    assert Static::Schedule.validators.any? { |validator| validator.is_a?(Static::ScheduleDuplicateTimeSlotsValidator) && validator.options[:on].nil? }
  end

  private

  def duplicate_errors(schedule)
    schedule.valid?
    schedule.errors.where(:base).select { |error| error.message.include?("repeat the start_time and end_time") }
  end

  def fix(path)
    Yerba::Record.fix_all(Static::Schedule.in_file(path), only: Static::ScheduleDuplicateTimeSlotsValidator)
  end

  def with_schedule(raw)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "2026", "schedule.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, raw)

      yield Static::Schedule.in_file(path).first, path
    end
  end
end
