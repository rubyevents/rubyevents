# frozen_string_literal: true

require "test_helper"

class Search::Backend::SQLiteFTSTest < ActiveSupport::TestCase
  test "available? returns true" do
    assert Search::Backend::SQLiteFTS.available?
  end

  test "name returns :sqlite_fts" do
    assert_equal :sqlite_fts, Search::Backend::SQLiteFTS.name
  end

  test "search_talks returns results and count" do
    results, count = Search::Backend::SQLiteFTS.search_talks("ruby", limit: 10)

    assert_kind_of ActiveRecord::Relation, results
    assert_kind_of Integer, count
  end

  test "search_talks respects limit" do
    results, _count = Search::Backend::SQLiteFTS.search_talks("ruby", limit: 1)

    assert results.size <= 1
  end

  test "search_speakers returns results and count" do
    results, count = Search::Backend::SQLiteFTS.search_speakers("test", limit: 10)

    assert_kind_of ActiveRecord::Relation, results
    assert_kind_of Integer, count
  end

  test "search_events returns results and count" do
    results, count = Search::Backend::SQLiteFTS.search_events("conference", limit: 10)

    assert_kind_of ActiveRecord::Relation, results
    assert_kind_of Integer, count
  end

  test "search_topics returns results and count" do
    results, count = Search::Backend::SQLiteFTS.search_topics("record", limit: 10)

    assert_kind_of ActiveRecord::Relation, results
    assert_kind_of Integer, count
  end

  test "search_series returns results and count" do
    results, count = Search::Backend::SQLiteFTS.search_series("rails", limit: 10)

    assert_kind_of ActiveRecord::Relation, results
    assert_kind_of Integer, count
  end

  test "search_organizations returns results and count" do
    results, count = Search::Backend::SQLiteFTS.search_organizations("ruby", limit: 10)

    assert_kind_of ActiveRecord::Relation, results
    assert_kind_of Integer, count
  end

  test "search_languages returns array and count" do
    results, count = Search::Backend::SQLiteFTS.search_languages("german", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_languages returns empty for blank query" do
    results, count = Search::Backend::SQLiteFTS.search_languages("", limit: 10)

    assert_equal [], results
    assert_equal 0, count
  end

  test "search_locations returns array and count" do
    results, count = Search::Backend::SQLiteFTS.search_locations("united", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_locations returns empty for blank query" do
    results, count = Search::Backend::SQLiteFTS.search_locations("", limit: 10)

    assert_equal [], results
    assert_equal 0, count
  end

  test "search_continents returns array and count" do
    results, count = Search::Backend::SQLiteFTS.search_continents("europe", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_continents returns empty for blank query" do
    results, count = Search::Backend::SQLiteFTS.search_continents("", limit: 10)

    assert_equal [], results
    assert_equal 0, count
  end

  test "search_countries returns array and count" do
    results, count = Search::Backend::SQLiteFTS.search_countries("united", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_countries returns empty for blank query" do
    results, count = Search::Backend::SQLiteFTS.search_countries("", limit: 10)

    assert_equal [], results
    assert_equal 0, count
  end

  test "search_states returns array and count" do
    results, count = Search::Backend::SQLiteFTS.search_states("california", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_states returns empty for blank query" do
    results, count = Search::Backend::SQLiteFTS.search_states("", limit: 10)

    assert_equal [], results
    assert_equal 0, count
  end

  test "search_cities returns array and count" do
    results, count = Search::Backend::SQLiteFTS.search_cities("new york", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_cities returns empty for blank query" do
    results, count = Search::Backend::SQLiteFTS.search_cities("", limit: 10)

    assert_equal [], results
    assert_equal 0, count
  end
end
