require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  setup do
    # Clear cache to ensure fresh content
    Rails.cache.clear
  end

  test "Japanese locale renders page correctly" do
    get "/ja/"
    assert_response :success

    # Check that Japanese translation is used
    assert_select "h2", text: /すべてのRubyイベントをインデックスするミッション/
  end

  test "English locale renders page correctly" do
    get "/"
    assert_response :success

    # Check that English text is displayed
    assert_select "h2", text: /On a mission to index all Ruby events/
  end

  test "locale switcher links work correctly" do
    get "/ja/"
    assert_response :success

    # Check language selector links
    assert_select "a[href='/en']"
    assert_select "a[href='/ja']"
  end

  test "navbar displays translated text in Japanese" do
    get "/ja/"
    assert_response :success

    # Check that navbar items are translated
    assert_select ".navbar", text: /イベント/
    assert_select ".navbar", text: /スピーカー/
  end

  test "navbar displays English text" do
    get "/"
    assert_response :success

    # Check that navbar items are in English
    assert_select ".navbar", text: /Events/
    assert_select ".navbar", text: /Speakers/
  end
end
