require "test_helper"

class SocialProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @social_profile = social_profiles(:speaker)
    @sociable = @social_profile.sociable
    @speaker = @social_profile.sociable
    @owner = User.create!(email: "test@example.com", password: "Secret1*3*5*", github_handle: @speaker.github, verified: true)
    @user = users(:one)
  end

  test "should get new if admin" do
    sign_in_as users(:admin)

    get new_polymorphic_url([@sociable, SocialProfile.new], provider: :twitter)
    assert_response :success
  end

  test "should get new if owner" do
    sign_in_as @owner

    get new_polymorphic_url([@sociable, SocialProfile.new], provider: :twitter)
    assert_response :success
  end

  test "new should return forbidden if user" do
    sign_in_as @user

    get new_polymorphic_url([@sociable, SocialProfile.new], provider: :twitter)
    assert_response :forbidden
  end

  test "new should redirect to sign_in if guest" do
    get new_polymorphic_url([@sociable, SocialProfile.new], provider: :twitter)
    assert_redirected_to sign_in_url
  end

  test "new returns server error if invalid provider" do
    sign_in_as @owner

    assert_raises StandardError do
      get new_polymorphic_url([@sociable, SocialProfile.new])
    end
  end

  test "shouldn't create social_profile if user" do
    sign_in_as @user

    post polymorphic_url([@sociable, :social_profiles]),
      params: {social_profile: {provider: :twitter, value: :john}},
      headers: {"Turbo-Frame" => "new_social_profile", "Accept" => "text/vnd.turbo-stream.html"}

    assert_response :forbidden
  end

  test "should create social profile if admin" do
    sign_in_as users(:admin)

    assert_difference("SocialProfile.count") do
      post polymorphic_url([@sociable, :social_profiles]),
        params: {social_profile: {provider: :twitter, value: :john}},
        headers: {"Turbo-Frame" => "new_social_profile", "Accept" => "text/vnd.turbo-stream.html"}
    end

    assert_response :success
  end

  test "should create social profile if owner" do
    sign_in_as @owner

    assert_difference("SocialProfile.count") do
      post polymorphic_url([@sociable, :social_profiles]),
        params: {social_profile: {provider: :twitter, value: :johndoe}},
        headers: {"Turbo-Frame" => "new_social_profile", "Accept" => "text/vnd.turbo-stream.html"}
    end

    assert_response :success
  end

  test "shouldn't create social_profile with invalid data" do
    sign_in_as @owner

    assert_no_difference("SocialProfile.count") do
      post polymorphic_url([@sociable, :social_profiles]),
        params: {social_profile: {provider: :twitter, value: ""}},
        headers: {"Turbo-Frame" => "new_social_profile", "Accept" => "text/vnd.turbo-stream.html"}
    end

    assert_response :unprocessable_entity
  end

  test "create redirects to sign_in if guest" do
    post polymorphic_url([@sociable, :social_profiles]),
      params: {social_profile: {provider: :twitter, value: :john}},
      headers: {"Turbo-Frame" => "new_social_profile", "Accept" => "text/vnd.turbo-stream.html"}

    assert_redirected_to sign_in_url
  end

  test "should get edit" do
    get edit_social_profile_url(@social_profile)
    assert_response :success
  end

  test "should update social_profile if admin" do
    sign_in_as users(:admin)

    patch social_profile_url(@social_profile),
      params: {social_profile: {provider: :twitter, value: :doe}},
      headers: {"Turbo-Frame" => "social_profile_#{@social_profile.id}", "Accept" => "text/vnd.turbo-stream.html"}
    @social_profile.reload

    assert_equal "doe", @social_profile.value
    assert_response :success
  end

  test "should update social_profile if owner" do
    sign_in_as @owner

    patch social_profile_url(@social_profile),
      params: {social_profile: {provider: :twitter, value: :owner}},
      headers: {"Turbo-Frame" => "social_profile_#{@social_profile.id}", "Accept" => "text/vnd.turbo-stream.html"}
    @social_profile.reload

    assert_equal "owner", @social_profile.value
    assert_response :success
  end

  test "shouldn't update social_profile if not admin or owner" do
    patch social_profile_url(@social_profile),
      params: {social_profile: {provider: :twitter, value: ""}},
      headers: {"Turbo-Frame" => "social_profile_#{@social_profile.id}", "Accept" => "text/vnd.turbo-stream.html"}

    assert_not_equal "", @social_profile.value
  end
end
