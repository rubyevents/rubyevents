# frozen_string_literal: true

require "test_helper"

class Static::Validators::ScheduleSlotsFilledTest < ActiveSupport::TestCase
  test "applicable? returns true for a schedule.yml file" do
    path = Dir.glob(Rails.root.join("data/**/schedule.yml")).first
    assert Static::Validators::ScheduleSlotsFilled.new(file_path: path).applicable?
  end

  test "applicable? returns false for a videos.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    assert_not Static::Validators::ScheduleSlotsFilled.new(file_path: file).applicable?
  end

  test "valid when items fill every slot" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 2
              items:
                - "Talk A"
                - "Talk B"
    YAML

    with_raw_schedule(raw) do |path|
      assert_empty Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
    end
  end

  test "flags a row that lists more items than it has slots" do
    raw = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 1
              items:
                - "Talk A"
                - "Talk B"
    YAML

    with_raw_schedule(raw) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("has 1 too many items") }
    end
  end

  test "valid when items and a matching talk together fill every slot" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 2
              items:
                - "Hack Space"
    YAML

    videos = <<~YAML
      ---
      - id: "workshop-1"
        date: "2026-05-07"
        start_time: "09:00"
        end_time: "12:00"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      assert_empty Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
    end
  end

  test "valid when parallel talks share a start and end time" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "10:00"
              end_time: "11:00"
              slots: 2
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
        start_time: "10:00"
        end_time: "11:00"
      - id: "talk-2"
        date: "2026-05-07"
        start_time: "10:00"
        end_time: "11:00"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      assert_empty Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
    end
  end

  test "a talk with times can only fill the row it matches" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "10:00"
              end_time: "11:00"
              slots: 1
            - start_time: "11:00"
              end_time: "12:00"
              slots: 1
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
        start_time: "11:00"
        end_time: "12:00"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors

      assert_equal 1, errors.size
      assert errors.any? { |e| e.to_h["message"].include?("at 10:00-11:00") }
    end
  end

  test "does not fill a slot with a talk from another date" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 1
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-08"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("has 1 unfilled slot.") }
    end
  end

  test "does not fill a slot with a talk whose times match no row" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "10:00"
              end_time: "11:00"
              slots: 1
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
        start_time: "14:00"
        end_time: "15:00"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("has 1 unfilled slot.") }
    end
  end

  test "valid when untimed talks fill every slot" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 2
            - start_time: "13:00"
              end_time: "14:00"
              slots: 2
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
      - id: "talk-2"
        date: "2026-05-07"
      - id: "talk-3"
        date: "2026-05-07"
      - id: "talk-4"
        date: "2026-05-07"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      assert_empty Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
    end
  end

  test "does not reuse an untimed talk across rows" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 1
            - start_time: "13:00"
              end_time: "14:00"
              slots: 1
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors

      assert_equal 1, errors.size
      assert errors.any? { |e| e.to_h["message"].include?("at 13:00-14:00") }
    end
  end

  test "keeps a separate pool of untimed talks per day" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 2
        - name: "Day 2"
          date: "2026-05-08"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 2
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
      - id: "talk-2"
        date: "2026-05-08"
      - id: "talk-3"
        date: "2026-05-08"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors

      assert_equal 1, errors.size
      assert errors.any? { |e| e.to_h["message"].include?("on \"Day 1\"") }
    end
  end

  test "flags every row once the pool of untimed talks runs out" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 2
            - start_time: "13:00"
              end_time: "14:00"
              slots: 2
            - start_time: "15:00"
              end_time: "16:00"
              slots: 1
    YAML

    videos = <<~YAML
      ---
      - id: "talk-1"
        date: "2026-05-07"
      - id: "talk-2"
        date: "2026-05-07"
    YAML

    with_raw_schedule(schedule, videos: videos) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors

      assert_equal 2, errors.size
      assert errors.any? { |e| e.to_h["message"].include?("has 2 unfilled slots.") }
      assert errors.any? { |e| e.to_h["message"].include?("at 15:00-16:00") }
    end
  end

  test "reports the slot count, the times and the day" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 4
    YAML

    with_raw_schedule(schedule) do |path|
      errors = Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
      assert_match "slots (4) at 09:00-12:00 on \"Day 1\" has 4 unfilled slots.", errors.first.message
    end
  end

  test "does not flag a schedule without videos.yml when every row lists items" do
    schedule = <<~YAML
      ---
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 1
              items:
                - title: "City Tour"
                  description: "Get tickets for city tour at website."
    YAML

    with_raw_schedule(schedule) do |path|
      assert_empty Static::Validators::ScheduleSlotsFilled.new(file_path: path).errors
    end
  end

  private

  def with_raw_schedule(raw, videos: "---\n[]".to_yaml)
    Dir.mktmpdir do |dir|
      schedule_path = File.join(dir, "data", "testconf", "2026", "schedule.yml")

      FileUtils.mkdir_p(File.dirname(schedule_path))
      File.write(schedule_path, raw)
      File.write(File.join(File.dirname(schedule_path), "videos.yml"), videos)

      yield schedule_path
    end
  end
end
