require "test_helper"

class Speakers::EnhanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:admin))
  end

  test "#patch" do
    speaker = users(:marco)

    assert_nil speaker.github_metadata.dig("profile", "login")

    assert_enqueued_jobs 2 do
      patch speakers_enhance_url(speaker, {format: :turbo_stream})
      assert_response :success
    end

    VCR.use_cassette("speakers/enhance_controller_test/patch") do
      perform_enqueued_jobs
    end

    speaker.reload

    assert_equal "marcoroth", speaker.github_metadata.dig("profile", "login")
  end
end
