# frozen_string_literal: true

require "test_helper"

class Static::Validators::SpeakerExistsTest < ActiveSupport::TestCase
  VALID_VIDEOS_FILE = Dir.glob(Rails.root.join("data/**/videos.yml")).first.to_s

  test "applicable? returns true for a videos.yml file" do
    validator = Static::Validators::SpeakerExists.new(file_path: VALID_VIDEOS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-videos file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::SpeakerExists.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::SpeakerExists.new(file_path: "/nonexistent/videos.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors when all speakers exist" do
    videos = [{"title" => "A talk", "speakers" => ["Aaron Bedra"]}].to_yaml
    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)
      assert_empty validator.errors
    end
  end

  test "returns error when top-level speaker is missing" do
    videos = [{"title" => "A talk", "speakers" => ["Unknown Person XYZZY"]}].to_yaml
    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("Unknown Person XYZZY") }
    end
  end

  test "returns error when nested talk speaker is missing" do
    videos = [{"title" => "Panel", "talks" => [{"title" => "Sub", "speakers" => ["Ghost Speaker XYZZY"]}]}].to_yaml
    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("Ghost Speaker XYZZY") }
    end
  end

  test "recognises speaker aliases as valid" do
    videos = [{"title" => "A talk", "speakers" => ["Abdelkader \"Seuros\" Boudih"]}].to_yaml
    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)
      assert_empty validator.errors
    end
  end

  test "errors are Static::Validators::Error objects" do
    videos = [{"title" => "A talk", "speakers" => ["No One XYZZY"]}].to_yaml
    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "returns empty errors for a real videos.yml" do
    validator = Static::Validators::SpeakerExists.new(file_path: VALID_VIDEOS_FILE)
    assert_empty validator.errors
  end

  private

  def with_temp_videos(videos_yaml)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "2025", "videos.yml")
    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, videos_yaml)
    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
