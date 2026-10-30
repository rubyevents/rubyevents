# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id                :integer          not null, primary key
#  notes             :text
#  subscribable_type :string           not null, uniquely indexed => [user_id, subscribable_id], indexed => [subscribable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  subscribable_id   :integer          not null, uniquely indexed => [user_id, subscribable_type], indexed => [subscribable_type]
#  user_id           :integer          not null, uniquely indexed => [subscribable_type, subscribable_id], indexed
#
# Indexes
#
#  idx_on_user_id_subscribable_type_subscribable_id_fb68f3bd3a  (user_id,subscribable_type,subscribable_id) UNIQUE
#  index_subscriptions_on_subscribable                          (subscribable_type,subscribable_id)
#  index_subscriptions_on_user_id                               (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class Subscription < ApplicationRecord
  # associations
  belongs_to :user
  belongs_to :subscribable, polymorphic: true

  # validations
  validates :subscribable_id, uniqueness: {scope: [:user_id, :subscribable_type]}
  validate :subscribable_is_not_the_user

  private

  def subscribable_is_not_the_user
    errors.add(:subscribable, "can't be yourself") if subscribable_type == "User" && subscribable_id == user_id
  end
end
