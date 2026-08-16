# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueTalkIdsTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_videos("testconf-2024" => [{"id" => "x", "title" => "Something"}]) do |paths|
      assert Static::Validators::UniqueTalkIds.new(file_path: paths.first).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::UniqueTalkIds.new(file_path: file).applicable?
  end

  test "does not flag unique ids and old_ids" do
    files = {
      "testconf-2024" => [
        {"id" => "jane-doe-testconf-2024", "old_id" => "jane-doe-legacy", "title" => "A"},
        {"id" => "john-smith-testconf-2024", "title" => "B"}
      ]
    }

    with_temp_videos(files) do |paths|
      assert_empty errors_for(paths)
    end
  end

  test "flags the same id used in two files" do
    files = {
      "testconf-2024" => [{"id" => "jane-doe-testconf", "title" => "A"}],
      "testconf-2025" => [{"id" => "jane-doe-testconf", "title" => "B"}]
    }

    with_temp_videos(files) do |paths|
      errors = errors_for(paths)

      assert_equal 2, errors.size
      assert_includes errors.first.message, %(id "jane-doe-testconf" is not unique)
      assert_includes errors.first.message, "testconf-2025/videos.yml"
    end
  end

  test "flags an old_id that collides with an id" do
    files = {
      "testconf-2024" => [{"id" => "jane-doe-testconf-2024", "old_id" => "jane-doe", "title" => "A"}],
      "testconf-2025" => [{"id" => "jane-doe", "title" => "B"}]
    }

    with_temp_videos(files) do |paths|
      errors = errors_for(paths)

      assert_equal 2, errors.size
      assert errors.any? { |e| e.message.include?(%(old_id "jane-doe" is not unique)) }
      assert errors.any? { |e| e.message.include?(%(id "jane-doe" is not unique)) }
    end
  end

  test "flags duplicate ids between a talk and a nested talk" do
    files = {
      "testconf-2024" => [
        {"id" => "duplicated-id", "title" => "A"},
        {
          "id" => "lightning-talk-testconf-2024",
          "title" => "Lightning Talks",
          "talks" => [{"id" => "duplicated-id", "title" => "B"}]
        }
      ]
    }

    with_temp_videos(files) do |paths|
      assert_equal 2, errors_for(paths).size
    end
  end

  private

  def errors_for(paths)
    files = paths.map { |path| Static::VideosFile.new(path) }

    Static::Validators::UniqueTalkIds.duplicate_errors(files: files)
  end

  def with_temp_videos(files)
    dir = Dir.mktmpdir

    paths = files.map do |event_slug, videos|
      videos_path = File.join(dir, "data", "testconf", event_slug, "videos.yml")
      FileUtils.mkdir_p(File.dirname(videos_path))
      File.write(videos_path, videos.to_yaml)
      videos_path
    end

    yield paths
  ensure
    FileUtils.rm_rf(dir)
  end
end
