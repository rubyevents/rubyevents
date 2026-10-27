require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get organizations_url
    assert_response :success
  end

  test "should get show" do
    organization = organizations(:one)
    get organization_url(organization)
    assert_response :success
  end

  test "should show the meetup groups an organization sponsors and organizes" do
    organization = organizations(:one)
    sponsored = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
    organized = EventSeries.create!(name: "Other.rb", slug: "otherrb", kind: :meetup)
    Sponsor.create!(organization: organization, event_series: sponsored, tier: "Supporter", badge: "Venue", started_on: "2024-01-01", ended_on: "2025-12-31")
    EventInvolvement.create!(involvementable: organization, event_series: organized, role: "Organizer")

    get organization_url(organization)

    assert_response :success
    assert_select "h2", text: "Meetup groups"
    assert_select "a[href=?]", series_path(sponsored)
    assert_select "a[href=?]", series_path(organized)
    assert_select "p", text: "Sponsor 2024 - 2025"
  end

  test "should redirect old sponsors path to organizations" do
    get "/sponsors"
    assert_redirected_to organizations_path
  end

  test "should redirect old sponsor show path to organization" do
    organization = organizations(:one)
    get "/sponsors/#{organization.slug}"
    assert_redirected_to organization_path(organization)
  end
end
