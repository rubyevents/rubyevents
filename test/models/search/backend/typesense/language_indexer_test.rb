# frozen_string_literal: true

require "test_helper"

class Search::Backend::Typesense::LanguageIndexerTest < ActiveSupport::TestCase
  test "language indexer class exists" do
    assert defined?(Search::Backend::Typesense::LanguageIndexer)
  end

  test "collection_schema returns valid schema" do
    schema = Search::Backend::Typesense::LanguageIndexer.collection_schema

    assert_equal "languages", schema["name"]
    assert_kind_of Array, schema["fields"]
    assert schema["fields"].any? { |f| f["name"] == "id" }
    assert schema["fields"].any? { |f| f["name"] == "code" }
    assert schema["fields"].any? { |f| f["name"] == "name" }
    assert schema["fields"].any? { |f| f["name"] == "emoji_flag" }
    assert schema["fields"].any? { |f| f["name"] == "talk_count" }
  end

  test "collection_schema has correct default_sorting_field" do
    schema = Search::Backend::Typesense::LanguageIndexer.collection_schema

    assert_equal "talk_count", schema["default_sorting_field"]
  end

  test "responds to reindex_all" do
    assert Search::Backend::Typesense::LanguageIndexer.respond_to?(:reindex_all)
  end

  test "responds to index_languages" do
    assert Search::Backend::Typesense::LanguageIndexer.respond_to?(:index_languages)
  end

  test "responds to search" do
    assert Search::Backend::Typesense::LanguageIndexer.respond_to?(:search)
  end

  test "responds to create_synonyms!" do
    assert Search::Backend::Typesense::LanguageIndexer.respond_to?(:create_synonyms!)
  end

  test "responds to drop_collection!" do
    assert Search::Backend::Typesense::LanguageIndexer.respond_to?(:drop_collection!)
  end

  test "responds to ensure_collection!" do
    assert Search::Backend::Typesense::LanguageIndexer.respond_to?(:ensure_collection!)
  end

  test "build_language_documents returns array" do
    documents = Search::Backend::Typesense::LanguageIndexer.send(:build_language_documents)

    assert_kind_of Array, documents
  end

  test "build_language_documents contains expected fields" do
    documents = Search::Backend::Typesense::LanguageIndexer.send(:build_language_documents)

    skip "No talks with languages in test data" if documents.empty?

    document = documents.first

    assert document.key?(:id)
    assert document.key?(:code)
    assert document.key?(:name)
    assert document.key?(:emoji_flag)
    assert document.key?(:talk_count)
  end

  test "build_language_documents id is prefixed with language_" do
    documents = Search::Backend::Typesense::LanguageIndexer.send(:build_language_documents)

    skip "No talks with languages in test data" if documents.empty?

    documents.each do |document|
      assert document[:id].start_with?("language_"), "Expected id to start with 'language_', got: #{document[:id]}"
    end
  end

  test "build_language_documents talk_count is an integer" do
    documents = Search::Backend::Typesense::LanguageIndexer.send(:build_language_documents)

    skip "No talks with languages in test data" if documents.empty?

    documents.each do |document|
      assert_kind_of Integer, document[:talk_count]
    end
  end
end
