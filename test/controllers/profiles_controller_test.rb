require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user_with_talk = users(:marco)
  end

  test "should show profile" do
    get profile_url(@user)
    assert_response :success
  end

  test "should show profile with talks" do
    get profile_url(@user_with_talk)
    assert_response :success
    assert_equal @user_with_talk.talks_count, assigns(:talks).length
  end

  test "should redirect to canonical user" do
    talk = @user_with_talk.talks.first
    original_slug = @user_with_talk.slug

    @user_with_talk.assign_canonical_speaker!(canonical_speaker: @user)
    @user_with_talk.reload

    assert_equal @user, @user_with_talk.canonical
    assert @user.talks.ids.include?(talk.id)
    assert @user_with_talk.talks.empty?

    get profile_url(original_slug)
    assert_redirected_to profile_url(@user)
  end

  # test "should redirect to github handle user when slug and github handle are different" do
  #   user = users(:one)
  #   user.github_handle = "new-github"
  #   user.save
  #   get profile_url(user.slug)
  #   assert_redirected_to profile_url(user.github_handle)
  # end

  test "should get edit in a remote modal" do
    get edit_profile_url(@user), headers: {"Turbo-Frame" => "modal"}
    assert_response :success
    assert_template "profiles/edit"
  end

  test "should redirect to root when not in a remote modal" do
    get edit_profile_url(@user)
    assert_response :redirect
    assert_redirected_to root_url
  end

  test "should create a suggestion for user" do
    patch profile_url(@user), params: {user: {bio: "new bio", github: "new-github", name: "new-name", slug: "new-slug", twitter: "new-twitter", website: "new-website"}}

    @user.reload

    assert_redirected_to profile_url(@user)
    assert_not_equal @user.reload.bio, "new bio"
    assert_equal 1, @user.suggestions.pending.count
  end

  test "admin can update directly the user" do
    assert_equal 0, @user.suggestions.pending.count
    sign_in_as users(:admin)
    patch profile_url(@user), params: {user: {bio: "new bio", github: "new-github", name: "new-name", twitter: "new-twitter", website: "new-website"}}

    @user.reload

    assert_redirected_to profile_path(@user)
    assert_equal "new bio", @user.reload.bio
    assert_equal 0, @user.suggestions.pending.count
    assert_equal users(:admin).id, @user.suggestions.last.suggested_by_id
  end

  test "owner can update the user directly" do
    sign_in_as @user

    assert_no_changes -> { @user.suggestions.pending.count } do
      patch profile_url(@user), params: {user: {bio: "new bio", name: "new-name", twitter: "new-twitter", website: "new-website"}}
    end

    assert_redirected_to profile_url(@user)
    assert_equal "new bio", @user.reload.bio
    assert_equal @user.name, "new-name"
    assert_equal @user.twitter, "new-twitter"
    assert_equal @user.website, "https://new-website"
    assert_equal @user.id, @user.suggestions.last.suggested_by_id
  end

  test "should redirect when user not found" do
    get profile_url("non-existent-slug")
    assert_redirected_to speakers_path
    assert_equal "User not found", flash[:notice]
  end

  test "discarded speaker_talks" do
    user = users(:marco)
    assert user.talks_count.positive?

    user.user_talks.each(&:discard)

    get profile_url(user)
    assert_response :success
    assert_equal 0, assigns(:talks).count
  end

  test "should find user by alias slug and redirect to canonical slug" do
    user = User.create!(name: "Test User", github_handle: "test-controller-user")
    user.aliases.create!(name: "Old Name", slug: "old-controller-slug")

    get profile_url("old-controller-slug")
    assert_redirected_to profile_url(user)
  end

  test "should redirect from alias slug to canonical user when user has canonical" do
    canonical_user = User.create!(name: "Canonical User", github_handle: "canonical-controller")
    duplicate_user = User.create!(name: "Duplicate User", github_handle: "duplicate-controller")

    duplicate_user.assign_canonical_user!(canonical_user: canonical_user)
    duplicate_user.reload

    alias_record = Alias.find_by(slug: "duplicate-controller")
    assert_not_nil alias_record
    assert_equal canonical_user.id, alias_record.aliasable_id

    get profile_url("duplicate-controller")
    assert_redirected_to profile_url(canonical_user)
  end
end
