# frozen_string_literal: true

require "test_helper"

class Static::Validators::RecordingCuesTest < ActiveSupport::TestCase
  test "does not flag talks that share a recording with cues in order" do
    with_temp_videos([talk("a", "00:00", "10:00"), talk("b", "10:00", "20:00"), talk("c", "TODO", "TODO")]) do |path|
      assert_empty errors_for(path)
    end
  end

  test "does not flag talks with their own videos" do
    with_temp_videos([talk("a", nil, nil, video_id: "one"), talk("b", nil, nil, video_id: "two")]) do |path|
      assert_empty errors_for(path)
    end
  end

  test "flags talks that share a recording without cues" do
    with_temp_videos([talk("a", "00:00", "10:00"), talk("b", nil, nil), talk("c", "20:00", nil)]) do |path|
      messages = errors_for(path).map(&:message)

      assert_equal 2, messages.size
      assert_includes messages.first, %(start_cue and end_cue are missing. This talk shares its youtube video "abc123" with 2 other talks)
      assert_includes messages.last, "end_cue is missing"
    end
  end

  test "flags a talk that ends before it starts" do
    with_temp_videos([talk("a", "20:55", "20:52"), talk("b", "21:00", "30:00")]) do |path|
      assert_equal [%(end_cue "20:52" isn't after start_cue "20:55".)], errors_for(path).map(&:message)
    end
  end

  test "flags overlapping cues" do
    with_temp_videos([talk("a", "1:00:38", "1:03:00"), talk("b", "1:01:37", "1:03:00")]) do |path|
      assert_equal [%(start_cue "1:01:37" overlaps "a", which ends at "1:03:00".)], errors_for(path).map(&:message)
    end
  end

  test "flags cues that are out of order" do
    with_temp_videos([talk("a", "01:38:00", "02:24:00"), talk("b", "16:00", "22:00")]) do |path|
      assert_equal [%(start_cue "16:00" is before "a", which starts at "01:38:00". List the talks in the order of the recording.)], errors_for(path).map(&:message)
    end
  end

  test "flags cues that overlap a talk of the same recording in another file" do
    with_temp_events("testconf-2024" => [talk("a", "00:00", "30:00")], "testconf-2025" => [talk("b", "20:00", "40:00")]) do |first, second|
      errors = errors_for(first, second)

      assert_equal [first, second], errors.map(&:file_path)
      assert_includes errors.first.message, %(cues "00:00" to "30:00" overlap "b" in #{second}, which uses the same youtube video "abc123" from "20:00" to "40:00".)
      assert_includes errors.last.message, %(cues "20:00" to "40:00" overlap "a" in #{first})
    end
  end

  test "does not flag talks of the same recording in different files with cues that don't overlap" do
    with_temp_events("testconf-2024" => [talk("a", "20:00", "40:00")], "testconf-2025" => [talk("b", "00:00", "20:00"), talk("c", "TODO", "TODO")]) do |first, second|
      assert_empty errors_for(first, second)
    end
  end

  test "checks the order of talks nested under a parent recording, without requiring their cues" do
    nested = [
      talk("a", "00:20", "05:00", video_provider: "parent", video_id: "a"),
      talk("b", "04:59", "08:23", video_provider: "parent", video_id: "b"),
      talk("c", nil, nil, video_provider: "parent", video_id: "c")
    ]

    with_temp_videos([talk("recording", nil, nil, video_id: "full").merge("talks" => nested)]) do |path|
      assert_equal [%(start_cue "04:59" overlaps "a", which ends at "05:00".)], errors_for(path).map(&:message)
    end
  end

  test "imports a TODO cue as an unknown cue" do
    with_temp_videos([talk("a", "TODO", "TODO")]) do |path|
      static_talk = Static::Talk.in_file(path).first

      assert_nil static_talk.start_cue_in_seconds
      assert_nil static_talk.end_cue_in_seconds
    end
  end

  private

  def talk(id, start_cue, end_cue, video_provider: "youtube", video_id: "abc123")
    {"id" => id, "title" => id.titleize, "start_cue" => start_cue, "end_cue" => end_cue, "video_provider" => video_provider, "video_id" => video_id}.compact
  end

  def errors_for(*paths)
    Static::Validators::RecordingCues.errors_in(paths.flat_map { |path| Static::Talk.in_file(path).to_a })
  end

  def with_temp_videos(videos, &block)
    with_temp_events("testconf-2024" => videos, &block)
  end

  def with_temp_events(events)
    dir = Dir.mktmpdir

    paths = events.map do |event, videos|
      path = File.join(dir, "data", "testconf", event, "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, Yerba::Document.from(videos).to_s)
      path
    end

    yield(*paths)
  ensure
    FileUtils.rm_rf(dir)
  end
end
