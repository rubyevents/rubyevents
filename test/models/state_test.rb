# frozen_string_literal: true

require "test_helper"

class StateTest < ActiveSupport::TestCase
  test "find returns State for valid US state" do
    country = Country.find("US")
    state = State.find(country: country, term: "OR")

    assert_not_nil state
    assert_equal "OR", state.code
    assert_equal "Oregon", state.name
  end

  test "find returns State for full state name" do
    country = Country.find("US")
    state = State.find(country: country, term: "Oregon")

    assert_not_nil state
    assert_equal "OR", state.code
  end

  test "find returns State for state slug" do
    country = Country.find("US")
    state = State.find(country: country, term: "oregon")

    assert_not_nil state
    assert_equal "OR", state.code
  end

  test "find returns nil for blank term" do
    country = Country.find("US")

    assert_nil State.find(country: country, term: nil)
    assert_nil State.find(country: country, term: "")
  end

  test "find returns nil for excluded country" do
    country = Country.find("PL")

    assert_nil State.find(country: country, term: "Warsaw")
  end

  test "find_by_code returns State for code" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_not_nil state
    assert_equal "Oregon", state.name
  end

  test "find_by_name returns State for name" do
    state = State.find_by_name("Oregon", country: Country.find("US"))

    assert_not_nil state
    assert_equal "OR", state.code
  end

  test "for_country returns array of States" do
    country = Country.find("US")
    states = State.for_country(country)

    assert states.is_a?(Array)
    assert states.any?
    assert states.first.is_a?(State)
  end

  test "supported_country? returns true for US" do
    country = Country.find("US")

    assert State.supported_country?(country)
  end

  test "supported_country? returns false for excluded countries" do
    country = Country.find("PL")

    refute State.supported_country?(country)
  end

  test "name returns English translation" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "Oregon", state.name
  end

  test "code returns state code" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "OR", state.code
  end

  test "slug returns parameterized name" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "oregon", state.slug
  end

  test "display_name returns abbreviation for US states" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "OR", state.display_name
  end

  test "display_name returns full name for GB nations" do
    state = State.find_by_code("ENG", country: Country.find("GB"))

    assert_equal "England", state.display_name
  end

  test "path returns states path for US state" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "/states/us/oregon", state.path
  end

  test "path returns countries path for GB nation" do
    state = State.find_by_code("ENG", country: Country.find("GB"))

    assert_equal "/countries/england", state.path
  end

  test "to_param returns slug" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "oregon", state.to_param
  end

  test "country returns associated Country" do
    country = Country.find("US")
    state = State.find_by_code("OR", country: country)

    assert_equal country, state.country
  end

  test "alpha2 returns country alpha2" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert_equal "US", state.alpha2
  end

  test "two states with same code and country are equal" do
    country = Country.find("US")
    state1 = State.find_by_code("OR", country: country)
    state2 = State.find_by_code("OR", country: country)

    assert_equal state1, state2
  end

  test "two states with different codes are not equal" do
    country = Country.find("US")
    state1 = State.find_by_code("OR", country: country)
    state2 = State.find_by_code("CA", country: country)

    assert_not_equal state1, state2
  end

  test "events returns ActiveRecord::Relation" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert state.events.is_a?(ActiveRecord::Relation)
  end

  test "users returns ActiveRecord::Relation" do
    state = State.find_by_code("OR", country: Country.find("US"))

    assert state.users.is_a?(ActiveRecord::Relation)
  end

  test "to_location returns Location with state and country" do
    state = State.find_by_code("OR", country: Country.find("US"))
    location = state.to_location

    assert_kind_of Location, location
    assert_equal "OR, United States", location.to_text
  end

  test "to_location for GB nation" do
    state = State.find_by_code("ENG", country: Country.find("GB"))
    location = state.to_location

    assert_equal "England, United Kingdom", location.to_text
  end

  test "to_location for AU state" do
    state = State.find_by_code("NSW", country: Country.find("AU"))
    location = state.to_location

    assert_equal "NSW, Australia", location.to_text
  end

  test "to_location for CA province" do
    state = State.find_by_code("ON", country: Country.find("CA"))
    location = state.to_location

    assert_equal "ON, Canada", location.to_text
  end
end
