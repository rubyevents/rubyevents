# frozen_string_literal: true

require "test_helper"

class SearchBackendTest < ActiveSupport::TestCase
  test "resolve returns SQLiteFTS by default in test environment" do
    assert_equal Backends::SQLiteFTS, SearchBackend.resolve
  end

  test "resolve returns SQLiteFTS when preferred is sqlite_fts" do
    assert_equal Backends::SQLiteFTS, SearchBackend.resolve(:sqlite_fts)
  end

  test "resolve returns Typesense when preferred is typesense" do
    assert_equal Backends::Typesense, SearchBackend.resolve(:typesense)
  end

  test "resolve returns SQLiteFTS when preferred is sqlite_fts string" do
    assert_equal Backends::SQLiteFTS, SearchBackend.resolve("sqlite_fts")
  end

  test "resolve returns Typesense when preferred is typesense string" do
    assert_equal Backends::Typesense, SearchBackend.resolve("typesense")
  end

  test "resolve returns default backend for unknown preference" do
    assert_equal Backends::SQLiteFTS, SearchBackend.resolve(:unknown)
  end

  test "backends hash contains both backends" do
    assert_equal Backends::Typesense, SearchBackend.backends[:typesense]
    assert_equal Backends::SQLiteFTS, SearchBackend.backends[:sqlite_fts]
  end

  test "index does not raise for valid record" do
    record = talks(:one)

    assert_nothing_raised do
      SearchBackend.index(record)
    end
  end

  test "remove does not raise for valid record" do
    record = talks(:one)

    assert_nothing_raised do
      SearchBackend.remove(record)
    end
  end
end
