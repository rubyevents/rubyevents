require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "all" do
    assert_equal Hash, Language.all.class
    assert_equal 184, Language.all.length
  end

  test "all lookup" do
    assert_equal "English", Language.all["en"]
    assert_equal "French", Language.all["fr"]
    assert_equal "German", Language.all["de"]
    assert_equal "Japanese", Language.all["ja"]
    assert_equal "Portuguese", Language.all["pt"]
    assert_equal "Spanish", Language.all["es"]
  end

  test "alpha2_codes" do
    assert_equal Array, Language.alpha2_codes.class
    assert_equal 184, Language.alpha2_codes.length
  end

  test "english_names" do
    assert_equal Array, Language.english_names.class
    assert_equal 184, Language.english_names.length
  end

  test "find by full name" do
    assert_equal "en", Language.find("English").alpha2
    assert_equal "en", Language.find("english").alpha2

    assert_equal "ja", Language.find("Japanese").alpha2
    assert_equal "ja", Language.find("japanese").alpha2

    assert_nil Language.find("random")
    assert_nil Language.find("nonexistent")
  end

  test "find by alpha2 code" do
    assert_equal "English", Language.find("en").english_name
    assert_equal "English", Language.find("en").english_name

    assert_equal "Japanese", Language.find("ja").english_name
    assert_equal "Japanese", Language.find("ja").english_name
  end

  test "find by alpha3 code" do
    assert_equal "English", Language.find("eng").english_name
    assert_equal "English", Language.find("eng").english_name

    assert_equal "Japanese", Language.find("jpn").english_name
    assert_equal "Japanese", Language.find("jpn").english_name
  end

  test "used" do
    assert_equal 1, Language.used.length
    assert_equal ["en"], Language.used.keys

    talk = talks(:two)
    talk.language = "Spanish"
    talk.save

    assert_equal 2, Language.used.length
    assert_equal ["en", "es"], Language.used.keys
  end

  test "find_by_code" do
    record = Language.find_by_code("de")

    assert_not_nil record
    assert_equal "de", record.alpha2
    assert_equal "German", record.english_name
    assert_equal "allemand", record.french_name
  end

  test "find_by_code returns nil for invalid code" do
    assert_nil Language.find_by_code("invalid")
    assert_nil Language.find_by_code("")
  end

  test "talks returns ActiveRecord relation" do
    talks = Language.talks("en")

    assert_kind_of ActiveRecord::Relation, talks
    assert talks.count >= 0
  end

  test "talks filters by language code" do
    talk = talks(:one)
    talk.update!(language: "ja")

    japanese_talks = Language.talks("ja")

    assert_includes japanese_talks, talk
  end

  test "talks_count returns integer" do
    count = Language.talks_count("en")

    assert_kind_of Integer, count
    assert count >= 0
  end

  test "native_name returns native name for known languages" do
    assert_equal "deutsch", Language.native_name("de")
    assert_equal "日本語", Language.native_name("ja")
    assert_equal "español", Language.native_name("es")
    assert_equal "français", Language.native_name("fr")
    assert_equal "português", Language.native_name("pt")
    assert_equal "русский", Language.native_name("ru")
    assert_equal "中文", Language.native_name("zh")
  end

  test "native_name returns nil for unknown languages" do
    assert_nil Language.native_name("en")
    assert_nil Language.native_name("invalid")
  end

  test "synonyms_for returns array of synonyms" do
    synonyms = Language.synonyms_for("de")

    assert_kind_of Array, synonyms
    assert_includes synonyms, "ger"
    assert_includes synonyms, "german"
    assert_includes synonyms, "allemand"
    assert_includes synonyms, "deutsch"
  end

  test "synonyms_for splits multiple names" do
    synonyms = Language.synonyms_for("es")

    assert_includes synonyms, "spanish"
    assert_includes synonyms, "castilian"
    assert_includes synonyms, "espagnol"
    assert_includes synonyms, "castillan"
    assert_includes synonyms, "español"
  end

  test "synonyms_for returns empty array for invalid code" do
    assert_equal [], Language.synonyms_for("invalid")
    assert_equal [], Language.synonyms_for("")
  end

  test "all_synonyms returns hash for used languages" do
    talk = talks(:one)
    talk.update!(language: "ja")

    synonyms = Language.all_synonyms

    assert_kind_of Hash, synonyms
    assert synonyms.key?("ja-language-synonym")
    assert_includes synonyms["ja-language-synonym"]["synonyms"], "ja"
    assert_includes synonyms["ja-language-synonym"]["synonyms"], "japanese"
    assert_includes synonyms["ja-language-synonym"]["synonyms"], "日本語"
  end
end
