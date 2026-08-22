# frozen_string_literal: true

module Notifications
  module TalkPublished
    extend ActiveSupport::Concern

    def create_user_notification_subscription
      notification = Notification.find_by(name: :talk_published)
      return unless notification

      NotificationUserSubscription.find_or_create_by(
        user: user,
        notification: notification,
        object_id: talk.id,
        object_class: talk.class.name
      )
    end

    def destroy_user_notification_subscription
      notification = Notification.find_by(name: :talk_published)
      return unless notification

      NotificationUserSubscription.find_by(
        user: user,
        notification: notification,
        object_id: talk.id,
        object_class: talk.class.name
      ).destroy
    end
  end
end
