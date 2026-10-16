# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkTrackTest < ActiveSupport::TestCase
  SCHEDULE = <<~YAML
    ---
    days: []
    tracks:
      - name: "Main Stage"
        color: "#000000"
      - name: "Workshop"
        color: "#FFFFFF"
  YAML

  test "applicable? returns true for a videos.yml file" do
    with_raw_video("---\n[]\n", schedule: SCHEDULE) do |path|
      assert Static::Validators::TalkTrack.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for a schedule.yml file" do
    file = Dir.glob(Rails.root.join("data/**/schedule.yml")).first
    assert_not Static::Validators::TalkTrack.new(file_path: file).applicable?
  end

  test "valid when every track is defined in schedule.yml" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
      - id: "talk-2"
        track: "Workshop"
      - id: "talk-3"
    YAML

    with_raw_video(raw, schedule: SCHEDULE) do |path|
      assert_empty Static::Validators::TalkTrack.new(file_path: path).errors
    end
  end

  test "flags a track that is not defined in schedule.yml" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
      - id: "talk-2"
        track: "Main stage"
    YAML

    with_raw_video(raw, schedule: SCHEDULE) do |path|
      errors = Static::Validators::TalkTrack.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.to_h["message"], "track \"Main stage\" is not defined"
      assert_includes errors.first.to_h["message"], "\"Main Stage\", \"Workshop\""
      assert_equal 5, errors.first.to_h["line"]
    end
  end

  test "flags a track used by a nested talk" do
    raw = <<~YAML
      ---
      - id: "lightning-talks"
        track: "Main Stage"
        talks:
          - id: "lightning-talk-1"
            track: "Lightning"
    YAML

    with_raw_video(raw, schedule: SCHEDULE) do |path|
      errors = Static::Validators::TalkTrack.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.to_h["message"], "track \"Lightning\" is not defined"
    end
  end

  test "flags tracks when schedule.yml defines no tracks" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
    YAML

    with_raw_video(raw, schedule: "---\ndays: []\n") do |path|
      errors = Static::Validators::TalkTrack.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.to_h["message"], "(defined: none)"
    end
  end

  test "skips events without a schedule.yml" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
    YAML

    with_raw_video(raw) do |path|
      assert_empty Static::Validators::TalkTrack.new(file_path: path).errors
    end
  end

  private

  def with_raw_video(raw, schedule: nil)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "2026", "videos.yml")

    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, raw)
    File.write(File.join(File.dirname(videos_path), "schedule.yml"), schedule) if schedule

    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
