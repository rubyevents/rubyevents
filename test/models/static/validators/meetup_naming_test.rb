# frozen_string_literal: true

require "test_helper"

class Static::Validators::MeetupNamingTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "MeetupSeriesName flags and strips a trailing Meetup" do
    with_meetup(series_name: "Lyon.rb Meetup") do |paths|
      validator = Static::Validators::MeetupSeriesName.new(file_path: paths[:series])

      assert_includes validator.errors.first.message, %(expected "Lyon.rb")

      validator.fix
      assert_equal "Lyon.rb", Static::EventSeries.in_file(paths[:series]).first["name"]
    end
  end

  test "MeetupSeriesName ignores a series without a trailing Meetup" do
    with_meetup(series_name: "Lyon.rb") do |paths|
      assert_empty Static::Validators::MeetupSeriesName.new(file_path: paths[:series]).errors
    end
  end

  test "MeetupSeriesName ignores conference series" do
    with_meetup(series_name: "Big Ruby Meetup", kind: "conference") do |paths|
      assert_empty Static::Validators::MeetupSeriesName.new(file_path: paths[:series]).errors
    end
  end

  test "MeetupEventTitle appends Meetup" do
    with_meetup(event_title: "Boulder Ruby") do |paths|
      validator = Static::Validators::MeetupEventTitle.new(file_path: paths[:event])

      assert_includes validator.errors.first.message, %(should be "Boulder Ruby Meetup")

      validator.fix
      assert_equal "Boulder Ruby Meetup", Static::Event.in_file(paths[:event]).first["title"]
    end
  end

  test "MeetupEventTitle collapses a repeated Meetup" do
    with_meetup(event_title: "SA Ruby Coders Meetup Meetup") do |paths|
      assert_includes Static::Validators::MeetupEventTitle.new(file_path: paths[:event]).errors.first.message, %(should be "SA Ruby Coders Meetup")
    end
  end

  test "MeetupEventTitle does not guess a title with Meetup in the middle" do
    with_meetup(event_title: "Ruby Meetup Oslo") do |paths|
      validator = Static::Validators::MeetupEventTitle.new(file_path: paths[:event])

      assert_includes validator.errors.first.message, "rename it by hand"
      assert_nil validator.fix
    end
  end

  test "MeetupEventTitle accepts a title ending in Meetup" do
    with_meetup(event_title: "Boulder Ruby Meetup") do |paths|
      assert_empty Static::Validators::MeetupEventTitle.new(file_path: paths[:event]).errors
    end
  end

  test "MeetupEventTitle accepts titles ending in Brigade, Group or Usergroup" do
    ["Cleveland Ruby Brigade", "Boston Ruby Group", "Bangalore Ruby Users Group", "Ruby Usergroup", "Boston Ruby Group Meetup"].each do |title|
      with_meetup(event_title: title) do |paths|
        assert_empty Static::Validators::MeetupEventTitle.new(file_path: paths[:event]).errors, title
      end
    end
  end

  test "MeetupEditionTitle leaves editions of a Brigade alone" do
    videos = [{"id" => "testrb-meetup-january-2026", "title" => "Cleveland Ruby Brigade January 2026", "date" => "2026-01-14"}]

    with_meetup(event_title: "Cleveland Ruby Brigade", videos: videos) do |paths|
      assert_empty Static::Validators::MeetupEditionTitle.new(file_path: paths[:videos]).errors
    end
  end

  test "MeetupEditionTitle adds Meetup to edition titles and event names" do
    videos = [
      {
        "id" => "testrb-meetup-january-2026", "title" => "Boulder Ruby January 2026", "event_name" => "Boulder Ruby January 2026",
        "date" => "2026-01-14", "video_provider" => "children", "video_id" => "testrb-meetup-january-2026",
        "talks" => [{"id" => "jane-doe-testrb-meetup-january-2026", "title" => "A Talk", "event_name" => "Boulder Ruby January 2026", "date" => "2026-01-14", "speakers" => ["Jane Doe"]}]
      },
      {"id" => "testrb-meetup-february-2026", "title" => "Docker and Rails", "date" => "2026-02-11"}
    ]

    with_meetup(event_title: "Boulder Ruby", videos: videos) do |paths|
      validator = Static::Validators::MeetupEditionTitle.new(file_path: paths[:videos])

      assert_equal 1, validator.errors.size
      assert_includes validator.errors.first.message, %(should be "Boulder Ruby Meetup January 2026")

      validator.fix

      edition, talk, other = Static::Talk.in_file(paths[:videos]).to_a
      assert_equal "Boulder Ruby Meetup January 2026", edition["title"]
      assert_equal "Boulder Ruby Meetup January 2026", edition["event_name"]
      assert_equal "Boulder Ruby Meetup January 2026", talk["event_name"]
      assert_equal "Docker and Rails", other["title"]
    end
  end

  test "MeetupEditionTitle accepts editions that already say Meetup" do
    videos = [{"id" => "testrb-meetup-january-2026", "title" => "Boulder Ruby Meetup January 2026", "date" => "2026-01-14"}]

    with_meetup(event_title: "Boulder Ruby Meetup", videos: videos) do |paths|
      assert_empty Static::Validators::MeetupEditionTitle.new(file_path: paths[:videos]).errors
    end
  end

  test "MeetupEventSlug renames an unpublished event to end in -meetup" do
    with_meetup(event_id: "testrb-ruby") do |paths|
      validator = Static::Validators::MeetupEventSlug.new(file_path: paths[:event])
      validator.define_singleton_method(:published?) { false }

      assert_includes validator.errors.first.message, %(should be "testrb-ruby-meetup")

      validator.fix
      assert File.exist?(File.join(File.dirname(paths[:event], 2), "testrb-ruby-meetup", "event.yml"))
    end
  end

  test "MeetupEventSlug does not rename an event that is already published" do
    with_meetup(event_id: "testrb-ruby") do |paths|
      validator = Static::Validators::MeetupEventSlug.new(file_path: paths[:event])
      validator.define_singleton_method(:published?) { true }

      assert_includes validator.errors.first.message, "already on main"
      assert_nil validator.fix
      assert File.exist?(paths[:event])
    end
  end

  test "MeetupEventSlug and MeetupEventTitle ignore RubyEvents" do
    with_meetup(event_id: "rubyevents", event_title: "RubyEvents") do |paths|
      assert_empty Static::Validators::MeetupEventSlug.new(file_path: paths[:event]).errors
      assert_empty Static::Validators::MeetupEventTitle.new(file_path: paths[:event]).errors
    end
  end

  test "MeetupEventSlug accepts ids ending in -meetup, -brigade, -group, -usergroup or a RUG abbreviation" do
    %w[testrb-meetup testrb-brigade testrb-group testrb-usergroup rughh lrug].each do |event_id|
      with_meetup(event_id: event_id) do |paths|
        assert_empty Static::Validators::MeetupEventSlug.new(file_path: paths[:event]).errors, event_id
      end
    end
  end

  private

  def with_meetup(series_name: "Test.rb", event_title: "Test.rb Meetup", event_id: "testrb-meetup", kind: "meetup", videos: [{"id" => "x", "title" => "x", "date" => "2026-01-14"}])
    with_static_data_dir do |dir|
      series_dir = File.join(dir, "data", "testrb")
      event_dir = File.join(series_dir, event_id)
      FileUtils.mkdir_p(event_dir)

      paths = {
        series: File.join(series_dir, "series.yml"),
        event: File.join(event_dir, "event.yml"),
        videos: File.join(event_dir, "videos.yml")
      }

      File.write(paths[:series], Yerba::Document.from({"id" => "testrb", "name" => series_name, "kind" => kind}).to_s)
      File.write(paths[:event], Yerba::Document.from({"id" => event_id, "title" => event_title, "kind" => kind}).to_s)
      File.write(paths[:videos], Yerba::Document.from(videos).to_s)

      yield paths
    end
  end
end
