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

  test "MeetupSeriesName accepts a trailing Meetup under a parent of the same name" do
    with_static_data_dir do |dir|
      parent = File.join(dir, "data", "testrb", "series.yml")
      child = File.join(dir, "data", "testrb", "testrb-meetup", "series.yml")
      FileUtils.mkdir_p(File.dirname(child))
      File.write(parent, Yerba::Document.from({"id" => "testrb", "name" => "Test.rb", "kind" => "organisation"}).to_s)
      File.write(child, Yerba::Document.from({"id" => "testrb-meetup", "name" => "Test.rb Meetup", "kind" => "meetup"}).to_s)

      assert_empty Static::Validators::MeetupSeriesName.new(file_path: child).errors
    end
  end

  test "MeetupSeriesName ignores conference series" do
    with_meetup(series_name: "Big Ruby Meetup", kind: "conference") do |paths|
      assert_empty Static::Validators::MeetupSeriesName.new(file_path: paths[:series]).errors
    end
  end

  test "MeetupSeriesFrequency flags and removes a frequency on a meetup series" do
    with_meetup(series_frequency: "monthly") do |paths|
      validator = Static::Validators::MeetupSeriesFrequency.new(file_path: paths[:series])

      assert_includes validator.errors.first.message, %(frequency "monthly" is set on a meetup series)

      validator.fix
      assert_nil Static::EventSeries.in_file(paths[:series]).first["frequency"]
    end
  end

  test "MeetupSeriesFrequency ignores conference series" do
    with_meetup(kind: "conference", series_frequency: "yearly") do |paths|
      assert_empty Static::Validators::MeetupSeriesFrequency.new(file_path: paths[:series]).errors
    end
  end

  test "MeetupTitle names a meetup after its group, Meetup and month, and keeps the old wording as its subtitle" do
    {
      "Test.rb January 2026" => nil,
      "Test.rb Meetup - January 2026" => nil,
      "Test.rb - Januar 2026" => nil,
      "Test.rb January 2026 - Pubnite" => "Pubnite",
      "Test.rb Meetup - January 2026 (Bern)" => "Bern",
      "Test.rb Hack Day - January 2026" => "Test.rb Hack Day",
      "Ruby Tuesday #12" => "Ruby Tuesday #12",
      "Test.rb" => nil,
      "Test.rb Meetup March 2026" => nil
    }.each do |title, subtitle|
      with_meetup(event_id: "testrb-2026-01-14", event_title: title, start_date: "2026-01-14") do |paths|
        validator = Static::Validators::MeetupTitle.new(file_path: paths[:event])

        assert_includes validator.errors.first&.message.to_s, %(should be "Test.rb Meetup January 2026"), title

        validator.fix
        event = Static::Event.in_file(paths[:event]).first
        assert_equal "Test.rb Meetup January 2026", event["title"], title
        assert_equal subtitle.to_s, event["subtitle"].to_s, title
      end
    end
  end

  test "MeetupTitle accepts a meetup named after its group, Meetup and month" do
    with_meetup(event_id: "testrb-2026-01-14", event_title: "Test.rb Meetup January 2026", start_date: "2026-01-14") do |paths|
      assert_empty Static::Validators::MeetupTitle.new(file_path: paths[:event]).errors
    end
  end

  test "MeetupTitle adds the day when the group meets more than once that month" do
    with_meetup(event_id: "testrb-2026-01-14", event_title: "Test.rb Meetup January 2026", start_date: "2026-01-14") do |paths|
      second = File.join(File.dirname(paths[:event], 2), "testrb-2026-01-28", "event.yml")
      FileUtils.mkdir_p(File.dirname(second))
      File.write(second, Yerba::Document.from({"id" => "testrb-2026-01-28", "title" => "Test.rb Meetup January 28, 2026", "kind" => "meetup", "start_date" => "2026-01-28", "end_date" => "2026-01-28"}).to_s)
      Static::Validators::MeetupTitle.reset_meetup_dates!

      assert_includes Static::Validators::MeetupTitle.new(file_path: paths[:event]).errors.first.message, %(should be "Test.rb Meetup January 14, 2026")
    end
  end

  test "MeetupTitle leaves Meetup out when the group's name already says it is a group" do
    with_meetup(series_name: "Test Ruby Brigade", event_id: "testrb-2026-01-14", event_title: "Test Ruby Brigade January 2026", start_date: "2026-01-14") do |paths|
      assert_empty Static::Validators::MeetupTitle.new(file_path: paths[:event]).errors
    end
  end

  test "MeetupTitle.title_name adds Meetup unless the name spells out a group" do
    {
      {"name" => "Paris.rb"} => "Paris.rb Meetup",
      {"name" => "London Ruby User Group", "meetup_name" => "LRUG"} => "LRUG Meetup",
      {"name" => "RUG::B"} => "RUG::B Meetup",
      {"name" => "Polish Ruby User Group (PLRUG)", "meetup_name" => "Ruby Warsaw"} => "Ruby Warsaw Meetup",
      {"name" => "Ruby on Rails Switzerland", "meetup_name" => "Railshöck"} => "Railshöck Meetup",
      {"name" => "Helsinki Ruby Brigade"} => "Helsinki Ruby Brigade",
      {"name" => "North West Ruby User Group"} => "North West Ruby User Group",
      {"name" => "Utah Ruby Users Group"} => "Utah Ruby Users Group",
      {"name" => "Ruby Usergroup Hamburg"} => "Ruby Usergroup Hamburg",
      {"name" => "Boston Ruby Group"} => "Boston Ruby Group",
      {"name" => "Dolnośląska Grupa Użytkowników Ruby"} => "Dolnośląska Grupa Użytkowników Ruby",
      {"name" => "Paris Ruby Workshop"} => "Paris Ruby Workshop"
    }.each do |series, title_name|
      assert_equal title_name, Static::Validators::MeetupTitle.title_name(series), series.inspect
    end
  end

  test "MeetupFolder accepts a meetup named after its series and date" do
    with_meetup(event_id: "testrb-2026-01-14", start_date: "2026-01-14") do |paths|
      assert_empty Static::Validators::MeetupFolder.new(file_path: paths[:event]).errors
    end
  end

  test "MeetupFolder accepts a counter for another meetup on the same day" do
    with_meetup(event_id: "testrb-2026-01-14-2", start_date: "2026-01-14") do |paths|
      assert_empty Static::Validators::MeetupFolder.new(file_path: paths[:event]).errors
    end
  end

  test "MeetupFolder flags a meetup that isn't named after its series and date" do
    with_meetup(event_id: "testrb-meetup-january-2026", start_date: "2026-01-14") do |paths|
      assert_includes Static::Validators::MeetupFolder.new(file_path: paths[:event]).errors.first.message, %(should be "testrb-2026-01-14")
    end
  end

  test "MeetupFolder flags a meetup without a date" do
    with_meetup(event_id: "testrb-meetup") do |paths|
      assert_includes Static::Validators::MeetupFolder.new(file_path: paths[:event]).errors.first.message, %(should be "testrb-YYYY-MM-DD")
    end
  end

  test "MeetupFolder ignores conferences and the undated Rails Girls groups" do
    with_meetup(event_id: "testconf-2026", kind: "conference", start_date: "2026-01-14") do |paths|
      assert_empty Static::Validators::MeetupFolder.new(file_path: paths[:event]).errors
    end

    with_meetup(event_id: "rails-girls-copenhagen") do |paths|
      assert_empty Static::Validators::MeetupFolder.new(file_path: paths[:event]).errors
    end
  end

  private

  def with_meetup(series_name: "Test.rb", event_title: "Test.rb Meetup", event_id: "testrb-meetup", kind: "meetup", series_frequency: nil, start_date: nil, videos: [{"id" => "x", "title" => "x", "date" => "2026-01-14"}])
    with_static_data_dir do |dir|
      series_dir = File.join(dir, "data", "testrb")
      event_dir = File.join(series_dir, event_id)
      FileUtils.mkdir_p(event_dir)

      paths = {
        series: File.join(series_dir, "series.yml"),
        event: File.join(event_dir, "event.yml"),
        videos: File.join(event_dir, "videos.yml")
      }

      File.write(paths[:series], Yerba::Document.from({"id" => "testrb", "name" => series_name, "kind" => kind, "frequency" => series_frequency}.compact).to_s)
      File.write(paths[:event], Yerba::Document.from({"id" => event_id, "title" => event_title, "kind" => kind, "start_date" => start_date, "end_date" => start_date}.compact).to_s)
      File.write(paths[:videos], Yerba::Document.from(videos).to_s)

      yield paths
    end
  end
end
