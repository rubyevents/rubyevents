# frozen_string_literal: true

require "test_helper"

class Static::Validators::MeetupTalksNestedTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "flags a talk listed at the top level of a meetup" do
    videos = [
      {"id" => "jane-doe-testrb-meetup-january-2026", "title" => "Building Things", "date" => "2026-01-14", "video_provider" => "youtube", "video_id" => "abc", "speakers" => ["Jane Doe"]}
    ]

    with_meetup(videos) do |path|
      errors = Static::Validators::MeetupTalksNested.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(talk "Building Things" is listed as a meetup edition)
      assert_includes errors.first.message, %("Test.rb Meetup January 2026")
    end
  end

  test "does not flag talks nested under an edition" do
    videos = [
      {
        "id" => "testrb-meetup-january-2026", "title" => "Test.rb Meetup January 2026", "date" => "2026-01-14", "video_provider" => "children",
        "talks" => [{"id" => "jane-doe-testrb-meetup-january-2026", "title" => "Building Things", "date" => "2026-01-14", "speakers" => ["Jane Doe"]}]
      }
    ]

    with_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupTalksNested.new(file_path: path).errors
    end
  end

  test "does not flag an edition that lists its speakers" do
    videos = [{"id" => "testrb-meetup-january-2026", "title" => "Test.rb Meetup January 2026", "date" => "2026-01-14", "video_provider" => "children", "speakers" => ["Jane Doe"], "talks" => []}]

    with_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupTalksNested.new(file_path: path).errors
    end
  end

  test "does not flag an edition with TODO speakers" do
    videos = [{"id" => "testrb-meetup-january-2026", "title" => "59th meetup", "date" => "2026-01-14", "video_provider" => "not_recorded", "speakers" => ["TODO"]}]

    with_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupTalksNested.new(file_path: path).errors
    end
  end

  test "does not apply to conferences" do
    videos = [{"id" => "jane-doe-testconf-2026", "title" => "Building Things", "date" => "2026-01-14", "speakers" => ["Jane Doe"]}]

    with_meetup(videos, kind: "conference") do |path|
      assert_not Static::Validators::MeetupTalksNested.new(file_path: path).applicable?
    end
  end

  private

  def with_meetup(videos, kind: "meetup")
    with_static_data_dir do |dir|
      videos_path = File.join(dir, "data", "testrb", "testrb-meetup", "videos.yml")
      FileUtils.mkdir_p(File.dirname(videos_path))
      File.write(videos_path, Yerba::Document.from(videos).to_s)
      File.write(File.join(File.dirname(videos_path), "event.yml"), Yerba::Document.from({"id" => "testrb-meetup", "title" => "Test.rb Meetup", "kind" => kind}).to_s)
      yield videos_path
    end
  end
end
