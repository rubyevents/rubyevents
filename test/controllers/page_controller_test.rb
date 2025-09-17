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

  test "home page should render featured events" do
    get root_path
    assert_response :success
    assert_select "h2", text: "Latest talks"
  end
end
