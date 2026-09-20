# == Schema Information
#
# Table name: notification_user_subscriptions
# Database name: primary
#
#  id              :integer          not null, primary key
#  object_class    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  notification_id :integer          not null, indexed
#  object_id       :integer
#  user_id         :integer          not null, indexed
#
# Indexes
#
#  index_notification_user_subscriptions_on_notification_id  (notification_id)
#  index_notification_user_subscriptions_on_user_id          (user_id)
#
# Foreign Keys
#
#  notification_id  (notification_id => notifications.id)
#  user_id          (user_id => users.id)
#
class NotificationUserSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :notification
end
