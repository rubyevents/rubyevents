require "application_system_test_case"

class SponsorsTest < ApplicationSystemTestCase
  def setup
    @sponsor_one = sponsors(:one)
    @sponsor_two = sponsors(:two)
    @sponsor_three = sponsors(:three)
    @organization_one = organizations(:one)
    @organization_two = organizations(:two)
    @organization_three = organizations(:three)
    @railsconf_2017 = events(:railsconf_2017)
    @no_sponsors_event = events(:no_sponsors_event)
  end

  test "visiting the index, clicking on a sponsor from scroll list, and seeing the sponsor's details" do
    visit root_url

    assert_link "Organizations"
    click_on "Organizations"

    assert_selector "h1", text: "Organizations"

    within '[data-controller="scroll"]' do
      assert_text @organization_one.name
      assert_text @organization_two.name
      assert_text @organization_three.name

      assert_link @organization_one.name
      click_on @organization_one.name
    end

    assert_text @organization_one.name
    assert_text @organization_one.description
    assert_text @organization_one.main_location
    assert_link @organization_one.domain.to_s
    assert_selector "img[src*='#{@organization_one.logo_url}']"

    assert_selector "input[aria-label='Supported Events (1)'][checked]"
    within ".tab-content" do
      assert_selector "h2", text: @railsconf_2017.start_date.year.to_s
      assert_text @railsconf_2017.name
      assert_selector "a[href='/events/#{@railsconf_2017.slug}']"
    end

    assert_selector "input[aria-label='Statistics']"
    find("input[aria-label='Statistics']").click
    within ".tab-content" do
      assert_text "Total Events Sponsored\n1\n#{@railsconf_2017.start_date.year} - #{@railsconf_2017.start_date.year}\n"

      assert_text "Talks at Sponsored Events\n0\nSupporting knowledge sharing\n"

      assert_text "Event Series\n1\nUnique partnerships\n"

      assert_text "Sponsorship Tiers\n#{@sponsor_one.tier.capitalize}\n1\n"

      assert_text "Event Scale\n⏳\nEvent Awaiting Content\n1\n"

      assert_text "Top Supported Event Series\n#{@railsconf_2017.series.name}\n1 event\n"

      assert_text "Additional Sponsorships\n#{@sponsor_one.badge}\nat\n#{@railsconf_2017.name}\n(#{@railsconf_2017.start_date.year})"
    end

    assert_link "Back to Organizations"
    click_on "Back to Organizations"

    within "#organizations" do
      assert_link @organization_one.name
      assert_link @organization_two.name
      assert_link @organization_three.name
    end
  end

  test "visiting the index, clicking on a letter, and seeing the sponsors that start with that letter" do
    visit root_url

    assert_link "Organizations"
    click_on "Organizations"

    assert_selector "h1", text: "Organizations"

    within "#organizations" do
      assert_link @organization_one.name
      assert_link @organization_two.name
      assert_link @organization_three.name
    end

    assert_link "A"
    click_on "A"
    within "#organizations" do
      assert_link @organization_one.name
      assert_no_link @organization_two.name
      assert_no_link @organization_three.name
    end

    assert_link "B"
    click_on "B"
    within "#organizations" do
      assert_no_link @organization_one.name
      assert_link @organization_two.name
      assert_no_link @organization_three.name
    end

    assert_link "C"
    click_on "C"
    within "#organizations" do
      assert_no_link @organization_one.name
      assert_no_link @organization_two.name
      assert_link @organization_three.name
    end
  end

  test "visiting the index, clicking on the incomplete data notice, and seeing the events that need data" do
    visit root_url

    assert_link "Organizations"
    click_on "Organizations"

    assert_selector "h1", text: "Organizations"

    assert_text "Organization data is incomplete"
    assert_text "Many conferences are still missing sponsor information. Help us complete the database!"
    assert_link "View conferences missing sponsor data"
    click_on "View conferences missing sponsor data"

    assert_selector "h1", text: "Conferences Missing Sponsor Data"

    assert_text @no_sponsors_event.name
    assert_selector "h2", text: "#{@no_sponsors_event.start_date.year} (1 event)"
    within "a[href='/events/#{@no_sponsors_event.slug}']" do
      assert_text @no_sponsors_event.name
      assert_text @no_sponsors_event.series.name
      assert_text @no_sponsors_event.start_date.strftime("%B %Y")
      assert_text "#{@no_sponsors_event.city}, #{@no_sponsors_event.country_code}"
    end

    assert_text "Total conferences missing sponsor data: #{Event.conference.left_joins(:sponsors).where(sponsors: {id: nil}).past.count}"
  end
end
