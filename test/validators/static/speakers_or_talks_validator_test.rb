# frozen_string_literal: true

require "test_helper"

class Static::SpeakersOrTalksValidatorTest < ActiveSupport::TestCase
  BOTH = "an entry must have either `talks` or `speakers`, but not both."
  NEITHER = "an entry must have either `talks` (a container) or `speakers` (a single talk), but has neither."

  test "valid when only speakers are present" do
    assert Static::Talk.new("title" => "A talk", "speakers" => ["Jane Doe"]).valid?
  end

  test "valid when only talks are present, even when empty" do
    assert Static::Talk.new("title" => "A meetup", "talks" => []).valid?
  end

  test "flags an entry with both talks and speakers" do
    videos = <<~YAML
      - id: "both"
        title: "Both"
        speakers:
          - "Jane"
        talks:
          - id: "nested"
            title: "Nested"
            speakers:
              - "Joe"
    YAML

    with_temp_videos(videos) do |talks|
      talk = talks.find_by(id: "both")

      assert_not talk.valid?
      assert_equal [BOTH], talk.errors.full_messages
      assert_equal 6, talk.error_location(talk.errors.first).start_line
    end
  end

  test "flags an entry with neither talks nor speakers" do
    talk = Static::Talk.new("title" => "Empty", "video_provider" => "not_recorded")

    assert_not talk.valid?
    assert_equal [NEITHER], talk.errors.full_messages
  end

  test "checks nested talks" do
    with_temp_videos([{"id" => "container", "title" => "Container", "talks" => [{"id" => "nested", "title" => "Nested has both", "speakers" => ["Joe"], "talks" => []}]}]) do |talks|
      assert talks.find_by(id: "container").valid?

      nested = talks.find_by(id: "nested")
      assert_not nested.valid?
      assert_equal [BOTH], nested.errors.full_messages
    end
  end

  private

  def with_temp_videos(videos)
    root = Dir.mktmpdir
    path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(path))
    videos.is_a?(String) ? File.write(path, videos) : Yerba::Document.from(videos).save_to!(path)

    yield Static::Talk.in_file(path)
  ensure
    FileUtils.rm_rf(root)
  end
end
