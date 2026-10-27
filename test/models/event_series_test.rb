require "test_helper"

class EventSeriesTest < ActiveSupport::TestCase
  setup do
    @series = event_series(:railsconf)
  end

  test "meetup_frequency follows the gaps between the latest meetups" do
    assert_equal "monthly", meetup_group(every: 28.days).meetup_frequency
    assert_equal "every two weeks", meetup_group(every: 14.days).meetup_frequency
    assert_equal "every two months", meetup_group(every: 60.days).meetup_frequency
    assert_equal "quarterly", meetup_group(every: 90.days).meetup_frequency
  end

  test "meetup_frequency is irregular when the gaps vary a lot" do
    series = meetup_group(dates: ["2024-01-10", "2024-01-17", "2024-01-24", "2024-09-01", "2024-09-08", "2025-08-01"])

    assert_equal "irregularly", series.meetup_frequency
  end

  test "meetup_frequency is unknown without enough meetups" do
    series = meetup_group(dates: ["2025-01-10", "2025-02-10"])

    assert_nil series.computed_meetup_frequency
    assert_nil series.meetup_frequency
  end

  test "computed_meetup_frequency fits the frequency column" do
    assert_equal :bimonthly, meetup_group(every: 60.days).computed_meetup_frequency
    assert EventSeries.frequencies.key?("bimonthly")
  end

  test "description leaves out an unknown frequency" do
    series = EventSeries.create!(name: "Fresh.rb", slug: "fresh-rb", kind: :meetup)
    add_meetup(series, 1.week.ago.to_date)

    assert_match "Fresh.rb is a meetup that hosted 1 meetup", EventSeries.includes(:events).find(series.id).description
  end

  test "description of a meetup group says when we know of none of its meetups yet" do
    series = EventSeries.create!(name: "Empty.rb", slug: "empty-rb", kind: :meetup)

    assert_equal "Empty.rb is a meetup group. We don't know of any of its meetups yet.\n", EventSeries.includes(:events).find(series.id).description
  end

  test "meetup_frequency_sentence uses the past tense for an inactive group" do
    assert_equal "Meets monthly", meetup_group(every: 28.days, until_date: 1.week.ago.to_date).meetup_frequency_sentence
    assert_equal "Used to meet monthly", meetup_group(every: 28.days, until_date: 2.years.ago.to_date).meetup_frequency_sentence
  end

  test "a meetup group is inactive after 18 months without a meetup" do
    assert_predicate meetup_group(every: 28.days, until_date: 19.months.ago.to_date), :inactive?
    refute_predicate meetup_group(every: 28.days, until_date: 17.months.ago.to_date), :inactive?
  end

  test "a meetup group with an upcoming meetup is active, however long the gap" do
    series = meetup_group(dates: ["2020-01-14", "2020-02-11", 1.month.from_now.to_date])

    refute_predicate series, :inactive?
  end

  test "a meetup group without meetups isn't inactive unless it ended" do
    series = EventSeries.includes(:events).find(EventSeries.create!(name: "Empty.rb", slug: "empty-rb", kind: :meetup).id)

    refute_predicate series, :inactive?
  end

  test "an ended series is inactive" do
    assert_predicate event_series(:railsconf), :ended?
    assert_predicate EventSeries.includes(:events).find(event_series(:railsconf).id), :inactive?
  end

  test "description uses the past tense for an inactive meetup series" do
    series = EventSeries.create!(name: "Triangle.rb", slug: "triangle-rb", kind: :meetup, frequency: :monthly)
    add_meetup(series, 2.years.ago.to_date)

    assert_match "Triangle.rb was a monthly meetup", EventSeries.includes(:events).find(series.id).description
  end

  test "description uses the present tense for an active meetup series" do
    series = EventSeries.create!(name: "Example.rb", slug: "example-rb", kind: :meetup, frequency: :monthly)
    add_meetup(series, 1.month.ago.to_date)

    assert_match "Example.rb is a monthly meetup", EventSeries.includes(:events).find(series.id).description
  end

  test "find_by_name_or_alias finds series by name" do
    found = EventSeries.find_by_name_or_alias(@series.name)

    assert_equal @series, found
  end

  test "find_by_name_or_alias finds series by alias name" do
    @series.aliases.create!(name: "Rails Conference", slug: "rails-conference")

    found = EventSeries.find_by_name_or_alias("Rails Conference")

    assert_equal @series, found
  end

  test "find_by_name_or_alias returns nil for non-existent name" do
    assert_nil EventSeries.find_by_name_or_alias("Non Existent Series")
  end

  test "find_by_name_or_alias returns nil for blank name" do
    assert_nil EventSeries.find_by_name_or_alias(nil)
    assert_nil EventSeries.find_by_name_or_alias("")
  end

  test "find_by_slug_or_alias finds series by slug" do
    found = EventSeries.find_by_slug_or_alias(@series.slug)

    assert_equal @series, found
  end

  test "find_by_slug_or_alias finds series by alias slug" do
    @series.aliases.create!(name: "Rails Conference", slug: "rails-conference")

    found = EventSeries.find_by_slug_or_alias("rails-conference")

    assert_equal @series, found
  end

  test "find_by_slug_or_alias returns nil for non-existent slug" do
    assert_nil EventSeries.find_by_slug_or_alias("non-existent-slug")
  end

  test "find_by_slug_or_alias returns nil for blank slug" do
    assert_nil EventSeries.find_by_slug_or_alias(nil)
    assert_nil EventSeries.find_by_slug_or_alias("")
  end

  test "sync_aliases_from_list creates aliases from array" do
    aliases = ["Rails Conference", "RailsConf US", "RC"]

    assert_difference "@series.aliases.count", 3 do
      @series.sync_aliases_from_list(aliases)
    end

    assert_equal "Rails Conference", @series.aliases.find_by(slug: "rails-conference").name
    assert_equal "RailsConf US", @series.aliases.find_by(slug: "railsconf-us").name
    assert_equal "RC", @series.aliases.find_by(slug: "rc").name
  end

  test "sync_aliases_from_list does not create duplicates" do
    @series.aliases.create!(name: "Rails Conference", slug: "rails-conference")

    aliases = ["Rails Conference", "RailsConf US"]

    assert_difference "@series.aliases.count", 1 do
      @series.sync_aliases_from_list(aliases)
    end
  end

  test "sync_aliases_from_list takes over an alias the other series no longer lists" do
    previous = EventSeries.create!(name: "Testconf Organisation", slug: "testconf-organisation", kind: :organisation)
    previous.aliases.create!(name: "Testconf Conference", slug: "testconf-conference")

    @series.sync_aliases_from_list(["Testconf Conference"])

    assert_equal @series, ::Alias.find_by(slug: "testconf-conference").aliasable
  end

  test "sync_aliases_from_list leaves an alias the other series still lists" do
    other = EventSeries.create!(name: "Testconf Organisation", slug: "testconf-organisation", kind: :organisation)
    other.aliases.create!(name: "Testconf Conference", slug: "testconf-conference")
    static_series = ->(slug) { {"aliases" => ["Testconf Conference"]} if slug == "testconf-organisation" }

    Static::EventSeries.stub(:find_by_slug, static_series) do
      @series.sync_aliases_from_list(["Testconf Conference"])
    end

    assert_equal other, ::Alias.find_by(slug: "testconf-conference").aliasable
  end

  test "sync_aliases_from_list handles nil gracefully" do
    assert_no_difference "@series.aliases.count" do
      @series.sync_aliases_from_list(nil)
    end
  end

  test "supports weekly and biweekly frequencies" do
    @series.frequency = :weekly
    assert_predicate @series, :weekly?

    @series.frequency = :biweekly
    assert_predicate @series, :biweekly?
  end

  private

  def meetup_group(every: nil, dates: nil, until_date: Date.new(2026, 1, 1))
    series = EventSeries.create!(name: "Test.rb #{SecureRandom.hex(3)}", kind: :meetup)
    dates ||= (0...8).map { |index| until_date - (every * index) }.reverse

    dates.each do |date|
      date = Date.parse(date.to_s)
      Event.create!(name: "Test.rb #{date}", slug: "#{series.slug}-#{date}", series: series, kind: :meetup, start_date: date, end_date: date)
    end

    EventSeries.includes(:events).find(series.id)
  end

  def add_meetup(series, date)
    Event.create!(name: "#{series.name} #{date}", slug: "#{series.slug}-#{date}", series: series, kind: :meetup, start_date: date, end_date: date)
  end
end
