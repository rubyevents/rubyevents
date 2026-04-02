require "test_helper"

class SluggableTest < ActiveSupport::TestCase
  test "generates slug from latin text" do
    talk = create_talk(title: "Hello World")
    assert_equal "hello-world", talk.slug
  end

  test "transliterates accented characters" do
    talk = create_talk(title: "café résumé")
    assert_equal "cafe-resume", talk.slug
  end

  test "transliterates umlauts" do
    talk = create_talk(title: "Ünïcödé")
    assert_equal "unicode", talk.slug
  end

  test "transliterates hiragana to romaji for talk title" do
    talk = create_talk(title: "まつもとゆきひろ")
    assert_equal "matsumotoyukihiro", talk.slug
  end

  test "transliterates katakana to romaji for talk title" do
    talk = create_talk(title: "カタカナ")
    assert_equal "katakana", talk.slug
  end

  test "transliterates mixed latin and katakana" do
    talk = create_talk(title: "Rubyカンファレンス")
    assert_equal "rubykanfarensu", talk.slug
  end

  test "transliterates hiragana to romaji for user name" do
    user = User.create!(name: "まつもとゆきひろ")
    assert_equal "matsumotoyukihiro", user.slug
  end

  test "transliterates katakana to romaji for user name" do
    user = User.create!(name: "カタカナ")
    assert_equal "katakana", user.slug
  end

  test "preserves existing slug" do
    talk = create_talk(title: "Hello World", slug: "custom-slug")
    assert_equal "custom-slug", talk.slug
  end

  test "uses slug as to_param" do
    talk = create_talk(title: "Hello World")
    assert_equal "hello-world", talk.to_param
  end

  test "fails validation and logs warning for kanji-only text" do
    talk = Talk.new(title: "松本行弘", date: "2025-01-01", static_id: "test-kanji")

    assert_not talk.valid?
    assert_includes talk.errors[:slug], "can't be blank"
  end

  test "auto suffixes on collision when configured" do
    create_talk(title: "Duplicate Talk")
    duplicate = create_talk(title: "Duplicate Talk")

    assert duplicate.slug.start_with?("duplicate-talk-")
    assert_not_equal "duplicate-talk", duplicate.slug
  end

  private

  def create_talk(title:, slug: nil)
    Talk.create!(
      title: title,
      date: "2025-01-01",
      static_id: "test-#{SecureRandom.hex(4)}",
      slug: slug
    ).tap { |t| t.reload }
  end
end
