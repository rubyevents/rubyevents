# frozen_string_literal: true

require "test_helper"

class Static::MeetupTitleValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "names a meetup after its group, Meetup and month, and keeps the old wording as its subtitle" do
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
      with_meetup(event_title: title) do |event, path|
        assert_includes title_errors(event).first.to_s, %(title "#{title}" should be "Test.rb Meetup January 2026"), title

        Yerba::Record.fix_all([event], only: Static::MeetupTitleValidator)
        event = Static::Event.in_file(path).first
        assert_equal "Test.rb Meetup January 2026", event["title"], title
        assert_equal subtitle.to_s, event["subtitle"].to_s, title
      end
    end
  end

  test "points at the title" do
    with_meetup(event_title: "Test.rb January 2026") do |event|
      event.valid?(:lint)

      assert_equal 3, event.error_location(event.errors.where(:title).first).start_line
    end
  end

  test "accepts a meetup named after its group, Meetup and month" do
    with_meetup(event_title: "Test.rb Meetup January 2026") do |event|
      assert_empty title_errors(event)
    end
  end

  test "adds the day when the group meets more than once that month" do
    with_meetup(event_title: "Test.rb Meetup January 2026") do |event, path|
      second = File.join(File.dirname(path, 2), "testrb-2026-01-28", "event.yml")
      FileUtils.mkdir_p(File.dirname(second))
      File.write(second, Yerba::Document.from({"id" => "testrb-2026-01-28", "title" => "Test.rb Meetup January 28, 2026", "kind" => "meetup", "start_date" => "2026-01-28", "end_date" => "2026-01-28"}).to_s)

      assert_includes title_errors(event).first, %(should be "Test.rb Meetup January 14, 2026")
    end
  end

  test "leaves Meetup out when the group's name already says it is a group" do
    with_meetup(series_name: "Test Ruby Brigade", event_title: "Test Ruby Brigade January 2026") do |event|
      assert_empty title_errors(event)
    end
  end

  test "ignores conferences" do
    with_meetup(event_title: "TestConf 2026", kind: "conference") do |event|
      assert_empty title_errors(event)
    end
  end

  test "title_name adds Meetup unless the name spells out a group" do
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
      assert_equal title_name, Static::MeetupTitleValidator.title_name(series), series.inspect
    end
  end

  private

  def title_errors(event)
    event.valid?(:lint)
    event.errors.full_messages_for(:title)
  end

  def with_meetup(event_title:, series_name: "Test.rb", kind: "meetup", event_id: "testrb-2026-01-14", start_date: "2026-01-14")
    with_static_data_dir do |root|
      series_dir = File.join(root, "data", "testrb")
      path = File.join(series_dir, event_id, "event.yml")
      FileUtils.mkdir_p(File.dirname(path))

      File.write(File.join(series_dir, "series.yml"), Yerba::Document.from({"id" => "testrb", "name" => series_name, "kind" => kind}).to_s)
      File.write(path, Yerba::Document.from({"id" => event_id, "title" => event_title, "kind" => kind, "start_date" => start_date, "end_date" => start_date}).to_s)

      yield Static::Event.in_file(path).first, path
    end
  end
end
