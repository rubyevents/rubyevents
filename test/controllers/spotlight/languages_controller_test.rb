require "test_helper"

class Spotlight::LanguagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Backends::SQLiteFTS.reset_cache!
  end

  test "returns empty results when no query provided" do
    get spotlight_languages_path(format: :turbo_stream)

    assert_response :success
    assert_match "languages_search_results", response.body
    assert_match "hidden", response.body
  end

  test "returns matching languages when query matches language name" do
    talk = talks(:one)
    talk.update!(language: "ja")
    Backends::SQLiteFTS.reset_cache!

    get spotlight_languages_path(format: :turbo_stream, s: "japan")

    assert_response :success
    assert_match "languages_search_results", response.body
    assert_match "Japanese", response.body
  end

  test "returns matching languages when query matches language code" do
    talk = talks(:one)
    talk.update!(language: "ja")
    Backends::SQLiteFTS.reset_cache!

    get spotlight_languages_path(format: :turbo_stream, s: "ja")

    assert_response :success
    assert_match "languages_search_results", response.body
    assert_match "Japanese", response.body
  end

  test "does not include English in results" do
    get spotlight_languages_path(format: :turbo_stream, s: "english")

    assert_response :success
    refute_match "English", response.body
  end

  test "returns empty results for non-matching query" do
    get spotlight_languages_path(format: :turbo_stream, s: "zzzznotfound")

    assert_response :success
    assert_match "hidden", response.body
  end
end
