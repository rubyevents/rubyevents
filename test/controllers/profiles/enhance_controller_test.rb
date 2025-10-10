require "test_helper"

class Profiles::EnhanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:admin))
  end

  test "#patch" do
    user = users(:marco)

    assert_nil user.github_metadata.dig("profile", "login")

    assert_enqueued_jobs 2 do
      patch profiles_enhance_url(user, {format: :turbo_stream})
      assert_response :success
    end

    VCR.use_cassette("profiles/enhance_controller_test/patch") do
      perform_enqueued_jobs
    end

    user.reload

    assert_equal "marcoroth", user.github_metadata.dig("profile", "login")
  end
end
