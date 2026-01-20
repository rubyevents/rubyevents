require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    @series = event_series(:railsconf)
    @series.update(website: "https://railsconf.org")
  end

  test "validates the country code " do
    assert Event.new(name: "test", country_code: "NL", series: @series).valid?
    assert Event.new(name: "test", country_code: "AU", series: @series).valid?
    refute Event.new(name: "test", country_code: "France", series: @series).valid?
  end

  test "allows nil country code" do
    assert Event.new(name: "test", country_code: nil, series: @series).valid?
  end

  test "returns event website if present" do
    event = Event.new(name: "test", series: @series, website: "https://event-website.com")
    assert_equal "https://event-website.com", event.website
  end

  test "returns event series website if event website is not present" do
    event = Event.new(name: "test", series: @series, website: nil)
    assert_equal "https://railsconf.org", event.website
  end

  test "don't create a unique slug in case of collison" do
    event = Event.create(name: "test")
    assert_equal "test", event.slug

    event = Event.create(name: "test")
    assert_equal "test", event.slug
    refute event.valid?
  end

  test "find_by_slug_or_alias finds event by slug" do
    event = events(:rails_world_2023)
    found = Event.find_by_slug_or_alias(event.slug)

    assert_equal event, found
  end

  test "find_by_slug_or_alias finds event by alias slug" do
    event = events(:rails_world_2023)
    event.slug_aliases.create!(name: "Old Name", slug: "old-event-slug")

    found = Event.find_by_slug_or_alias("old-event-slug")

    assert_equal event, found
  end

  test "find_by_slug_or_alias returns nil for non-existent slug" do
    found = Event.find_by_slug_or_alias("non-existent-slug")

    assert_nil found
  end

  test "find_by_slug_or_alias returns nil for blank slug" do
    assert_nil Event.find_by_slug_or_alias(nil)
    assert_nil Event.find_by_slug_or_alias("")
  end

  test "find_by_name_or_alias finds event by name" do
    event = events(:rails_world_2023)
    found = Event.find_by_name_or_alias(event.name)

    assert_equal event, found
  end

  test "find_by_name_or_alias finds event by alias name" do
    event = events(:rails_world_2023)
    event.slug_aliases.create!(name: "RW 2023", slug: "rw-2023")

    found = Event.find_by_name_or_alias("RW 2023")

    assert_equal event, found
  end

  test "find_by_name_or_alias returns nil for non-existent name" do
    assert_nil Event.find_by_name_or_alias("Non Existent Event")
  end

  test "find_by_name_or_alias returns nil for blank name" do
    assert_nil Event.find_by_name_or_alias(nil)
    assert_nil Event.find_by_name_or_alias("")
  end

  test "sync_aliases_from_list creates aliases from array" do
    event = events(:rails_world_2023)
    aliases = ["RW 2023", "Rails World Amsterdam", "RailsWorld23"]

    assert_difference "event.slug_aliases.count", 3 do
      event.sync_aliases_from_list(aliases)
    end

    assert_equal "RW 2023", event.slug_aliases.find_by(slug: "rw-2023").name
    assert_equal "Rails World Amsterdam", event.slug_aliases.find_by(slug: "rails-world-amsterdam").name
    assert_equal "RailsWorld23", event.slug_aliases.find_by(slug: "railsworld23").name
  end

  test "sync_aliases_from_list does not create duplicates" do
    event = events(:rails_world_2023)
    event.slug_aliases.create!(name: "RW 2023", slug: "rw-2023")

    aliases = ["RW 2023", "Rails World Amsterdam"]

    assert_difference "event.slug_aliases.count", 1 do
      event.sync_aliases_from_list(aliases)
    end
  end

  test "sync_aliases_from_list handles nil gracefully" do
    event = events(:rails_world_2023)

    assert_no_difference "event.slug_aliases.count" do
      event.sync_aliases_from_list(nil)
    end
  end

  test "ft_search finds event by name" do
    event = events(:rails_world_2023)

    results = Event.ft_search("Rails World")
    assert_includes results, event
  end

  test "ft_search finds event by alias name" do
    event = events(:rails_world_2023)
    event.slug_aliases.create!(name: "RW 2023", slug: "rw-2023")

    results = Event.ft_search("RW 2023")
    assert_includes results, event
  end

  test "ft_search is case insensitive" do
    event = events(:rails_world_2023)
    event.slug_aliases.create!(name: "RW 2023", slug: "rw-2023")

    results = Event.ft_search("rw 2023")
    assert_includes results, event
  end

  test "ft_search finds event by series name" do
    event = events(:rails_world_2023)

    results = Event.ft_search(event.series.name)
    assert_includes results, event
  end

  test "ft_search finds event by series alias name" do
    event = events(:rails_world_2023)
    event.series.aliases.create!(name: "RW Conference", slug: "rw-conference")

    results = Event.ft_search("RW Conference")
    assert_includes results, event
  end

  test "country returns Country object when country_code present" do
    event = Event.new(name: "Test Event", series: @series, country_code: "US")

    assert_not_nil event.country
    assert_equal "US", event.country.alpha2
  end

  test "country returns Country object for different country codes" do
    event = Event.new(name: "Test Event", series: @series, country_code: "DE")

    assert_not_nil event.country
    assert_equal "DE", event.country.alpha2
  end

  test "country returns nil when country_code is blank" do
    event = Event.new(name: "Test Event", series: @series, country_code: "")

    assert_nil event.country
  end

  test "country returns nil when country_code is nil" do
    event = Event.new(name: "Test Event", series: @series, country_code: nil)

    assert_nil event.country
  end

  test "country.name returns English translation when country present" do
    event = Event.new(name: "Test Event", series: @series, country_code: "DE")

    assert_equal "Germany", event.country.name
  end

  test "country.name returns translation for US" do
    event = Event.new(name: "Test Event", series: @series, country_code: "US")

    assert_equal "United States", event.country.name
  end

  test "country.path returns country path when country present" do
    event = events(:rails_world_2023)
    event.update!(country_code: "NL")

    assert_equal "/countries/netherlands", event.country.path
  end

  test "grouped_by_country returns countries with their events" do
    event = events(:rails_world_2023)
    event.update!(country_code: "NL")

    result = Event.where(id: event.id).grouped_by_country

    assert result.is_a?(Array)
    assert_equal 1, result.size

    country, events = result.first
    assert_equal "NL", country.alpha2
    assert_includes events, event
  end

  test "grouped_by_country sorts by country name" do
    event1 = events(:rails_world_2023)
    event1.update!(country_code: "NL")

    event2 = Event.create!(name: "Test Event", country_code: "DE", series: @series)

    result = Event.where(id: [event1.id, event2.id]).grouped_by_country

    assert_equal "DE", result.first.first.alpha2  # Germany comes before Netherlands
    assert_equal "NL", result.last.first.alpha2
  end

  test "grouped_by_country excludes events without country" do
    event = events(:rails_world_2023)
    event.update!(country_code: nil)

    result = Event.where(id: event.id).grouped_by_country

    assert_empty result
  end

  test "belongs to city" do
    event = events(:rails_world_2023)

    assert_equal "Amsterdam", event.city_record.name
  end
end
