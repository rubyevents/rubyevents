# frozen_string_literal: true

require "test_helper"

class Profiles::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @profile = users(:chael)
  end

  test "if user is not logged in - redirects" do
    get profile_notes_path(@profile)
    assert_response :redirect
    assert_redirected_to profile_path(@profile)
  end

  test "if user is not favorited - redirects" do
    sign_in_as(@user)
    get profile_notes_path(@profile)
    assert_response :redirect
    assert_redirected_to profile_path(@profile)
  end

  test "if user is favorited - shows notes" do
    sign_in_as(@user)
    @profile.favorited_by.create(user: @user, notes: "This is a note about the user")
    get profile_notes_path(@profile)
    assert_response :success
    assert_includes response.body, "This is a note about the user"
  end

  test "edit existing notes" do
    sign_in_as(@user)
    @profile.favorited_by.create(user: @user, notes: "This is a note about the user")
    get edit_profile_notes_path(@profile)
    assert_response :success
    assert_includes response.body, "This is a note about the user"
  end
end
