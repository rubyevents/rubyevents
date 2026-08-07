require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "valid notification" do
    notification = Notification.new(name: "New Notification")
    assert notification.valid?
  end

  def setup
    @notification = Notification.new(name: "cfp_opened")
  end

  test "should be valid with valid attributes" do
    assert @notification.valid?
  end

  test "should require a name" do
    @notification.name = nil
    assert_not @notification.valid?
  end

  test "should be unique" do
    Notification.create(name: "cfp_opened")
    assert_not @notification.valid?
  end
end
