# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueTalkSpeakersTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox
  include StaticDataSandbox

  setup do
    Static::Validators::UniqueTalkSpeakers.reset!
  end

  teardown do
    Static::Validators::UniqueTalkSpeakers.reset!
  end

  test "applicable? returns true for a videos.yml file" do
    with_raw_video("---\n[]\n") do |path|
      assert Static::Validators::UniqueTalkSpeakers.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for a schedule.yml file" do
    file = Dir.glob(Rails.root.join("data/**/schedule.yml")).first
    assert_not Static::Validators::UniqueTalkSpeakers.new(file_path: file).applicable?
  end

  test "valid when every speaker is listed once" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        speakers:
          - Tom Stuart
          - Tom Stuart @mortice
    YAML

    with_raw_video(raw) do |path|
      assert_empty Static::Validators::UniqueTalkSpeakers.new(file_path: path).errors
    end
  end

  test "flags a speaker listed twice" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        speakers:
          - Tom Stuart
          - Joseph Wilk
          - Tom Stuart
    YAML

    with_raw_video(raw) do |path|
      errors = Static::Validators::UniqueTalkSpeakers.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.to_h["message"], "speaker \"Tom Stuart\" is listed 2 times"
      assert_equal 6, errors.first.to_h["line"]
    end
  end

  test "flags a speaker listed by name and by alias" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        speakers:
          - Tom Stuart @mortice
          - mortice
    YAML

    with_raw_video(raw) do |path|
      errors = Static::Validators::UniqueTalkSpeakers.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.to_h["message"], "(as \"Tom Stuart @mortice\", \"mortice\")"
    end
  end

  test "flags a speaker listed twice in a nested talk" do
    raw = <<~YAML
      ---
      - id: "lightning-talks"
        speakers:
          - Tom Stuart
        talks:
          - id: "lightning-talk-1"
            speakers:
              - Joseph Wilk
              - Joseph Wilk
    YAML

    with_raw_video(raw) do |path|
      errors = Static::Validators::UniqueTalkSpeakers.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.to_h["message"], "speaker \"Joseph Wilk\""
    end
  end

  private

  def with_raw_video(raw)
    with_static_data_dir do |dir|
      videos_path = File.join(dir, "data", "testconf", "2026", "videos.yml")

      FileUtils.mkdir_p(File.dirname(videos_path))
      File.write(videos_path, raw)
      File.write(File.join(File.dirname(videos_path), "event.yml"), %(---\nid: "2026"\ntitle: "TestConf 2026"\nkind: "conference"\n))

      yield videos_path
    end
  end
end
