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

  test "featured_reason is :happening while the event is running" do
    event = Event.new(name: "test", series: @series, start_date: Date.today - 1, end_date: Date.today + 1)

    assert event.happening?
    assert_equal :happening, event.featured_reason
  end

  test "featured_reason is :upcoming before the event starts" do
    event = Event.new(name: "test", series: @series, start_date: Date.today + 5, end_date: Date.today + 6)

    assert_equal :upcoming, event.featured_reason
  end

  test "featured_reason is :recently_published for a past event sorted recently" do
    event = Event.new(name: "test", series: @series, start_date: Date.today - 40, end_date: Date.today - 40, home_sort_date: Date.today - 3)

    assert_equal :recently_published, event.featured_reason
  end

  test "featured_reason is :available for an older past event" do
    event = Event.new(name: "test", series: @series, start_date: Date.today - 400, end_date: Date.today - 400, home_sort_date: Date.today - 400)

    assert_equal :available, event.featured_reason
  end

  test "featured_distance is zero while happening, days-until when upcoming, days-since when past" do
    happening = Event.new(name: "test", series: @series, start_date: Date.today - 1, end_date: Date.today + 1)
    upcoming = Event.new(name: "test", series: @series, start_date: Date.today + 5, end_date: Date.today + 6)
    past = Event.new(name: "test", series: @series, start_date: Date.today - 40, end_date: Date.today - 40, home_sort_date: Date.today - 10)

    assert_equal 0, happening.featured_distance
    assert_equal 5, upcoming.featured_distance
    assert_equal 10, past.featured_distance
  end

  test "featured_reason is :cfp_closing when a CFP closes within the window, even for a far-off event" do
    event = events(:future_conference)
    event.cfps.destroy_all
    event.cfps.create!(close_date: Date.today + 2, link: "https://cfp.example.com")
    event.cfps.reload

    assert_equal :cfp_closing, event.featured_reason
    assert_equal 2, event.featured_distance
  end

  test "featured_reason ignores a CFP closing beyond the window" do
    event = events(:future_conference)
    event.cfps.destroy_all
    event.cfps.create!(close_date: Date.today + 10, link: "https://cfp.example.com")
    event.cfps.reload

    assert_nil event.featured_cfp
    assert_equal :upcoming, event.featured_reason
  end

  test "featured_reason ignores a closing CFP without a submission link" do
    event = events(:future_conference)
    event.cfps.destroy_all
    event.cfps.create!(close_date: Date.today + 2, link: nil)
    event.cfps.reload

    assert_nil event.featured_cfp
    assert_equal :upcoming, event.featured_reason
  end

  test "featured_distance interleaves soon-upcoming and freshly-published events" do
    upcoming_soon = Event.new(name: "test", series: @series, start_date: Date.today + 2, end_date: Date.today + 3)
    just_published = Event.new(name: "test", series: @series, start_date: Date.today - 30, end_date: Date.today - 30, home_sort_date: Date.today - 5)

    assert_operator upcoming_soon.featured_distance, :<, just_published.featured_distance
  end

  test "featured returns eligible events in priority order up to the limit" do
    today = Date.today
    Event.update_all(featured_background: nil, featured_color: nil, home_sort_date: nil, recordings_published_date: nil)

    happening = events(:rails_world_2023)
    happening.update!(
      start_date: today.prev_day,
      end_date: today.next_day,
      home_sort_date: today,
      featured_background: "#000000",
      featured_color: "#ffffff"
    )

    upcoming = events(:future_conference)
    upcoming.update!(
      start_date: today + 2.days,
      end_date: today + 3.days,
      home_sort_date: today,
      featured_background: "#000000",
      featured_color: "#ffffff"
    )

    assert_equal [happening], Event.featured(limit: 1, today: today).to_a
    assert_equal [happening, upcoming], Event.featured(limit: 2, today: today).to_a
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
    assert event.city_record.events.include?(event)
  end

  test "today? conference is not today" do
    event = Event.new(start_date: 3.days.ago, end_date: 2.days.ago, kind: :conference)
    assert !event.today?
  end

  test "today? conference is today" do
    event = Event.new(start_date: 1.day.ago, end_date: 2.days.from_now, kind: :conference)
    assert event.today?
  end

  test "today? meetup is not today" do
    event = events(:wnb_rb_meetup)
    talk = talks(:non_english_talk_one)
    talk.update!(date: 3.days.ago, event: event)

    assert !event.today?
  end

  test "today? meetup is today" do
    event = events(:wnb_rb_meetup)
    talk = talks(:non_english_talk_one)
    talk.update!(date: Date.today, event: event)

    assert event.today?
  end

  test "to_ical returns a Icalendar::Event" do
    event = events(:rails_world_2023)

    assert_kind_of Icalendar::Event, event.to_ical
  end

  test "to_ical serializes to a ical formatted string with the event details" do
    travel_to DateTime.new(2026, 1, 1) do
      event = events(:rails_world_2023)
      event.updated_at = Time.now

      assert_equal <<~ICAL.gsub("\n", "\r\n"), event.to_ical.to_ical
        BEGIN:VEVENT
        DTSTAMP:20260101T000000Z
        UID:RUBYEVENTS-#{event.id}
        DTSTART;VALUE=DATE:20231026
        DESCRIPTION:RailsWorld is a yearly conference held in Netherlands.
        LAST-MODIFIED:20260101T000000
        LOCATION:Amsterdam\\, Netherlands
        STATUS:CONFIRMED
        SUMMARY:Rails World 2023
        URL;VALUE=URI:https://rubyonrails.org/world
        END:VEVENT
      ICAL
    end
  end

  test "to_ical sets an inclusive DTEND for multi-day events" do
    event = events(:railsconf_2025)

    ical = event.to_ical.to_ical

    assert_includes ical, "DTSTART;VALUE=DATE:20250708"
    assert_includes ical, "DTEND;VALUE=DATE:20250711"
  end
end
