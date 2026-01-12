require "application_system_test_case"

class SpotlightSearchTest < ApplicationSystemTestCase
  test "show the spotlight search with results" do
    visit root_url

    assert_no_selector "#spotlight-search"

    assert_selector "#magnifying-glass"
    find("#magnifying-glass").click

    assert_selector "#spotlight-search"

    fill_in "query", with: "a"
    assert_selector "#talks_search_results"
  end

  test "open the spotlight search with cmd + k" do
    visit root_url
    find("body").send_keys([:meta, "k"])
    assert_selector "#spotlight-search"
  end
end
