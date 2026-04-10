# frozen_string_literal: true

require "test_helper"

class Search::BackendTest < ActiveSupport::TestCase
  test "resolve returns SQLiteFTS by default in test environment" do
    assert_equal Search::Backend::SQLiteFTS, Search::Backend.resolve
  end

  test "resolve returns SQLiteFTS when preferred is sqlite_fts" do
    assert_equal Search::Backend::SQLiteFTS, Search::Backend.resolve(:sqlite_fts)
  end

  test "resolve returns SQLiteFTS when preferred is sqlite_fts string" do
    assert_equal Search::Backend::SQLiteFTS, Search::Backend.resolve("sqlite_fts")
  end

  test "resolve returns default backend for unknown preference" do
    assert_equal Search::Backend::SQLiteFTS, Search::Backend.resolve(:unknown)
  end

  test "backends hash contains both backends" do
    assert_equal Search::Backend::SQLiteFTS, Search::Backend.backends[:sqlite_fts]
  end

  test "index does not raise for valid record" do
    record = talks(:one)

    assert_nothing_raised do
      Search::Backend.index(record)
    end
  end

  test "remove does not raise for valid record" do
    record = talks(:one)

    assert_nothing_raised do
      Search::Backend.remove(record)
    end
  end
end
