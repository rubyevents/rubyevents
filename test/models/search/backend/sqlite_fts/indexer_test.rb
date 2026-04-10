# frozen_string_literal: true

require "test_helper"

class Search::Backend::SQLiteFTS::IndexerTest < ActiveSupport::TestCase
  setup do
    @talk = talks(:one)
    @user = users(:one)
  end

  test "index handles a talk without raising" do
    assert_nothing_raised do
      Search::Backend::SQLiteFTS::Indexer.index(@talk)
    end
  end

  test "index handles a user without raising" do
    assert_nothing_raised do
      Search::Backend::SQLiteFTS::Indexer.index(@user)
    end
  end

  test "remove handles a talk without raising" do
    assert_nothing_raised do
      Search::Backend::SQLiteFTS::Indexer.remove(@talk)
    end
  end

  test "remove handles a user without raising" do
    assert_nothing_raised do
      Search::Backend::SQLiteFTS::Indexer.remove(@user)
    end
  end
end
