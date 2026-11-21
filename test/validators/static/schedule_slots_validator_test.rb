# frozen_string_literal: true

require "test_helper"

class Static::ScheduleSlotsValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "valid when items fill every slot" do
    assert_empty errors_for(<<~YAML)
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
  end

  test "flags a row that lists more items than it has slots" do
    errors = errors_for(<<~YAML)
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

    assert_equal [[5, %(slots (1) at 09:00-12:00 on "Day 1" has 1 too many items. Update the slot count, remove items from the schedule.yml, or reschedule talks in the videos.yml.)]], errors
  end

  test "valid when items and a matching talk together fill every slot" do
    schedule = <<~YAML
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

    assert_empty errors_for(schedule, videos: <<~YAML)
      - id: "workshop-1"
        date: "2026-05-07"
        start_time: "09:00"
        end_time: "12:00"
    YAML
  end

  test "valid when parallel talks share a start and end time" do
    schedule = <<~YAML
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "10:00"
              end_time: "11:00"
              slots: 2
    YAML

    assert_empty errors_for(schedule, videos: <<~YAML)
      - id: "talk-1"
        date: "2026-05-07"
        start_time: "10:00"
        end_time: "11:00"
      - id: "talk-2"
        date: "2026-05-07"
        start_time: "10:00"
        end_time: "11:00"
    YAML
  end

  test "a talk with times can only fill the row it matches" do
    schedule = <<~YAML
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

    errors = errors_for(schedule, videos: <<~YAML).map(&:last)
      - id: "talk-1"
        date: "2026-05-07"
        start_time: "11:00"
        end_time: "12:00"
    YAML

    assert_equal 1, errors.size
    assert_includes errors.first, "at 10:00-11:00"
  end

  test "does not fill a slot with a talk from another date" do
    schedule = <<~YAML
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 1
    YAML

    errors = errors_for(schedule, videos: <<~YAML).map(&:last)
      - id: "talk-1"
        date: "2026-05-08"
    YAML

    assert_equal 1, errors.size
    assert_includes errors.first, "has 1 unfilled slot."
  end

  test "does not fill a slot with a talk whose times match no row" do
    schedule = <<~YAML
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "10:00"
              end_time: "11:00"
              slots: 1
    YAML

    errors = errors_for(schedule, videos: <<~YAML).map(&:last)
      - id: "talk-1"
        date: "2026-05-07"
        start_time: "14:00"
        end_time: "15:00"
    YAML

    assert_equal 1, errors.size
    assert_includes errors.first, "has 1 unfilled slot."
  end

  test "valid when untimed talks fill every slot" do
    schedule = <<~YAML
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

    assert_empty errors_for(schedule, videos: <<~YAML)
      - id: "talk-1"
        date: "2026-05-07"
      - id: "talk-2"
        date: "2026-05-07"
      - id: "talk-3"
        date: "2026-05-07"
      - id: "talk-4"
        date: "2026-05-07"
    YAML
  end

  test "does not reuse an untimed talk across rows" do
    schedule = <<~YAML
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

    errors = errors_for(schedule, videos: <<~YAML)
      - id: "talk-1"
        date: "2026-05-07"
    YAML

    assert_equal 1, errors.size
    assert_equal 8, errors.first.first
    assert_includes errors.first.last, "at 13:00-14:00"
  end

  test "keeps a separate pool of untimed talks per day" do
    schedule = <<~YAML
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

    errors = errors_for(schedule, videos: <<~YAML).map(&:last)
      - id: "talk-1"
        date: "2026-05-07"
      - id: "talk-2"
        date: "2026-05-08"
      - id: "talk-3"
        date: "2026-05-08"
    YAML

    assert_equal 1, errors.size
    assert_includes errors.first, %(on "Day 1")
  end

  test "flags every row once the pool of untimed talks runs out" do
    schedule = <<~YAML
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

    errors = errors_for(schedule, videos: <<~YAML).map(&:last)
      - id: "talk-1"
        date: "2026-05-07"
      - id: "talk-2"
        date: "2026-05-07"
    YAML

    assert_equal 2, errors.size
    assert errors.any? { |message| message.include?("has 2 unfilled slots.") }
    assert errors.any? { |message| message.include?("at 15:00-16:00") }
  end

  test "reports the slot count, the times and the day" do
    errors = errors_for(<<~YAML)
      days:
        - name: "Day 1"
          date: "2026-05-07"
          grid:
            - start_time: "09:00"
              end_time: "12:00"
              slots: 4
    YAML

    assert_equal [[5, %(slots (4) at 09:00-12:00 on "Day 1" has 4 unfilled slots. Fix by lowering the slot count, adding talks to the videos.yml, or removing items from the schedule.yml.)]], errors
  end

  test "valid without talks when every row lists items" do
    assert_empty errors_for(<<~YAML)
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
  end

  private

  def errors_for(schedule_yaml, videos: "[]\n")
    with_static_data_dir do |root|
      dir = File.join(root, "data", "testconf", "2026")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "schedule.yml"), schedule_yaml)
      File.write(File.join(dir, "videos.yml"), videos)
      File.write(File.join(dir, "event.yml"), %(id: "2026"\ntitle: "TestConf 2026"\nkind: "conference"\n))

      schedule = Static::Schedule.in_file(File.join(dir, "schedule.yml")).first
      schedule.valid?(:lint)
      schedule.errors.map { |error| [schedule.error_location(error)&.start_line, error.full_message] }
    end
  end
end
