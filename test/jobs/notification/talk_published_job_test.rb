require "test_helper"

class Notification::TalkPublishedJobTest < ActiveJob::TestCase
  def setup
    @talk = talks(:one)
    @notification = notifications(:talk_published)
  end

  test "creates notification user" do
    assert_difference "NotificationUser.count", 1 do
      Notification::TalkPublishedJob.perform_now(talk_id: @talk.id)
    end
  end
end
