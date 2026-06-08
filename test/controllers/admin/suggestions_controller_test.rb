require "test_helper"

class Admin::SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @non_admin = users(:one)
    @victim = users(:two)

    # Isolate from placeholder fixtures with invalid polymorphic types.
    Suggestion.delete_all

    # A pending suggestion that, if approved, rewrites the victim's bio.
    @suggestion = Suggestion.create!(
      suggestable: @victim,
      suggested_by: @non_admin,
      content: {"bio" => "pwned"},
      status: :pending
    )
  end

  # Attempt a request that, once the route is admin-constrained, won't match any
  # route for a non-admin (raising RoutingError in tests). We rescue it so the
  # test asserts the *security outcome* regardless of how access is denied.
  def attempt(&block)
    yield
  rescue ActionController::RoutingError
    # access denied at the routing layer — expected once fixed
  end

  test "non-admin cannot approve a suggestion (IDOR / privilege escalation)" do
    sign_in_as @non_admin

    attempt { patch admin_suggestion_url(@suggestion) }

    assert @suggestion.reload.pending?,
      "VULNERABLE: a non-admin was able to approve a suggestion"
    assert_not_equal "pwned", @victim.reload.bio,
      "VULNERABLE: a non-admin escalated to edit another user's profile"
  end

  test "non-admin cannot reject a suggestion" do
    sign_in_as @non_admin

    attempt { delete admin_suggestion_url(@suggestion) }

    assert @suggestion.reload.pending?,
      "VULNERABLE: a non-admin was able to reject a suggestion"
  end

  test "non-admin cannot view the suggestions queue" do
    sign_in_as @non_admin

    response_status = attempt { get admin_suggestions_url } && response.status

    assert_not_equal 200, response_status,
      "VULNERABLE: a non-admin was able to view the suggestions queue"
  end

  test "anonymous user cannot approve a suggestion" do
    attempt { patch admin_suggestion_url(@suggestion) }

    assert @suggestion.reload.pending?,
      "VULNERABLE: an anonymous user was able to approve a suggestion"
  end

  test "admin can view the suggestions queue" do
    sign_in_as @admin

    get admin_suggestions_url
    assert_response :success
  end

  test "admin can approve a suggestion, applying the change" do
    sign_in_as @admin

    patch admin_suggestion_url(@suggestion)

    assert_redirected_to admin_suggestions_path
    assert @suggestion.reload.approved?
    assert_equal "pwned", @victim.reload.bio
  end
end
