require "test_helper"

class Static::EventTest < ActiveSupport::TestCase
  include StaticDataSandbox

  SLUG = "helveticruby-2025"

  teardown do
    Static::EventSeries.unload!
    Static::Event.unload!
  end

  test "import!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    ENV["SEED_SMOKE_TEST"] = "true"
    result = event.import!
    assert_equal "Helvetic Ruby 2025", result.name
  ensure
    ENV.delete("SEED_SMOKE_TEST")
  end

  test "import_event!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    result = event.import_event!
    assert_equal "Helvetic Ruby 2025", result.name
  end

  test "ruby_focused? is true unless the event sets it to false" do
    assert Static::Event.find_by_slug(SLUG).ruby_focused?
    refute Static::Event.find_by_slug("splash-2025").ruby_focused?
  end

  test "import_event! stores whether the event is about Ruby" do
    Static::EventSeries.find_by_slug("rubyevents").import_series!

    refute Static::Event.find_by_slug("splash-2025").import_event!.ruby_focused?
  end

  test "import_event! moves the event listed in old_ids to the new id" do
    with_renamed_event do
      Static::EventSeries.find_by_slug("testconf").import_series!
      previous = ::Event.create!(name: "Testconf 2024", slug: "testconf-24", series: ::EventSeries.find_by!(slug: "testconf"))

      record = Static::Event.find_by_slug("testconf-2024").import_event!

      assert_equal previous.id, record.id
      assert_equal "testconf-2024", record.slug
      assert_nil ::Event.find_by(slug: "testconf-24")
      assert_equal record, ::Event.find_by_slug_or_alias("testconf-24")
    end
  end

  test "import_event! keeps the old id as an alias when there is no event to move" do
    with_renamed_event do
      Static::EventSeries.find_by_slug("testconf").import_series!

      record = Static::Event.find_by_slug("testconf-2024").import_event!

      assert_equal "testconf-2024", record.slug
      assert_equal record, ::Event.find_by_slug_or_alias("testconf-24")
    end
  end

  test "import_event! merges an event listed in old_ids that still exists next to it" do
    with_renamed_event do
      series = ::EventSeries.create!(name: "Testconf", slug: "testconf", kind: :conference)
      existing = ::Event.create!(name: "Testconf 2024", slug: "testconf-2024", series: series)
      duplicate = ::Event.create!(name: "Testconf 24", slug: "testconf-24", series: series)
      duplicate.event_participations.create!(user: users(:one), role: "attendee")

      Static::Event.find_by_slug("testconf-2024").import_event!

      assert_nil ::Event.find_by(id: duplicate.id)
      assert_equal "attendee", ::EventParticipation.find_by(user: users(:one), event: existing)&.role
      assert_equal existing, ::Alias.find_by(slug: "testconf-24")&.aliasable
    end
  end

  test "import_cfps!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_cfps!(event_record)
    assert event_record.cfps.exists?
  end

  test "import_videos!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_videos!(event_record)
    assert event_record.talks.exists?
  end

  test "import_videos! destroys talks listed under removed_talk_ids" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_videos!(event_record)

    removed_id = event_record.talks.first.static_id
    kept_count = event_record.talks.count - 1

    event.stub(:attributes, event.attributes.merge("removed_talk_ids" => [removed_id])) do
      event.import_videos!(event_record)
    end

    assert_nil ::Talk.find_by(static_id: removed_id)
    assert_equal kept_count, event_record.talks.reload.count
  end

  test "import_videos! leaves talks alone when removed_talk_ids is empty" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_videos!(event_record)

    count = event_record.talks.count
    event.import_videos!(event_record)

    assert_equal count, event_record.talks.reload.count
  end

  test "import_sponsors!" do
    Static::EventSeries.find_by_slug("helveticruby").import_series!
    event = Static::Event.find_by_slug(SLUG)
    event_record = event.import_event!
    event.import_sponsors!(event_record)
    assert event_record.sponsors.exists?
  end

  test "import_sponsors! imports sponsor attributes" do
    Static::EventSeries.find_by_slug("balkanruby").import_series!
    event = Static::Event.find_by_slug("balkanruby-2025")
    event_record = event.import_event!
    event.import_sponsors!(event_record)
    assert event_record.sponsors.exists?
    avo = Organization.find_by(name: "Avo")
    avo_sponsor = event_record.sponsors.find_by(organization: avo)
    assert_equal "Party Sponsor", avo_sponsor.badge
  end

  test "import_sponsors! imports a sponsor whose name was renamed to be slugifiable" do
    Static::EventSeries.find_by_slug("kaigi-on-rails").import_series!
    event = Static::Event.find_by_slug("kaigi-on-rails-2026")
    event_record = event.import_event!

    assert_nil Organization.find_by(name: "FjordBootCamp")

    event.import_sponsors!(event_record)

    organization = Organization.find_by(name: "FjordBootCamp")
    assert_equal "fjordbootcamp", organization.slug
    assert event_record.sponsors.exists?(organization: organization)
  end

  test "import_sponsors! imports a sponsor listed in multiple tiers" do
    Static::EventSeries.find_by_slug("deccan-queen-on-rails").import_series!
    event = Static::Event.find_by_slug("deccan-queen-on-rails-2026")
    event_record = event.import_event!
    event.import_sponsors!(event_record)

    zendesk = Organization.find_by(name: "Zendesk")
    tiers = event_record.sponsors.where(organization: zendesk).pluck(:tier)

    assert_equal ["Gold", "Rails Girls Sponsor"], tiers.sort

    event.import_sponsors!(event_record)

    assert_equal 2, event_record.sponsors.reload.where(organization: zendesk).count
  end

  test "import_involvements!" do
    event = Static::Event.find_by_slug("xoruby-portland-2025")
    event.import_event!
    event_record = event.event_record
    event.import_involvements!(event_record)
    involvements = event_record.reload.event_involvements.pluck(:id)
    event.import_involvements!(event_record)
    assert_equal involvements, event_record.reload.event_involvements.pluck(:id)
    assert_equal 7, event_record.event_involvements.count
  end

  test "today? returns false if event is in the past" do
    event = Static::Event.find_by_slug("railsconf-2025")
    assert_not event.today?
  end

  test "home_sort_date uses the event's own dates for non-conference, non-meetup events" do
    event = Static::Event.find_by_slug("ceru-camp-2009")
    stub_record = Event.new(start_date: Date.new(2000, 1, 1))

    assert_equal "retreat", event.kind
    assert_equal event.end_date, event.home_sort_date(event_record: stub_record)
  end

  test "home_sort_date prefers recordings_published_date when present" do
    event = Static::Event.find_by_slug("brightonruby-2025")
    stub_record = Event.new(start_date: Date.new(2000, 1, 1))

    assert_equal event.published_date, event.home_sort_date(event_record: stub_record)
  end

  test "state_code is parsed from location on import" do
    Static::EventSeries.find_by_slug("xoruby").import_series!
    Static::City.all.detect { |city| city.slug == "montreal" }.import!

    event = Static::Event.find_by_slug("xoruby-montreal-2026")
    record = event.import_event!

    assert_equal "Montréal", record.city
    assert_equal "QC", record.state_code
    assert_equal "CA", record.country_code
    assert_includes City.find_by!(slug: "montreal").events, record
  end

  test "state_code falls back to featured city when location omits state" do
    Static::EventSeries.find_by_slug("montrealrb").import_series!
    Static::City.all.detect { |city| city.slug == "montreal" }.import!

    event = Static::Event.find_by_slug("montrealrb-2022-07-06")
    record = event.import_event!

    assert_equal "Montréal", record.city
    assert_equal "QC", record.state_code
    assert_equal "CA", record.country_code
  end

  test "create writes an empty videos.yml next to the new event.yml" do
    with_static_data_dir do |root|
      FileUtils.mkdir_p(File.join(root, "data/testconf"))
      File.write(File.join(root, "data/testconf/series.yml"), %(---\nid: "testconf"\nname: "TestConf"\n))

      event = Static::Event.create(series_slug: "testconf", title: "TestConf 2024", kind: "conference", start_date: "2024-05-01", end_date: "2024-05-02", location: "online", timezone: "UTC", coordinates: false)
      videos_path = File.join(File.dirname(event.file_path), "videos.yml")

      assert_equal File.join(root, "data/testconf/testconf-2024/event.yml"), event.file_path
      assert File.exist?(videos_path)
      assert_equal [], Yerba.parse_file(videos_path).values
    end
  end

  test "start_date and end_date are required" do
    event = Static::Event.new("title" => "My Meetup", "kind" => "meetup")

    assert_not event.valid?
    assert_equal ["start_date is required", "end_date is required"], event.errors.full_messages
  end

  test "end_date must be on or after start_date" do
    assert Static::Event.new("kind" => "conference", "start_date" => "2025-11-13", "end_date" => "2025-11-13").valid?

    event = Static::Event.new("kind" => "conference", "start_date" => "2025-11-13", "end_date" => "2025-11-12")

    assert_not event.valid?
    assert_equal ["end_date must be on or after start_date"], event.errors.full_messages
  end

  test "dates are YYYY-MM-DD and exist" do
    placeholder = Static::Event.new("kind" => "conference", "start_date" => "2017-xx-xx", "end_date" => "2017-11-15")

    assert_not placeholder.valid?
    assert_equal [%(start_date "2017-xx-xx" is not a date, use YYYY-MM-DD and set `date_precision` to "month" or "year" when the exact date is unknown)], placeholder.errors.full_messages

    impossible = Static::Event.new("kind" => "conference", "start_date" => "2025-02-30", "end_date" => "2025-02-30")

    assert_not impossible.valid?
    assert_equal 2, impossible.errors.count
  end

  test "start_time and end_time are only for one-day events" do
    assert Static::Event.new("kind" => "meetup", "start_date" => "2025-11-12", "end_date" => "2025-11-12", "start_time" => "18:30", "end_time" => "21:00").valid?

    event = Static::Event.new("kind" => "conference", "start_date" => "2025-11-12", "end_date" => "2025-11-14", "start_time" => "09:00", "end_time" => "18:00")

    assert_not event.valid?
    assert_equal [
      "start_time is only for one-day events, this one runs from 2025-11-12 to 2025-11-14. Put the hours of each day in its schedule.yml instead",
      "end_time is only for one-day events, this one runs from 2025-11-12 to 2025-11-14. Put the hours of each day in its schedule.yml instead"
    ], event.errors.full_messages
  end

  test "a meetup named after its series and date is valid" do
    with_meetup_folder("testrb-2026-01-14", start_date: "2026-01-14") do |event|
      assert_empty meetup_folder_errors(event)
    end
  end

  test "a meetup may have a counter for another meetup on the same day" do
    with_meetup_folder("testrb-2026-01-14-2", start_date: "2026-01-14") do |event|
      assert_empty meetup_folder_errors(event)
    end
  end

  test "flags a meetup that isn't named after its series and date" do
    with_meetup_folder("testrb-meetup-january-2026", start_date: "2026-01-14") do |event|
      assert_includes meetup_folder_errors(event).first, %(meetup id "testrb-meetup-january-2026" should be "testrb-2026-01-14")
      assert_equal 2, event.error_location(event.errors.find { |error| error.message.start_with?("meetup id") }).start_line
    end
  end

  test "flags a meetup without a date" do
    with_meetup_folder("testrb-meetup") do |event|
      assert_includes meetup_folder_errors(event).first, %(should be "testrb-YYYY-MM-DD")
    end
  end

  test "does not check the folder of a conference" do
    with_meetup_folder("testconf-2026", kind: "conference", start_date: "2026-01-14") do |event|
      assert_empty meetup_folder_errors(event)
    end
  end

  private

  def with_renamed_event
    with_static_data_dir do |root|
      directory = File.join(root, "data/testconf/testconf-2024")
      FileUtils.mkdir_p(directory)

      File.write(File.join(root, "data/testconf/series.yml"), Yerba::Document.from({"id" => "testconf", "name" => "Testconf", "kind" => "conference"}).to_s)
      File.write(File.join(directory, "event.yml"), Yerba::Document.from({"id" => "testconf-2024", "old_ids" => ["testconf-24"], "title" => "Testconf 2024", "kind" => "conference", "location" => "Bern, Switzerland", "timezone" => "Europe/Zurich", "start_date" => "2024-06-01", "end_date" => "2024-06-01"}).to_s)

      yield root
    end
  end

  def meetup_folder_errors(event)
    event.valid?(:lint)
    event.errors.full_messages.grep(/\Ameetup id /)
  end

  def with_meetup_folder(event_id, kind: "meetup", start_date: nil)
    with_static_data_dir do |root|
      path = File.join(root, "data/testrb", event_id, "event.yml")
      FileUtils.mkdir_p(File.dirname(path))

      File.write(File.join(root, "data/testrb/series.yml"), Yerba::Document.from({"id" => "testrb", "name" => "Test.rb", "kind" => kind}).to_s)
      File.write(path, Yerba::Document.from({"id" => event_id, "title" => "Test.rb", "kind" => kind, "start_date" => start_date, "end_date" => start_date}.compact).to_s)

      yield Static::Event.in_file(path).first
    end
  end
end
