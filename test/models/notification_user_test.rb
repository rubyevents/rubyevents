require "test_helper"

class NotificationUserTest < ActiveSupport::TestCase
  setup do
    talk = talks(:meetup_past_talk)
    @notification_user = notification_users(:one)
    @notification_user.update(object_id: talk.id)
  end

  test "generate title" do
    assert_equal "talk title 3", @notification_user.title
  end

  test "generate link to talk" do
    assert_equal "/talks/talk-title-3", @notification_user.to_link
  end
end
