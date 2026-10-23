# frozen_string_literal: true

require "test_helper"

class Static::Validators::MeetupEditionProviderTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "flags not_recorded and scheduled meetup editions" do
    videos = [edition("testrb-meetup-january-2026", "not_recorded"), edition("testrb-meetup-february-2026", "scheduled")]

    with_meetup(videos) do |path|
      errors = Static::Validators::MeetupEditionProvider.new(file_path: path).errors

      assert_equal 2, errors.size
      assert_includes errors.first.message, %(video_provider "not_recorded" of meetup edition "testrb-meetup-january-2026" should be "children")
    end
  end

  test "does not flag children editions or editions with their own recording" do
    videos = [edition("testrb-meetup-january-2026", "children"), edition("testrb-meetup-february-2026", "youtube")]

    with_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupEditionProvider.new(file_path: path).errors
    end
  end

  test "does not flag nested talks" do
    videos = [
      edition("testrb-meetup-january-2026", "children").merge(
        "talks" => [{"id" => "jane-doe-testrb-meetup-january-2026", "title" => "A Talk", "date" => "2026-01-14", "video_provider" => "not_recorded", "speakers" => ["Jane Doe"]}]
      )
    ]

    with_meetup(videos) do |path|
      assert_empty Static::Validators::MeetupEditionProvider.new(file_path: path).errors
    end
  end

  test "does not apply to conferences" do
    with_meetup([edition("testconf-2026", "not_recorded")], kind: "conference") do |path|
      assert_not Static::Validators::MeetupEditionProvider.new(file_path: path).applicable?
    end
  end

  test "fix sets the editions to children" do
    videos = [edition("testrb-meetup-january-2026", "not_recorded"), edition("testrb-meetup-february-2026", "youtube")]

    with_meetup(videos) do |path|
      result = Static::Validators::MeetupEditionProvider.new(file_path: path).fix

      assert_equal 1, result[:changed]
      assert_equal %w[children youtube], Static::Talk.in_file(path).to_a.map { it["video_provider"] }
    end
  end

  private

  def edition(id, provider)
    {"id" => id, "title" => "Test.rb Meetup", "date" => "2026-01-14", "video_provider" => provider, "video_id" => id}
  end

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
