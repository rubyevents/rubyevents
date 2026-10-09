# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkShortKindTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"video_id" => "x", "title" => "Opening"}]) do |path|
      assert Static::Validators::TalkShortKind.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::TalkShortKind.new(file_path: file).applicable?
  end

  test "flags a short entry (under 10 minutes) without an explicit kind" do
    with_temp_video([{"title" => "Some Segment", "start_cue" => "00:00", "end_cue" => "05:00", "video_provider" => "not_recorded"}]) do |path|
      errors = Static::Validators::TalkShortKind.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("under 10 minutes") }
    end
  end

  test "does not flag a short entry that has an explicit kind" do
    with_temp_video([{"title" => "Some Segment", "kind" => "intro", "start_cue" => "00:00", "end_cue" => "05:00", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkShortKind.new(file_path: path).errors
    end
  end

  test "does not flag an entry that is 10 minutes or longer" do
    with_temp_video([{"title" => "Some Segment", "start_cue" => "00:00", "end_cue" => "10:00", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkShortKind.new(file_path: path).errors
    end
  end

  test "does not flag when the duration cannot be figured out" do
    with_temp_video([{"title" => "Some Segment", "start_cue" => "TODO", "end_cue" => "TODO", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkShortKind.new(file_path: path).errors
    end
  end

  test "does not flag when only one cue is present" do
    with_temp_video([{"title" => "Some Segment", "start_cue" => "00:00", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkShortKind.new(file_path: path).errors
    end
  end

  test "supports HH:MM:SS cues" do
    with_temp_video([{"title" => "Some Segment", "start_cue" => "01:00:00", "end_cue" => "01:05:00", "video_provider" => "not_recorded"}]) do |path|
      errors = Static::Validators::TalkShortKind.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("under 10 minutes") }
    end
  end

  test "checks nested talks" do
    videos = [{"video_provider" => "children", "talks" => [{"title" => "Segment", "start_cue" => "00:00", "end_cue" => "02:00", "video_provider" => "not_recorded"}]}]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkShortKind.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("under 10 minutes") }
    end
  end

  private

  def with_temp_video(videos)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, videos.to_yaml)
    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
