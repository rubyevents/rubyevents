require "test_helper"

class PageControllerTest < ActionDispatch::IntegrationTest
  test "should get home page" do
    get root_path
    assert_response :success
  end

  test "should get uses page" do
    get uses_path
    assert_response :success
  end

  test "should set global meta tags" do
    get root_path
    assert_response :success

    assert_select "title", Metadata::DEFAULT_TITLE
    assert_select "meta[name=description][content=?]", Metadata::DEFAULT_DESC
    assert_select "link[rel='canonical'][href=?]", request.original_url

    expected_logo_url = @controller.view_context.image_url("logo_og_image.png")

    # OpenGraph
    assert_select "meta[property='og:title'][content=?]", Metadata::DEFAULT_TITLE
    assert_select "meta[property='og:description'][content=?]", Metadata::DEFAULT_DESC
    assert_select "meta[property='og:site_name'][content=?]", Metadata::SITE_NAME
    assert_select "meta[property='og:url'][content=?]", request.original_url
    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[property='og:image'][content=?]", expected_logo_url

    # Twitter
    assert_select "meta[name='twitter:title'][content=?]", Metadata::DEFAULT_TITLE
    assert_select "meta[name='twitter:description'][content=?]", Metadata::DEFAULT_DESC
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "meta[name='twitter:image'][content=?]", expected_logo_url
  end

  test "should redirect to login when accessing recommended page without authentication" do
    get recommended_path
    assert_redirected_to new_session_path
  end

  test "should get recommended page when authenticated" do
    user = users(:one)
    sign_in_as user

    get recommended_path
    assert_select "p", "No recommendations available yet."
  end

  test "should assign recommended talks when authenticated" do
    user = users(:one)
    user2 = users(:two)

    [user, user2].each do |u|
      user.watched_talk_seeder.seed_development_data
    end

    sign_in_as user

    get recommended_path
    assert_response :success
    assert_not_nil assigns(:recommended_talks)
  end

  test "recommended page respects limit parameter" do
    user = users(:one)
    sign_in_as user

    get recommended_path
    assert_response :success
  end
end
