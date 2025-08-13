require "application_system_test_case"

class SponsorsTest < ApplicationSystemTestCase
  def setup
    @sponsor_one = sponsors(:one)
    @sponsor_two = sponsors(:two)
    @sponsor_three = sponsors(:three)
    @railsconf_2017 = events(:railsconf_2017)
    @no_sponsors_event = events(:no_sponsors_event)
    @brightonruby_org = organisations(:brightonruby)
    @event_sponsor_one = event_sponsors(:one)
  end

  test "visiting the index, clicking on a sponsor from scroll list, and seeing the sponsor's details" do
    visit root_url

    assert_link "Sponsors"
    click_on "Sponsors"

    assert_selector "h1", text: "Sponsors"

    within '[data-controller="scroll"]' do
      assert_text @sponsor_one.name
      assert_text @sponsor_two.name
      assert_text @sponsor_three.name

      assert_link @sponsor_one.name
      click_on @sponsor_one.name
    end

    assert_text @sponsor_one.name
    assert_text @sponsor_one.description
    assert_text @sponsor_one.main_location
    assert_link "#{@sponsor_one.domain}"
    assert_selector "img[src*='#{@sponsor_one.logo_url}']"

    assert_selector "input[aria-label='Supported Events (1)'][checked]"
    within ".tab-content" do
      assert_selector "h2", text: @railsconf_2017.start_date.year.to_s
      assert_text @railsconf_2017.name
      assert_selector "a[href='/events/#{@railsconf_2017.slug}']"
    end

    assert_selector "input[aria-label='Map (1)']"
    find("input[aria-label='Map (1)']").click
    within ".tab-content" do

      country = @railsconf_2017.static_metadata&.country
      country_events = @sponsor_one.events.group_by { |event| event.static_metadata&.country }
        .compact
        .find { |c, _| c == country }&.last || []
      event_count = country_events.size

      assert_selector "h3", text: country&.continent || "Unknown"
      assert_text "🇺🇸"
      assert_text country&.translations["en"]
      assert_text "#{event_count} #{'event'.pluralize(event_count)}"
      assert_text "#{@railsconf_2017.name} (#{@railsconf_2017.start_date.year})"
    end

    assert_selector "input[aria-label='Statistics']"
    find("input[aria-label='Statistics']").click
    within ".tab-content" do
      assert_text "Total Events Sponsored\n1\n#{@railsconf_2017.start_date.year} - #{@railsconf_2017.start_date.year}\n"

      assert_text "Geographic Reach\n1\n1 continent\n"

      assert_text "Talks at Sponsored Events\n0\nSupporting knowledge sharing\n"

      assert_text "Conference Organisations\n1\nUnique partnerships\n"

      assert_text "Years Active\n1\n#{@railsconf_2017.start_date.year} - #{@railsconf_2017.start_date.year}\n"

      assert_text "Sponsorship Tiers\n#{@event_sponsor_one.tier.capitalize}\n1\n"

      assert_text "Event Scale\n⏳\nEvent Awaiting Content\n1\n"

      assert_text "Top Supported Organisations\n#{@railsconf_2017.organisation.name}\n1 event\n"

      assert_text "Additional Sponsorships\n#{@event_sponsor_one.badge}\nat\n#{@railsconf_2017.name}\n(#{@railsconf_2017.start_date.year})"
    end

    assert_link "Back to Sponsors"
    click_on "Back to Sponsors"

    within "#sponsors" do
      assert_link @sponsor_one.name
      assert_link @sponsor_two.name
      assert_link @sponsor_three.name
    end
  end

  test "visiting the index, clicking on a letter, and seeing the sponsors that start with that letter" do
    visit root_url

    assert_link "Sponsors"
    click_on "Sponsors"

    assert_selector "h1", text: "Sponsors"

    within "#sponsors" do
      assert_link @sponsor_one.name
      assert_link @sponsor_two.name
      assert_link @sponsor_three.name
    end

    assert_link "A"
    click_on "A"
    within "#sponsors" do
      assert_link @sponsor_one.name
      assert_no_link @sponsor_two.name
      assert_no_link @sponsor_three.name
    end

    assert_link "B"
    click_on "B"
    within "#sponsors" do
      assert_no_link @sponsor_one.name
      assert_link @sponsor_two.name
      assert_no_link @sponsor_three.name
    end

    assert_link "C"
    click_on "C"
    within "#sponsors" do
      assert_no_link @sponsor_one.name
      assert_no_link @sponsor_two.name
      assert_link @sponsor_three.name
    end
  end

  test "visiting the index, clicking on the incomplete data notice, and seeing the events that need data" do
    visit root_url

    assert_link "Sponsors"
    click_on "Sponsors"

    assert_selector "h1", text: "Sponsors"

    assert_text "Sponsor data is incomplete"
    assert_text "Many conferences are still missing sponsor information. Help us complete the database!"
    assert_link "View conferences missing sponsor data"
    click_on "View conferences missing sponsor data"

    assert_selector "h1", text: "Conferences Missing Sponsor Data"

    assert_text @no_sponsors_event.name
    assert_selector "h2", text: "#{@no_sponsors_event.start_date.year} (1 event)"
    within "a[href='/events/#{@no_sponsors_event.slug}']" do
      assert_text @no_sponsors_event.name
      assert_text @brightonruby_org.name
      assert_text @no_sponsors_event.start_date.strftime("%B %Y")
      assert_text "#{@no_sponsors_event.city}, #{@no_sponsors_event.country_code}"
    end

    assert_text "Total conferences missing sponsor data: #{Event.conference.left_joins(:event_sponsors).where(event_sponsors: {id: nil}).past.count}"
  end
end
