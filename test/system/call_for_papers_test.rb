require "application_system_test_case"

class CallForPapersTest < ApplicationSystemTestCase
  setup do
    @event = events(:future_conference)
  end

  test "visiting the index" do
    skip
    visit root_url

    click_on "CFP"
    assert_selector "h1", text: "Open Call for Proposals"
  end
end
