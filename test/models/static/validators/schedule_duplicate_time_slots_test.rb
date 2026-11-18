# frozen_string_literal: true

require "test_helper"

class Static::Validators::ScheduleDuplicateTimeSlotsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "applicable? returns true for a schedule.yml file" do
    path = Dir.glob(Rails.root.join("data/**/schedule.yml")).first
    assert Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).applicable?
  end

  test "applicable? returns false for a videos.yml file" do
    path = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    assert_not Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).applicable?
  end

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

    with_raw_schedule(raw) do |path|
      assert_empty Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).errors
    end
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

    with_raw_schedule(raw) do |path|
      assert_empty Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).errors
    end
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

    with_raw_schedule(raw) do |path|
      assert_empty Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).errors
    end
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

    with_raw_schedule(raw) do |path|
      errors = Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).errors.map(&:to_h)

      assert_equal 2, errors.size
      assert_equal [10, 14], errors.map { |error| error["line"] }
      assert errors.all? { |error| error["message"].include?(%(slots at 14:40-15:10 on "Day 1" repeat the start_time and end_time of the row on line 6)) }
      assert errors.all? { |error| error["message"].include?("bin/rails validate:fix") }
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

    with_raw_schedule(raw) do |path|
      validator = Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path)
      errors = validator.errors.map(&:to_h)

      assert_equal 1, errors.size
      assert_includes errors.first["message"], "Fix the time if it's a typo"
      assert_not_includes errors.first["message"], "validate:fix"
      assert_nil validator.fix
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

    with_raw_schedule(raw) do |path|
      validator = Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path)

      assert_equal 1, validator.errors.size
      assert_nil validator.fix
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

    with_raw_schedule(raw) do |path|
      result = Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).fix

      assert_equal({changed: 1, file_path: path}, result)

      grid = Yerba.parse_file(path).to_h.dig("days", 0, "grid")

      assert_equal 2, grid.size
      assert_equal({"start_time" => "14:40", "end_time" => "15:10", "slots" => 3}, grid.first)
      assert_empty Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).errors
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

    with_raw_schedule(raw) do |path|
      Static::Validators::ScheduleDuplicateTimeSlots.new(file_path: path).fix

      grid = Yerba.parse_file(path).to_h.dig("days", 0, "grid")

      assert_equal 1, grid.size
      assert_equal 3, grid.first["slots"]
      assert_equal ["Early registration", "Pre-conference meetup", "Drinks"], grid.first["items"].map { |item| item.is_a?(Hash) ? item["title"] : item }
      assert_includes File.read(path), "description: |-\n              Meet other attendees."
    end
  end

  test "is registered as a fixable schedule validator" do
    assert_includes Static::Validators::Validator.schedule_validator_classes, Static::Validators::ScheduleDuplicateTimeSlots
    assert_includes Static::Validators::Validator.fixable_validators, Static::Validators::ScheduleDuplicateTimeSlots
  end

  private

  def with_raw_schedule(raw)
    with_static_data_dir do |dir|
      schedule_path = File.join(dir, "data", "testconf", "2026", "schedule.yml")

      FileUtils.mkdir_p(File.dirname(schedule_path))
      File.write(schedule_path, raw)
      File.write(File.join(File.dirname(schedule_path), "videos.yml"), "---\n[]\n")
      File.write(File.join(File.dirname(schedule_path), "event.yml"), %(---\nid: "2026"\ntitle: "TestConf 2026"\nkind: "conference"\n))

      yield schedule_path
    end
  end
end
