# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkDatesTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"video_id" => "x", "date" => "2024-01-15"}]) do |path|
      assert Static::Validators::TalkDates.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    assert_not Static::Validators::TalkDates.new(file_path: file).applicable?
  end

  test "flags published_at before the talk date" do
    videos = [{"date" => "2024-01-15", "published_at" => "2024-01-10"}]

    with_temp_video(videos, event: event_yaml) do |path|
      errors = Static::Validators::TalkDates.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be before the talk date") }
    end
  end

  test "valid when published_at is on or after the talk date" do
    videos = [{"date" => "2024-01-15", "published_at" => "2024-01-20T09:00:00Z"}]

    with_temp_video(videos, event: event_yaml) do |path|
      assert_empty Static::Validators::TalkDates.new(file_path: path).errors
    end
  end

  test "compares published_at in the event timezone, not UTC" do
    event = {"kind" => "conference", "start_date" => "2023-05-11", "end_date" => "2023-05-11", "timezone" => "Asia/Tokyo"}
    videos = [{"date" => "2023-05-11", "published_at" => "2023-05-10T20:00:00Z"}]

    with_temp_video(videos, event: event) do |path|
      assert_empty Static::Validators::TalkDates.new(file_path: path).errors
    end
  end

  test "flags a talk date outside the event range" do
    videos = [{"date" => "2024-03-01", "published_at" => "2024-03-05"}]

    with_temp_video(videos, event: event_yaml) do |path|
      errors = Static::Validators::TalkDates.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must be within the event dates") }
    end
  end

  test "valid when the talk date is within the event range" do
    videos = [{"date" => "2024-01-16", "published_at" => "2024-02-01"}]

    with_temp_video(videos, event: event_yaml) do |path|
      assert_empty Static::Validators::TalkDates.new(file_path: path).errors
    end
  end

  test "skips the range check when there is no event.yml" do
    videos = [{"date" => "2024-03-01", "published_at" => "2024-03-05"}]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkDates.new(file_path: path).errors
    end
  end

  test "checks nested talks" do
    videos = [{"video_provider" => "children", "talks" => [{"date" => "2024-01-16", "published_at" => "2024-01-01"}]}]

    with_temp_video(videos, event: event_yaml) do |path|
      errors = Static::Validators::TalkDates.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be before the talk date") }
    end
  end

  private

  def event_yaml
    {"kind" => "conference", "start_date" => "2024-01-15", "end_date" => "2024-01-17"}
  end

  def with_temp_video(videos, event: nil)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "2024", "videos.yml")

    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, videos.to_yaml)
    File.write(File.join(File.dirname(videos_path), "event.yml"), event.to_yaml) if event

    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
