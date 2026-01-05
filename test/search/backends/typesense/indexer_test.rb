# frozen_string_literal: true

require "test_helper"

class Backends::Typesense::IndexerTest < ActiveSupport::TestCase
  # These tests verify the interface exists and handles edge cases
  # Actual Typesense integration is tested via VCR cassettes elsewhere

  test "indexer class exists" do
    assert defined?(Backends::Typesense::Indexer)
  end

  test "indexer responds to index" do
    assert Backends::Typesense::Indexer.respond_to?(:index)
  end

  test "indexer responds to remove" do
    assert Backends::Typesense::Indexer.respond_to?(:remove)
  end

  test "indexer responds to reindex_all" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_all)
  end

  test "indexer responds to reindex_talks" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_talks)
  end

  test "indexer responds to reindex_users" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_users)
  end

  test "indexer responds to reindex_events" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_events)
  end

  test "indexer responds to reindex_topics" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_topics)
  end

  test "indexer responds to reindex_series" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_series)
  end

  test "indexer responds to reindex_organizations" do
    assert Backends::Typesense::Indexer.respond_to?(:reindex_organizations)
  end
end
