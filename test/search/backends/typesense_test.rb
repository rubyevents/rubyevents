# frozen_string_literal: true

require "test_helper"

class Backends::TypesenseTest < ActiveSupport::TestCase
  test "name returns :typesense" do
    assert_equal :typesense, Backends::Typesense.name
  end

  test "search_languages delegates to SQLiteFts" do
    results, count = Backends::Typesense.search_languages("german", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end

  test "search_locations delegates to SQLiteFts" do
    results, count = Backends::Typesense.search_locations("united", limit: 10)

    assert_kind_of Array, results
    assert_kind_of Integer, count
  end
end
