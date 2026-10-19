# frozen_string_literal: true

require "test_helper"

class Static::Validators::SpeakerExistsTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox
  include StaticDataSandbox

  VALID_VIDEOS_FILE = Dir.glob(Rails.root.join("data/**/videos.yml")).first.to_s

  setup do
    Static::Validators::SpeakerExists.reset!
  end

  test "applicable? returns true for a videos.yml file" do
    validator = Static::Validators::SpeakerExists.new(file_path: VALID_VIDEOS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns true for an involvements.yml file" do
    file = Dir.glob(Rails.root.join("data/**/involvements.yml")).first
    validator = Static::Validators::SpeakerExists.new(file_path: file)
    assert validator.applicable?
  end

  test "returns error when an involvement user is missing" do
    involvements = <<~YAML
      ---
      - name: "Organizer"
        users:
          - "Aaron Bedra"
          - "Org Ghost XYZZY"
    YAML

    with_temp_involvements(involvements) do |involvements_path|
      validator = Static::Validators::SpeakerExists.new(file_path: involvements_path)

      assert_equal 1, validator.errors.length
      assert_equal %(Speaker "Org Ghost XYZZY" not found in data/speakers.yml), validator.errors.first.message
      assert_equal 5, validator.errors.first.line
    end
  end

  test "applicable? returns false for a file without speaker references" do
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

      assert_equal 1, validator.errors.length
      assert_equal %(Speaker "Unknown Person XYZZY" not found in data/speakers.yml), validator.errors.first.message
    end
  end

  test "returns error when nested talk speaker is missing" do
    videos = [{"title" => "Panel", "talks" => [{"title" => "Sub", "speakers" => ["Ghost Speaker XYZZY"]}]}].to_yaml

    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)

      assert_equal 1, validator.errors.length
      assert_equal %(Speaker "Ghost Speaker XYZZY" not found in data/speakers.yml), validator.errors.first.message
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

  test "fix adds the missing speakers to speakers.yml" do
    videos = <<~YAML
      ---
      - title: "A talk"
        speakers:
          - "Ghost Speaker XYZZY"
          - "Aaron Bedra"

      - title: "Panel"
        talks:
          - title: "Sub"
            speakers:
              - "Ghost Speaker XYZZY"
              - "Nested Ghost XYZZY"
    YAML

    with_temp_videos(videos) do |videos_path|
      validator = Static::Validators::SpeakerExists.new(file_path: videos_path)

      assert_equal 3, validator.errors.length
      assert_equal 2, validator.fix[:changed]

      assert_equal({"name" => "Nested Ghost XYZZY", "github" => "", "slug" => "nested-ghost-xyzzy"}, Static::Speaker.find_by(name: "Nested Ghost XYZZY").to_h)
      assert Static::Speaker.find_by(name: "Ghost Speaker XYZZY")
      assert_empty Static::Validators::SpeakerExists.new(file_path: videos_path).errors
      assert_nil Static::Validators::SpeakerExists.new(file_path: videos_path).fix
    end
  end

  test "returns empty errors for a real videos.yml" do
    validator = Static::Validators::SpeakerExists.new(file_path: VALID_VIDEOS_FILE)

    assert_empty validator.errors
  end

  private

  def with_temp_videos(videos_yaml, &block)
    with_temp_event_file("videos.yml", videos_yaml, &block)
  end

  def with_temp_involvements(involvements_yaml, &block)
    with_temp_event_file("involvements.yml", involvements_yaml, &block)
  end

  def with_temp_event_file(name, content)
    with_static_data_dir do |dir|
      path = File.join(dir, "data", "testconf", "testconf-2024", name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)

      yield path
    end
  end
end
