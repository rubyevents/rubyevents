# frozen_string_literal: true

require "test_helper"

class Static::TalkDatesValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  EVENT = {"kind" => "conference", "start_date" => "2024-01-15", "end_date" => "2024-01-17"}.freeze

  test "flags published_at before the talk date" do
    with_talk({"date" => "2024-01-15", "published_at" => "2024-01-10"}, event: EVENT) do |talk|
      assert_equal ["published_at (2024-01-10) must not be before the talk date (2024-01-15)"], date_errors(talk)
    end
  end

  test "does not flag published_at before the talk date when the ignore comment is present" do
    raw = <<~YAML
      ---
      - id: "talk"
        date: "2024-01-15"
        published_at: "2024-01-10" # validator:disable published_at_before_date
    YAML

    with_talk(raw, event: EVENT) do |talk|
      assert_empty date_errors(talk)
    end
  end

  test "the ignore comment only suppresses the matching line" do
    raw = <<~YAML
      ---
      - id: "talk" # validator:disable published_at_before_date
        date: "2024-01-15"
        published_at: "2024-01-10"
    YAML

    with_talk(raw, event: EVENT) do |talk|
      assert_equal 1, date_errors(talk).size
      assert_equal 4, talk.error_location(talk.errors.where(:published_at).first).start_line
    end
  end

  test "valid when published_at is on or after the talk date" do
    with_talk({"date" => "2024-01-15", "published_at" => "2024-01-20T09:00:00Z"}, event: EVENT) do |talk|
      assert_empty date_errors(talk)
    end
  end

  test "compares published_at in the event timezone, not UTC" do
    event = {"kind" => "conference", "start_date" => "2023-05-11", "end_date" => "2023-05-11", "timezone" => "Asia/Tokyo"}

    with_talk({"date" => "2023-05-11", "published_at" => "2023-05-10T20:00:00Z"}, event: event) do |talk|
      assert_empty date_errors(talk)
    end
  end

  test "flags a talk date outside the event range" do
    with_talk({"date" => "2024-03-01", "published_at" => "2024-03-05"}, event: EVENT) do |talk|
      assert_equal ["date (2024-03-01) must be within the event dates (2024-01-15 to 2024-01-17). If this is a pre-conference activity (e.g. workshops or a pre-party) held before the event, add a pre_date to the event.yml."], date_errors(talk)
    end
  end

  test "valid when the talk date is within the event range" do
    with_talk({"date" => "2024-01-16", "published_at" => "2024-02-01"}, event: EVENT) do |talk|
      assert_empty date_errors(talk)
    end
  end

  test "skips supplementary kinds (trailer/recap/aftermovie)" do
    ::Talk::SUPPLEMENTARY_KINDS.each do |kind|
      with_talk({"kind" => kind, "date" => "2024-03-01", "published_at" => "2024-01-01T00:00:00Z"}, event: EVENT) do |talk|
        assert_empty date_errors(talk), "expected #{kind} to be skipped"
      end
    end
  end

  test "allows a talk on the pre_date (before start_date)" do
    event = {"kind" => "conference", "pre_date" => "2024-01-14", "start_date" => "2024-01-15", "end_date" => "2024-01-17"}

    with_talk({"kind" => "workshop", "date" => "2024-01-14", "video_provider" => "not_recorded"}, event: event) do |talk|
      assert_empty date_errors(talk)
    end
  end

  test "still flags a talk before the pre_date" do
    event = {"kind" => "conference", "pre_date" => "2024-01-14", "start_date" => "2024-01-15", "end_date" => "2024-01-17"}

    with_talk({"kind" => "workshop", "date" => "2024-01-10", "video_provider" => "not_recorded"}, event: event) do |talk|
      assert_match(/\Adate \(2024-01-10\) must be within the event dates \(2024-01-14 to 2024-01-17\)\..*add a pre_date/, date_errors(talk).first)
    end
  end

  test "skips the range check when there is no event.yml" do
    with_talk({"date" => "2024-03-01", "published_at" => "2024-03-05"}) do |talk|
      assert_empty date_errors(talk)
    end
  end

  test "checks nested talks" do
    videos = [{"id" => "container", "video_provider" => "children", "talks" => [{"id" => "talk", "date" => "2024-01-16", "published_at" => "2024-01-01"}]}]

    with_talk(videos, event: EVENT) do |talk|
      assert_equal ["published_at (2024-01-01) must not be before the talk date (2024-01-16)"], date_errors(talk)
    end
  end

  private

  def date_errors(talk)
    talk.valid?(:lint)

    talk.errors.full_messages_for(:published_at) + talk.errors.full_messages_for(:date)
  end

  def with_talk(videos, event: nil)
    videos = [{"id" => "talk"}.merge(videos)] if videos.is_a?(Hash)

    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      videos.is_a?(String) ? File.write(path, videos) : Yerba::Document.from(videos).save_to!(path)
      Yerba::Document.from(event).save_to!(File.join(File.dirname(path), "event.yml")) if event

      yield Static::Talk.in_file(path).find_by(id: "talk")
    end
  end
end
