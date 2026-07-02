# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkPublishedAtTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"video_id" => "x", "video_provider" => "not_recorded"}]) do |path|
      assert Static::Validators::TalkPublishedAt.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    assert_not Static::Validators::TalkPublishedAt.new(file_path: file).applicable?
  end

  ["not_recorded", "scheduled", "not_published", "children", "parent"].each do |provider|
    test "flags published_at present for #{provider}" do
      videos = [{"video_provider" => provider, "published_at" => "2024-01-15"}]

      with_temp_video(videos) do |path|
        errors = Static::Validators::TalkPublishedAt.new(file_path: path).errors
        assert errors.any? { |e| e.to_h["message"].include?("must not be set when video_provider is \"#{provider}\"") }
      end
    end

    test "valid when published_at is absent for #{provider}" do
      with_temp_video([{"video_provider" => provider}]) do |path|
        assert_empty Static::Validators::TalkPublishedAt.new(file_path: path).errors
      end
    end
  end

  test "allows published_at for a watchable provider" do
    videos = [{"video_provider" => "youtube", "published_at" => "2024-01-15T09:00:00Z"}]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkPublishedAt.new(file_path: path).errors
    end
  end

  test "checks nested talks" do
    videos = [{"video_provider" => "children", "talks" => [{"video_provider" => "not_recorded", "published_at" => "2024-01-15"}]}]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkPublishedAt.new(file_path: path).errors
      assert errors.any? { |e| e.to_h["message"].include?("must not be set") }
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
