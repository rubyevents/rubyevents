# frozen_string_literal: true

require "test_helper"

class Static::Validators::EventRecordingsPublishedDateTest < ActiveSupport::TestCase
  test "applicable? returns true for an event.yml file" do
    with_temp_event({"kind" => "conference"}, []) do |path|
      assert Static::Validators::EventRecordingsPublishedDate.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for a non-event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    assert_not Static::Validators::EventRecordingsPublishedDate.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-existent file" do
    assert_not Static::Validators::EventRecordingsPublishedDate.new(file_path: "/nonexistent/event.yml").applicable?
  end

  test "meetup with a published_at is flagged" do
    with_temp_event({"kind" => "meetup", "recordings_published_date" => "2024-01-01"}, watchable(3)) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be set for meetups") }
    end
  end

  test "meetup without a published_at is valid" do
    with_temp_event({"kind" => "meetup"}, watchable(3)) do |path|
      assert_empty Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
    end
  end

  test "valid when the majority is published and published_at is present and not too early" do
    videos = watchable(3, dates: %w[2025-01-01 2025-01-02 2025-01-03])
    with_temp_event({"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-03"}, videos) do |path|
      assert_empty Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
    end
  end

  test "requires published_at when the majority is published" do
    with_temp_event({"kind" => "conference", "end_date" => "2024-12-31"}, watchable(3)) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("is required when the majority") }
    end
  end

  test "forbids published_at when the majority is not published" do
    videos = watchable(1, dates: ["2025-01-01"]) + providers("scheduled", 3)
    with_temp_event({"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-01"}, videos) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be set unless the majority") }
    end
  end

  test "terminal states are excluded from the majority so an all-recorded event still requires published_at" do
    # 2 watchable + 5 not_recorded: only 2 resolvable talks, both published -> majority.
    videos = watchable(2, dates: %w[2025-01-01 2025-01-02]) + providers("not_recorded", 5)
    with_temp_event({"kind" => "conference", "end_date" => "2024-12-31"}, videos) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("is required when the majority") }
    end
  end

  test "flags a published_at before the end_date" do
    videos = watchable(3, dates: %w[2025-01-01 2025-01-02 2025-01-03])
    with_temp_event({"kind" => "conference", "end_date" => "2025-06-01", "recordings_published_date" => "2025-05-01"}, videos) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be before end_date") }
    end
  end

  test "flags a published_at before the video percentile" do
    videos = watchable(3, dates: %w[2025-01-01 2025-02-01 2025-03-01])
    with_temp_event({"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-15"}, videos) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be before the P90") }
    end
  end

  test "flags a recordings_published_date on an event that has not started yet" do
    with_temp_event({"kind" => "conference", "start_date" => "2099-01-01", "recordings_published_date" => "2099-01-02"}, providers("scheduled", 3)) do |path|
      errors = Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("has not started yet") }
    end
  end

  test "a future event without a recordings_published_date is valid" do
    with_temp_event({"kind" => "conference", "start_date" => "2099-01-01"}, providers("scheduled", 3)) do |path|
      assert_empty Static::Validators::EventRecordingsPublishedDate.new(file_path: path).errors
    end
  end

  test "percentile ignores a single late straggler" do
    dates = Array.new(9) { Date.new(2020, 1, 1) } + [Date.new(2025, 1, 1)]
    assert_equal Date.new(2020, 1, 1), Static::Validators::EventRecordingsPublishedDate.percentile(dates)
  end

  test "percentile of an empty list is nil" do
    assert_nil Static::Validators::EventRecordingsPublishedDate.percentile([])
  end

  private

  def watchable(count, dates: nil)
    Array.new(count) do |i|
      {"video_provider" => "youtube", "published_at" => (dates ? dates[i] : "2025-01-0#{i + 1}")}
    end
  end

  def providers(provider, count)
    Array.new(count) { {"video_provider" => provider} }
  end

  def with_temp_event(event, videos)
    dir = Dir.mktmpdir
    event_path = File.join(dir, "data", "testconf", "2025", "event.yml")
    FileUtils.mkdir_p(File.dirname(event_path))
    File.write(event_path, event.to_yaml)
    File.write(File.join(File.dirname(event_path), "videos.yml"), videos.to_yaml)
    yield event_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
