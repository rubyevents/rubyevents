# frozen_string_literal: true

require "test_helper"

class Static::Talk::TrackTest < ActiveSupport::TestCase
  include StaticDataSandbox

  SCHEDULE = <<~YAML
    ---
    days: []
    tracks:
      - name: "Main Stage"
        color: "#000000"
      - name: "Workshop"
        color: "#FFFFFF"
  YAML

  test "valid when every track is defined in schedule.yml" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
      - id: "talk-2"
        track: "Workshop"
      - id: "talk-3"
    YAML

    with_talks(raw, schedule: SCHEDULE) do |talks|
      assert_equal({"talk-1" => [], "talk-2" => [], "talk-3" => []}, track_errors(talks))
    end
  end

  test "flags a track that is not defined in schedule.yml" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
      - id: "talk-2"
        track: "Main stage"
    YAML

    with_talks(raw, schedule: SCHEDULE) do |talks|
      assert_equal({"talk-1" => [], "talk-2" => [%(track "Main stage" is not defined in the tracks of schedule.yml (defined: "Main Stage", "Workshop"). Fix the track name or add it to the tracks in schedule.yml.)]}, track_errors(talks))

      talk = talks.find_by(id: "talk-2")
      assert_equal 5, talk.error_location(talk.errors.where(:track).first).start_line
    end
  end

  test "flags a track used by a nested talk" do
    raw = <<~YAML
      ---
      - id: "lightning-talks"
        track: "Main Stage"
        talks:
          - id: "lightning-talk-1"
            track: "Lightning"
    YAML

    with_talks(raw, schedule: SCHEDULE) do |talks|
      errors = track_errors(talks)

      assert_empty errors["lightning-talks"]
      assert_match(/\Atrack "Lightning" is not defined/, errors["lightning-talk-1"].sole)
    end
  end

  test "flags tracks when schedule.yml defines no tracks" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
    YAML

    with_talks(raw, schedule: "---\ndays: []\n") do |talks|
      assert_includes track_errors(talks)["talk-1"].sole, "(defined: none)"
    end
  end

  test "skips events without a schedule.yml" do
    raw = <<~YAML
      ---
      - id: "talk-1"
        track: "Main Stage"
    YAML

    with_talks(raw) do |talks|
      assert_equal({"talk-1" => []}, track_errors(talks))
    end
  end

  private

  def track_errors(talks)
    talks.to_h do |talk|
      talk.valid?(:lint)

      [talk.id, talk.errors.full_messages_for(:track)]
    end
  end

  def with_talks(raw, schedule: nil)
    with_static_data_dir do |root|
      directory = File.join(root, "data", "testconf", "testconf-2026")
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, "videos.yml"), raw)
      File.write(File.join(directory, "event.yml"), %(---\nid: "testconf-2026"\ntitle: "TestConf 2026"\nkind: "conference"\n))
      File.write(File.join(directory, "schedule.yml"), schedule) if schedule

      yield Static::Talk.in_file(File.join(directory, "videos.yml"))
    end
  end
end
