require "test_helper"

class LanguagePreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "requires authentication" do
    patch language_preference_url(language_code: "ja", answer: "understands")
    assert_response :redirect
  end

  test "records that the user understands a language" do
    sign_in_as @user

    patch language_preference_url(language_code: "ja", answer: "understands")

    assert_response :redirect
    assert_includes @user.reload.languages.understood, "ja"
    assert_not_includes @user.languages.not_understood, "ja"
  end

  test "records that the user does not understand a language" do
    sign_in_as @user

    patch language_preference_url(language_code: "pt", answer: "does_not_understand")

    assert_response :redirect
    assert_includes @user.reload.languages.not_understood, "pt"
    assert_not_includes @user.languages.understood, "pt"
  end

  test "ignores an invalid answer" do
    sign_in_as @user

    patch language_preference_url(language_code: "ja", answer: "maybe")

    assert_empty @user.reload.languages.understood
    assert_empty @user.languages.not_understood
  end

  test "responds to turbo stream by replacing the banner" do
    sign_in_as @user

    patch language_preference_url(language_code: "ja", answer: "understands"), headers: {"Accept" => "text/vnd.turbo-stream.html"}

    assert_response :success
    assert_match "language-prompt", response.body
  end
end
