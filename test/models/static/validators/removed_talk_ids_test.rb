# frozen_string_literal: true

require "test_helper"

class Static::Validators::RemovedTalkIdsTest < ActiveSupport::TestCase
  EXISTING_EVENT_FILE = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml").to_s

  test "applicable? returns true for an event.yml file" do
    assert Static::Validators::RemovedTalkIds.new(file_path: EXISTING_EVENT_FILE).applicable?
  end

  test "applicable? returns false for a videos.yml file" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/videos.yml").to_s

    assert_not Static::Validators::RemovedTalkIds.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-existent file" do
    assert_not Static::Validators::RemovedTalkIds.new(file_path: "/nonexistent/event.yml").applicable?
  end

  test "returns no errors when the event does not declare removed_talk_ids" do
    assert_empty Static::Validators::RemovedTalkIds.new(file_path: EXISTING_EVENT_FILE).errors
  end

  test "returns no errors when the removed id is gone from videos.yml" do
    videos = [{"id" => "john-smith-testconf-2024", "title" => "B"}]

    with_temp_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: videos) do |path|
      assert_empty Static::Validators::RemovedTalkIds.new(file_path: path).errors
    end
  end

  test "flags a removed id that is still in videos.yml" do
    videos = [{"id" => "jane-doe-testconf-2024", "title" => "A"}]

    with_temp_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: videos) do |path|
      errors = Static::Validators::RemovedTalkIds.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(id "jane-doe-testconf-2024" is listed under `removed_talk_ids`, but it is still in videos.yml)
      assert_equal 5, errors.first.line
    end
  end

  test "flags a removed id that survives as an old_id" do
    videos = [{"id" => "jane-doe-keynote-testconf-2024", "old_id" => "jane-doe-testconf-2024", "title" => "A"}]

    with_temp_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: videos) do |path|
      errors = Static::Validators::RemovedTalkIds.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(id "jane-doe-testconf-2024" is listed under `removed_talk_ids`)
    end
  end

  test "flags a removed id nested under a parent talk" do
    videos = [{"id" => "lightning-talks-testconf-2024", "title" => "Lightning Talks", "talks" => [{"id" => "jane-doe-testconf-2024", "title" => "A"}]}]

    with_temp_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: videos) do |path|
      assert_equal 1, Static::Validators::RemovedTalkIds.new(file_path: path).errors.size
    end
  end

  test "only flags the ids that are still present" do
    videos = [{"id" => "jane-doe-testconf-2024", "title" => "A"}]
    removed = ["gone-testconf-2024", "jane-doe-testconf-2024"]

    with_temp_event(removed_talk_ids: removed, videos: videos) do |path|
      errors = Static::Validators::RemovedTalkIds.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, "jane-doe-testconf-2024"
    end
  end

  test "returns no errors when the event has no videos.yml" do
    with_temp_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: nil) do |path|
      assert_empty Static::Validators::RemovedTalkIds.new(file_path: path).errors
    end
  end

  private

  def with_temp_event(removed_talk_ids:, videos:)
    dir = Dir.mktmpdir
    event_path = File.join(dir, "data", "testconf", "testconf-2024", "event.yml")
    FileUtils.mkdir_p(File.dirname(event_path))

    lines = ["---", %(id: "testconf-2024"), %(title: "TestConf 2024"), "removed_talk_ids:"]
    lines += removed_talk_ids.map { |id| %(  - "#{id}") }
    File.write(event_path, lines.join("\n") + "\n")

    File.write(File.join(File.dirname(event_path), "videos.yml"), videos.to_yaml) if videos

    yield event_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
