# frozen_string_literal: true

require "test_helper"

class Static::RecordingCuesValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "is a lint validation of talks" do
    assert Static::Talk.validators.any? { |validator| validator.is_a?(Static::RecordingCuesValidator) && validator.options[:on] == :lint }
  end

  test "does not flag talks that share a recording with cues in order" do
    with_events("testconf-2024" => [talk("a", "00:00", "10:00"), talk("b", "10:00", "20:00"), talk("c", "TODO", "TODO")]) do
      assert_empty cue_errors
    end
  end

  test "does not flag talks with their own videos" do
    with_events("testconf-2024" => [talk("a", nil, nil, video_id: "one"), talk("b", nil, nil, video_id: "two")]) do
      assert_empty cue_errors
    end
  end

  test "flags talks that share a recording without cues and points at their id" do
    with_events("testconf-2024" => [talk("a", "00:00", "10:00"), talk("b", nil, nil), talk("c", "20:00", nil)]) do
      errors = cue_errors

      assert_equal %w[b c], errors.map { |error| error.base["id"] }
      assert_includes errors.first.full_message, %(start_cue and end_cue are missing. This talk shares its youtube video "abc123" with 2 other talks)
      assert_includes errors.last.full_message, "end_cue is missing"
      assert_equal errors.first.base.source_line("id"), errors.first.base.error_location(errors.first).start_line
    end
  end

  test "flags a talk that ends before it starts" do
    with_events("testconf-2024" => [talk("a", "20:55", "20:52"), talk("b", "21:00", "30:00")]) do
      errors = cue_errors

      assert_equal [%(end_cue "20:52" isn't after start_cue "20:55".)], errors.map(&:full_message)
      assert_equal errors.first.base.source_line("end_cue"), errors.first.base.error_location(errors.first).start_line
    end
  end

  test "flags overlapping cues" do
    with_events("testconf-2024" => [talk("a", "1:00:38", "1:03:00"), talk("b", "1:01:37", "1:03:00")]) do
      assert_equal [%(start_cue "1:01:37" overlaps "a", which ends at "1:03:00".)], cue_errors.map(&:full_message)
    end
  end

  test "flags cues that are out of order" do
    with_events("testconf-2024" => [talk("a", "01:38:00", "02:24:00"), talk("b", "16:00", "22:00")]) do
      assert_equal [%(start_cue "16:00" is before "a", which starts at "01:38:00". List the talks in the order of the recording.)], cue_errors.map(&:full_message)
    end
  end

  test "flags cues that overlap a talk of the same recording in another file" do
    with_events("testconf-2024" => [talk("a", "00:00", "30:00")], "testconf-2025" => [talk("b", "20:00", "40:00")]) do
      errors = cue_errors

      assert_equal %w[data/testconf/testconf-2024/videos.yml data/testconf/testconf-2025/videos.yml], errors.map { |error| error.base.project_file_path }
      assert_includes errors.first.full_message, %(cues "00:00" to "30:00" overlap "b" in data/testconf/testconf-2025/videos.yml, which uses the same youtube video "abc123" from "20:00" to "40:00".)
      assert_includes errors.last.full_message, %(cues "20:00" to "40:00" overlap "a" in data/testconf/testconf-2024/videos.yml)
      assert_equal errors.first.base.source_line("start_cue"), errors.first.base.error_location(errors.first).start_line
    end
  end

  test "does not flag talks of the same recording in different files with cues that don't overlap" do
    with_events("testconf-2024" => [talk("a", "20:00", "40:00")], "testconf-2025" => [talk("b", "00:00", "20:00"), talk("c", "TODO", "TODO")]) do
      assert_empty cue_errors
    end
  end

  test "checks the order of talks nested under a parent recording, without requiring their cues" do
    nested = [
      talk("a", "00:20", "05:00", video_provider: "parent", video_id: "a"),
      talk("b", "04:59", "08:23", video_provider: "parent", video_id: "b"),
      talk("c", nil, nil, video_provider: "parent", video_id: "c")
    ]

    with_events("testconf-2024" => [talk("recording", nil, nil, video_id: "full").merge("talks" => nested)]) do
      assert_equal [%(start_cue "04:59" overlaps "a", which ends at "05:00".)], cue_errors.map(&:full_message)
    end
  end

  test "imports a TODO cue as an unknown cue" do
    with_events("testconf-2024" => [talk("a", "TODO", "TODO")]) do
      static_talk = Static::Talk.all.first

      assert_nil static_talk.start_cue_in_seconds
      assert_nil static_talk.end_cue_in_seconds
    end
  end

  private

  def talk(id, start_cue, end_cue, video_provider: "youtube", video_id: "abc123")
    {"id" => id, "title" => id.titleize, "start_cue" => start_cue, "end_cue" => end_cue, "video_provider" => video_provider, "video_id" => video_id}.compact
  end

  def cue_errors
    Yerba::Record::Validations.caching do
      validator = Static::RecordingCuesValidator.new

      Static::Talk.all.to_a.flat_map do |talk|
        validator.validate(talk)
        talk.errors.objects
      end
    end
  end

  def with_events(events)
    with_static_data_dir do |root|
      events.each do |event, videos|
        path = File.join(root, "data", "testconf", event, "videos.yml")
        FileUtils.mkdir_p(File.dirname(path))
        Yerba::Document.from(videos).save_to!(path)
      end

      yield
    end
  end
end
