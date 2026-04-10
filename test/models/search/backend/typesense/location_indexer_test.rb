# frozen_string_literal: true

require "test_helper"

class Search::Backend::Typesense::LocationIndexerTest < ActiveSupport::TestCase
  test "location indexer class exists" do
    assert defined?(Search::Backend::Typesense::LocationIndexer)
  end

  test "collection_schema returns valid schema" do
    schema = Search::Backend::Typesense::LocationIndexer.collection_schema

    assert_equal "locations", schema["name"]
    assert_kind_of Array, schema["fields"]
    assert schema["fields"].any? { |f| f["name"] == "name" }
    assert schema["fields"].any? { |f| f["name"] == "type" }
    assert schema["fields"].any? { |f| f["name"] == "event_count" }
  end

  test "responds to reindex_all" do
    assert Search::Backend::Typesense::LocationIndexer.respond_to?(:reindex_all)
  end

  test "responds to index_continents" do
    assert Search::Backend::Typesense::LocationIndexer.respond_to?(:index_continents)
  end

  test "responds to index_countries" do
    assert Search::Backend::Typesense::LocationIndexer.respond_to?(:index_countries)
  end

  test "responds to index_states" do
    assert Search::Backend::Typesense::LocationIndexer.respond_to?(:index_states)
  end

  test "responds to index_cities" do
    assert Search::Backend::Typesense::LocationIndexer.respond_to?(:index_cities)
  end

  test "responds to search" do
    assert Search::Backend::Typesense::LocationIndexer.respond_to?(:search)
  end

  test "build_continent_documents returns array" do
    documents = Search::Backend::Typesense::LocationIndexer.send(:build_continent_documents)

    assert_kind_of Array, documents
  end

  test "build_country_documents returns array" do
    documents = Search::Backend::Typesense::LocationIndexer.send(:build_country_documents)

    assert_kind_of Array, documents
  end

  test "build_state_documents returns array" do
    documents = Search::Backend::Typesense::LocationIndexer.send(:build_state_documents)

    assert_kind_of Array, documents
  end

  test "build_city_documents returns array" do
    documents = Search::Backend::Typesense::LocationIndexer.send(:build_city_documents)

    assert_kind_of Array, documents
  end
end
