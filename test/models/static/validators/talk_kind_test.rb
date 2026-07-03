# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkKindTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"video_id" => "x", "title" => "Keynote: X"}]) do |path|
      assert Static::Validators::TalkKind.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::TalkKind.new(file_path: file).applicable?
  end

  test "flags an entry whose title infers a non-default kind but has no explicit kind" do
    with_temp_video([{"title" => "Keynote: The Future", "video_provider" => "not_recorded"}]) do |path|
      errors = Static::Validators::TalkKind.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("inferred as \"keynote\"") }
    end
  end

  test "does not flag a plain talk that infers the default kind" do
    with_temp_video([{"title" => "I love Ruby", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkKind.new(file_path: path).errors
    end
  end

  test "does not flag when the kind is set explicitly" do
    with_temp_video([{"title" => "Keynote: The Future", "kind" => "keynote", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkKind.new(file_path: path).errors
    end
  end

  test "respects an explicit kind that disagrees with the inferred one" do
    with_temp_video([{"title" => "Keynote: The Future", "kind" => "talk", "video_provider" => "not_recorded"}]) do |path|
      assert_empty Static::Validators::TalkKind.new(file_path: path).errors
    end
  end

  test "flags a redundant explicit kind: talk when the title also classifies as talk" do
    with_temp_video([{"title" => "I love Ruby", "kind" => "talk", "video_provider" => "not_recorded"}]) do |path|
      errors = Static::Validators::TalkKind.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("redundant") }
    end
  end

  test "checks nested talks" do
    videos = [{"video_provider" => "children", "talks" => [{"title" => "Lightning Talk: Foo", "video_provider" => "not_recorded"}]}]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkKind.new(file_path: path).errors

      assert errors.any? { |e| e.to_h["message"].include?("inferred as \"lightning_talk\"") }
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
