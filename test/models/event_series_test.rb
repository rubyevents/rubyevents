require "test_helper"

class EventSeriesTest < ActiveSupport::TestCase
  setup do
    @series = event_series(:railsconf)
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

  test "sync_aliases_from_list handles nil gracefully" do
    assert_no_difference "@series.aliases.count" do
      @series.sync_aliases_from_list(nil)
    end
  end
end
