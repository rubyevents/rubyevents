# frozen_string_literal: true

require "test_helper"

class Static::Validators::SpeakersOrTalksTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"video_id" => "x", "speakers" => ["Jane"]}]) do |path|
      assert Static::Validators::SpeakersOrTalks.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::SpeakersOrTalks.new(file_path: file).applicable?
  end

  test "valid when only speakers are present" do
    with_temp_video([{"title" => "A talk", "speakers" => ["Jane Doe"]}]) do |path|
      assert_empty Static::Validators::SpeakersOrTalks.new(file_path: path).errors
    end
  end

  test "valid when only talks are present, even when empty" do
    with_temp_video([{"title" => "A meetup", "talks" => []}]) do |path|
      assert_empty Static::Validators::SpeakersOrTalks.new(file_path: path).errors
    end
  end

  test "flags an entry with both talks and speakers" do
    videos = [{"title" => "Both", "speakers" => ["Jane"], "talks" => [{"title" => "Nested", "speakers" => ["Joe"]}]}]

    with_temp_video(videos) do |path|
      errors = Static::Validators::SpeakersOrTalks.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("not both") }
    end
  end

  test "flags an entry with neither talks nor speakers" do
    with_temp_video([{"title" => "Empty", "video_provider" => "not_recorded"}]) do |path|
      errors = Static::Validators::SpeakersOrTalks.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("neither") }
    end
  end

  test "checks nested talks" do
    videos = [{"title" => "Container", "talks" => [{"title" => "Nested has both", "speakers" => ["Joe"], "talks" => []}]}]

    with_temp_video(videos) do |path|
      errors = Static::Validators::SpeakersOrTalks.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("not both") }
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
