# frozen_string_literal: true

require "test_helper"

class Static::ShortTalkKindValidatorTest < ActiveSupport::TestCase
  test "flags a short entry (under 10 minutes) without an explicit kind" do
    talk = segment("start_cue" => "00:00", "end_cue" => "05:00")

    assert_not talk.valid?
    assert_match(/\Ais only 05:00 long \(under 10 minutes\) but has no explicit kind\./, talk.errors.full_messages.first)
  end

  test "does not flag a short entry that has an explicit kind" do
    assert segment("kind" => "intro", "start_cue" => "00:00", "end_cue" => "05:00").valid?
  end

  test "does not flag an entry that is 10 minutes or longer" do
    assert segment("start_cue" => "00:00", "end_cue" => "10:00").valid?
  end

  test "does not flag when the duration cannot be figured out" do
    assert segment("start_cue" => "TODO", "end_cue" => "TODO").valid?
  end

  test "does not flag when only one cue is present" do
    assert segment("start_cue" => "00:00").valid?
  end

  test "supports HH:MM:SS cues" do
    talk = segment("start_cue" => "01:00:00", "end_cue" => "01:05:00")

    assert_not talk.valid?
    assert_match(/under 10 minutes/, talk.errors.full_messages.first)
  end

  test "points at the start_cue" do
    videos = <<~YAML
      - id: "segment"
        title: "Some Segment"
        speakers:
          - "Jane Doe"
        video_provider: "not_recorded"
        start_cue: "00:00"
        end_cue: "05:00"
    YAML

    with_temp_videos(videos) do |talks|
      talk = talks.find_by(id: "segment")

      assert_not talk.valid?
      assert_equal 6, talk.error_location(talk.errors.first).start_line
    end
  end

  test "checks nested talks" do
    videos = [{"id" => "container", "title" => "Container", "video_provider" => "children", "talks" => [{"id" => "segment", "title" => "Segment", "speakers" => ["Jane Doe"], "start_cue" => "00:00", "end_cue" => "02:00", "video_provider" => "not_recorded"}]}]

    with_temp_videos(videos) do |talks|
      nested = talks.find_by(id: "segment")

      assert_not nested.valid?
      assert_match(/under 10 minutes/, nested.errors.full_messages.first)
    end
  end

  private

  def segment(attributes)
    Static::Talk.new({"title" => "Some Segment", "speakers" => ["Jane Doe"], "video_provider" => "not_recorded"}.merge(attributes))
  end

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
