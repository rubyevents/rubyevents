# frozen_string_literal: true

require "test_helper"

class Static::Validators::MeetupIdTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "applicable? returns true for a meetup videos.yml file" do
    with_temp_meetup([edition("testrb-meetup-january-2026", "2026-01-14")]) do |path|
      assert Static::Validators::MeetupId.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for a conference videos.yml file" do
    with_temp_meetup([edition("whatever", "2026-01-14")], event: {"kind" => "conference"}) do |path|
      assert_not Static::Validators::MeetupId.new(file_path: path).applicable?
    end
  end

  test "does not flag one meetup per month named event-month-year" do
    videos = [
      edition("testrb-meetup-january-2026", "2026-01-14"),
      edition("testrb-meetup-february-2026", "2026-02-11")
    ]

    with_temp_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupId.new(file_path: path).errors
    end
  end

  test "flags an id that does not follow event-month-year" do
    with_temp_meetup([edition("testrb-january-2026", "2026-01-14")]) do |path|
      errors = Static::Validators::MeetupId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(expected id "testrb-meetup-january-2026")
    end
  end

  test "flags an id whose month does not match the date" do
    with_temp_meetup([edition("testrb-meetup-january-2026", "2026-02-11")]) do |path|
      errors = Static::Validators::MeetupId.new(file_path: path).errors

      assert_includes errors.first.message, %(expected id "testrb-meetup-february-2026")
    end
  end

  test "adds the day to every meetup in a month with more than one" do
    videos = [
      edition("testrb-meetup-january-2026", "2026-01-07"),
      edition("testrb-meetup-21-january-2026", "2026-01-21")
    ]

    with_temp_meetup(videos) do |path|
      errors = Static::Validators::MeetupId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(expected id "testrb-meetup-07-january-2026")
    end
  end

  test "numbers meetups on the same day in file order" do
    videos = [
      edition("testrb-meetup-07-january-2026", "2026-01-07"),
      edition("testrb-meetup-07-january-2026-2", "2026-01-07"),
      edition("testrb-meetup-07-january-2026-3", "2026-01-07")
    ]

    with_temp_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupId.new(file_path: path).errors
    end
  end

  test "ignores nested talks" do
    videos = [
      edition("testrb-meetup-january-2026", "2026-01-14").merge(
        "video_provider" => "children",
        "talks" => [{"id" => "jane-doe-testrb-meetup-january-2026", "title" => "A Talk", "date" => "2026-01-14", "speakers" => ["Jane Doe"]}]
      )
    ]

    with_temp_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupId.new(file_path: path).errors
    end
  end

  test "fix renames the id and video_id of an unrecorded meetup" do
    with_temp_meetup([edition("testrb-january-2026", "2026-01-14")]) do |path|
      result = Static::Validators::MeetupId.new(file_path: path).fix

      assert_equal 1, result[:changed]

      talk = Static::Talk.in_file(path).to_a.first
      assert_equal "testrb-meetup-january-2026", talk["id"]
      assert_equal "testrb-meetup-january-2026", talk["video_id"]
    end
  end

  test "fix keeps the video_id of a recorded meetup" do
    videos = [edition("testrb-january-2026", "2026-01-14").merge("video_provider" => "youtube", "video_id" => "abc123")]

    with_temp_meetup(videos) do |path|
      Static::Validators::MeetupId.new(file_path: path).fix

      talk = Static::Talk.in_file(path).to_a.first
      assert_equal "testrb-meetup-january-2026", talk["id"]
      assert_equal "abc123", talk["video_id"]
    end
  end

  test "fix does nothing when every id is correct" do
    with_temp_meetup([edition("testrb-meetup-january-2026", "2026-01-14")]) do |path|
      original_content = File.read(path)

      assert_nil Static::Validators::MeetupId.new(file_path: path).fix
      assert_equal original_content, File.read(path)
    end
  end

  private

  def edition(id, date)
    {"id" => id, "title" => "Test.rb Meetup", "date" => date, "video_provider" => "not_recorded", "video_id" => id}
  end

  def with_temp_meetup(videos, event: {"kind" => "meetup"})
    with_static_data_dir do |dir|
      videos_path = File.join(dir, "data", "testrb", "testrb-meetup", "videos.yml")
      FileUtils.mkdir_p(File.dirname(videos_path))
      File.write(videos_path, Yerba::Document.from(videos).to_s)
      File.write(File.join(File.dirname(videos_path), "event.yml"), Yerba::Document.from(event).to_s)
      yield videos_path
    end
  end
end
