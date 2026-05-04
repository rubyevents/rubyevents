require "test_helper"

class Hotwire::Native::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  test "renders auto-submitting POST form for github with redirect_to and state in action URL" do
    with_forgery_protection do
      get hotwire_native_v1_auth_url(provider: :github, redirect_to: "/talks", state: "abc|native:android")
    end
    assert_response :success
    assert_select "form[method='post']" do |forms|
      action = forms.first["action"]
      assert_equal "/auth/github", action.split("?").first
      query = Rack::Utils.parse_nested_query(action.split("?", 2).last)
      assert_equal "/talks", query["redirect_to"]
      assert_equal "abc|native:android", query["state"]
      assert_select "input[type='hidden'][name='authenticity_token']"
    end
  end

  test "omits empty redirect_to and state from action URL" do
    get hotwire_native_v1_auth_url(provider: :github)
    assert_response :success
    assert_select "form[action='/auth/github']"
  end

  private

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
