# frozen_string_literal: true

require "test_helper"

class Static::SpeakerExistsValidatorTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox
  include StaticDataSandbox

  test "valid when all speakers exist" do
    with_event_file("videos.yml", %(---\n- id: "talk"\n  title: "A talk"\n  speakers:\n    - "Aaron Bedra"\n)) do |path|
      assert_empty speaker_errors(Static::Talk.in_file(path).find_by(id: "talk"))
    end
  end

  test "flags a missing top-level speaker" do
    with_event_file("videos.yml", %(---\n- id: "talk"\n  title: "A talk"\n  speakers:\n    - "Unknown Person XYZZY"\n)) do |path|
      assert_equal [%(Speaker "Unknown Person XYZZY" not found in data/speakers.yml)], speaker_errors(Static::Talk.in_file(path).find_by(id: "talk"))
    end
  end

  test "flags a missing nested talk speaker" do
    videos = <<~YAML
      ---
      - id: "panel"
        title: "Panel"
        talks:
          - id: "sub"
            title: "Sub"
            speakers:
              - "Ghost Speaker XYZZY"
    YAML

    with_event_file("videos.yml", videos) do |path|
      talks = Static::Talk.in_file(path)

      assert_empty speaker_errors(talks.find_by(id: "panel"))
      assert_equal [%(Speaker "Ghost Speaker XYZZY" not found in data/speakers.yml)], speaker_errors(talks.find_by(id: "sub"))
    end
  end

  test "flags a missing alternative recording speaker" do
    videos = <<~YAML
      ---
      - id: "talk"
        title: "A talk"
        speakers:
          - "Aaron Bedra"
        alternative_recordings:
          - title: "A talk (again)"
            speakers:
              - "Alt Ghost XYZZY"
    YAML

    with_event_file("videos.yml", videos) do |path|
      recording = Static::Talk.in_file(path).find_by(id: "talk").alternative_recordings.first

      assert_equal [%(Speaker "Alt Ghost XYZZY" not found in data/speakers.yml)], speaker_errors(recording)
    end
  end

  test "flags a missing involvement user and points at it" do
    involvements = <<~YAML
      ---
      - name: "Organizer"
        users:
          - "Aaron Bedra"
          - "Org Ghost XYZZY"
    YAML

    with_event_file("involvements.yml", involvements) do |path|
      involvement = Static::Involvement.in_file(path).first

      assert_equal [%(Speaker "Org Ghost XYZZY" not found in data/speakers.yml)], speaker_errors(involvement)
      assert_equal 5, involvement.error_location(involvement.errors.first).start_line
    end
  end

  test "recognises speaker aliases as valid" do
    with_event_file("videos.yml", %(---\n- id: "talk"\n  title: "A talk"\n  speakers:\n    - 'Abdelkader "Seuros" Boudih'\n)) do |path|
      assert_empty speaker_errors(Static::Talk.in_file(path).find_by(id: "talk"))
    end
  end

  test "fix adds the missing speakers to speakers.yml" do
    videos = <<~YAML
      ---
      - id: "talk"
        title: "A talk"
        speakers:
          - "Ghost Speaker XYZZY"
          - "Aaron Bedra"

      - id: "panel"
        title: "Panel"
        talks:
          - id: "sub"
            title: "Sub"
            speakers:
              - "Ghost Speaker XYZZY"
              - "Nested Ghost XYZZY"
    YAML

    with_event_file("videos.yml", videos) do |path|
      talks = Static::Talk.in_file(path)
      assert_equal 3, talks.sum { |talk| speaker_errors(talk).size }

      assert_equal 2, fix(path).sum { |_record, _validator, changes| changes }

      assert_equal({"name" => "Nested Ghost XYZZY", "github" => "", "slug" => "nested-ghost-xyzzy"}, Static::Speaker.find_by(name: "Nested Ghost XYZZY").to_h)
      assert Static::Speaker.find_by(name: "Ghost Speaker XYZZY")
      assert Static::Talk.in_file(path).all? { |talk| speaker_errors(talk).empty? }
      assert_empty fix(path)
    end
  end

  test "a real videos.yml has no missing speakers" do
    talks = Static::Talk.in_file(Dir.glob(Rails.root.join("data/**/videos.yml")).first)

    assert talks.all? { |talk| speaker_errors(talk).empty? }
  end

  private

  def speaker_errors(record)
    record.valid?(:lint)

    record.errors.full_messages.grep(/not found in data\/speakers.yml/)
  end

  def fix(path)
    Yerba::Record.fix_all(Static::Talk.in_file(path), only: Static::SpeakerExistsValidator)
  end

  def with_event_file(name, content)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)

      yield path
    end
  end
end
