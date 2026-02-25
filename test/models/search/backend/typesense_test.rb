# frozen_string_literal: true

require "test_helper"

class Search::Backend::TypesenseTest < ActiveSupport::TestCase
  test "name returns :typesense" do
    assert_equal :typesense, Search::Backend::Typesense.name
  end

  test "search_languages delegates to SQLiteFTS" do
    results, count = Search::Backend::Typesense.search_languages("german", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_locations delegates to SQLiteFTS" do
    results, count = Search::Backend::Typesense.search_locations("united", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_continents delegates to SQLiteFTS" do
    results, count = Search::Backend::Typesense.search_continents("europe", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_countries delegates to SQLiteFTS" do
    results, count = Search::Backend::Typesense.search_countries("united", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_states delegates to SQLiteFTS" do
    results, count = Search::Backend::Typesense.search_states("california", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_cities delegates to SQLiteFTS" do
    results, count = Search::Backend::Typesense.search_cities("new york", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end
end
