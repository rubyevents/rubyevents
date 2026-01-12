require "test_helper"

class TemplateTest < ActiveSupport::TestCase
  test "serializes basic template to YAML" do
    template = Template.new(
      title: "Test Talk",
      event_name: "Test Event",
      date: Date.new(2025, 1, 15),
      speakers: "John Doe, Jane Smith"
    )

    parsed = YAML.safe_load(template.to_yaml).first

    assert_equal "Test Talk", parsed["title"]
    assert_equal "Test Event", parsed["event_name"]
    assert_equal "2025-01-15", parsed["date"]
    assert_equal ["John Doe", "Jane Smith"], parsed["speakers"]
  end

  test "serializes template with video information" do
    template = Template.new(
      title: "Video Talk",
      event_name: "Video Event",
      date: Date.current,
      video_provider: "youtube",
      video_id: "abc123",
      start_cue: Time.parse("00:02:30"),
      end_cue: Time.parse("00:45:00")
    )

    parsed = YAML.safe_load(template.to_yaml).first

    assert_equal "youtube", parsed["video_provider"]
    assert_equal "abc123", parsed["video_id"]
    assert_equal "00:02:30", parsed["start_cue"]
    assert_equal "00:45:00", parsed["end_cue"]
  end

  test "serializes template with children" do
    template = Template.new(
      title: "Parent Talk",
      event_name: "Multi-talk Event",
      date: Date.current
    )

    child = Template.new(
      title: "Child Talk",
      speakers: "Child Speaker"
    )

    template.children << child

    parsed = YAML.safe_load(template.to_yaml).first

    assert_equal "children", parsed["video_provider"]
    assert_equal 1, parsed["talks"].length
    assert_equal "Child Talk", parsed["talks"].first["title"]
    assert_equal ["Child Speaker"], parsed["talks"].first["speakers"]
  end

  test "validates required fields" do
    template = Template.new

    refute template.valid?
    assert_not_nil template.errors[:title]
    assert_not_nil template.errors[:event_name]
    assert_not_nil template.errors[:date]
  end
end
