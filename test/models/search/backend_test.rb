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

  test "reindex_changed_since indexes changed talks with their speakers and events" do
    talk = talks(:one)
    speaker = talk.user_talks.first&.user || flunk("fixture talk needs a speaker")
    started_at = 1.minute.from_now

    travel_to 2.minutes.from_now do
      talk.touch
    end

    indexed = []
    Search::Backend.stub(:index, ->(record) { indexed << record }) do
      Search::Backend.reindex_changed_since(started_at)
    end

    assert_includes indexed, talk
    assert_includes indexed, speaker
    assert_includes indexed, talk.event
    assert_not_includes indexed, talks(:two)
  end
end
