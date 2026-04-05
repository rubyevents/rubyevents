require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    talk = talks(:meetup_past_talk)
    notification_user = notification_users(:one)
    notification_user.update(user: @user, object_id: talk.id)
    sign_in_as @user
  end

  test "should get index" do
    get notifications_path
    assert_response :success
    assert_select "h1", "Notifications"
  end

  test "index displays user notifications ordered by created_at desc" do
    get notifications_path
    assert_response :success

    notification_users = @user.notification_users.includes(:notification).order(created_at: :desc)
    assert_equal notification_users.count, assigns(:notifications).count
  end

  test "should redirect to notification link and mark as read" do
    notification_user = notification_users(:one)
    assert_not notification_user.read

    get redirect_notification_path(notification_user)

    notification_user.reload
    assert notification_user.read
  end

  test "redirect should redirect to notification link" do
    notification_user = notification_users(:one)
    talk = Talk.find(notification_user.object_id)

    get redirect_notification_path(notification_user)

    assert_redirected_to talk_path(talk)
  end

  test "redirect updates read status to true" do
    notification_user = notification_users(:one)

    assert_difference("NotificationUser.where(read: true).count") do
      get redirect_notification_path(notification_user)
    end
  end

  test "redirect with invalid id should return 404" do
    get redirect_notification_path(999999)
    assert_response :not_found
  end
end
