# frozen_string_literal: true

require "test_helper"

class Static::UniqueTalkSpeakersValidatorTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox
  include StaticDataSandbox

  setup do
    File.write(Static::Speaker.path, <<~YAML)
      ---
      - name: "Joseph Wilk"
        slug: "joseph-wilk"

      - name: "Tom Stuart"
        slug: "tom-stuart"

      - name: "Tom Stuart @mortice"
        slug: "tom-stuart-mortice"
        aliases:
          - name: "mortice"
            slug: "mortice"
    YAML

    Static::Speaker.unload!
  end

  test "valid when every speaker is listed once" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        speakers:
          - Tom Stuart
          - Tom Stuart @mortice
    YAML

    assert_empty speaker_errors(raw)
  end

  test "flags a speaker listed twice and points at the second listing" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        speakers:
          - Tom Stuart
          - Joseph Wilk
          - Tom Stuart
    YAML

    with_talks(raw) do |talks|
      talk = talks.first
      talk.valid?(:lint)
      error = talk.errors.where(:base).sole

      assert_equal %(speaker "Tom Stuart" is listed 2 times (as "Tom Stuart"). Remove the duplicate or point it at the right speaker in data/speakers.yml.), error.message
      assert_equal 6, talk.error_location(error).start_line
    end
  end

  test "flags a speaker listed by name and by alias" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        speakers:
          - Tom Stuart @mortice
          - mortice
    YAML

    errors = speaker_errors(raw)

    assert_equal 1, errors.size
    assert_includes errors.first, %((as "Tom Stuart @mortice", "mortice"))
  end

  test "flags a speaker listed twice in a nested talk" do
    raw = <<~YAML
      ---
      - id: "lightning-talks"
        speakers:
          - Tom Stuart
        talks:
          - id: "lightning-talk-1"
            speakers:
              - Joseph Wilk
              - Joseph Wilk
    YAML

    errors = speaker_errors(raw)

    assert_equal 1, errors.size
    assert_includes errors.first, %(speaker "Joseph Wilk")
  end

  private

  def speaker_errors(raw)
    with_talks(raw) do |talks|
      talks.to_a.flat_map do |talk|
        talk.valid?(:lint)
        talk.errors.where(:base).map(&:message).grep(/is listed/)
      end
    end
  end

  def with_talks(raw)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "2026", "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, raw)

      yield Static::Talk.in_file(path)
    end
  end
end
