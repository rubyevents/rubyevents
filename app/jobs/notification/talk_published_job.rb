class Notification::TalkPublishedJob < ApplicationJob
  queue_as :low

  def perform(talk_id:)
    notification = Notification.find_by(name: "talk_published")

    notification.users.find_each do |user|
      user.notification_users.create(
        notification: notification,
        object_id: talk_id,
        object_class: "Talk",
        read: false
      )
    end
  end
end
