# frozen_string_literal: true

require "test_helper"

class Search::Backend::Typesense::IndexerTest < ActiveSupport::TestCase
  test "indexer class exists" do
    assert defined?(Search::Backend::Typesense::Indexer)
  end

  test "indexer responds to index" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:index)
  end

  test "indexer responds to remove" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:remove)
  end

  test "indexer responds to reindex_all" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_all)
  end

  test "indexer responds to reindex_talks" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_talks)
  end

  test "indexer responds to reindex_users" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_users)
  end

  test "indexer responds to reindex_events" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_events)
  end

  test "indexer responds to reindex_topics" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_topics)
  end

  test "indexer responds to reindex_series" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_series)
  end

  test "indexer responds to reindex_organizations" do
    assert Search::Backend::Typesense::Indexer.respond_to?(:reindex_organizations)
  end
end
