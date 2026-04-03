# == Schema Information
#
# Table name: notification_users
# Database name: primary
#
#  id              :integer          not null, primary key
#  object_class    :string           not null
#  read            :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  notification_id :integer          not null, indexed
#  object_id       :integer          not null
#  user_id         :integer          not null, indexed
#
# Indexes
#
#  index_notification_users_on_notification_id  (notification_id)
#  index_notification_users_on_user_id          (user_id)
#
# Foreign Keys
#
#  notification_id  (notification_id => notifications.id)
#  user_id          (user_id => users.id)
#
class NotificationUser < ApplicationRecord
  belongs_to :notification
  belongs_to :user

  validates :object_class, :object_id, presence: true
end
