# == Schema Information
#
# Table name: user_talks
# Database name: primary
#
#  id           :integer          not null, primary key
#  discarded_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  talk_id      :integer          not null, indexed, uniquely indexed => [user_id]
#  user_id      :integer          not null, indexed, uniquely indexed => [talk_id]
#
# Indexes
#
#  index_user_talks_on_talk_id              (talk_id)
#  index_user_talks_on_user_id              (user_id)
#  index_user_talks_on_user_id_and_talk_id  (user_id,talk_id) UNIQUE
#
# Foreign Keys
#
#  talk_id  (talk_id => talks.id)
#  user_id  (user_id => users.id)
#
class UserTalk < ApplicationRecord
  # mixins
  include Discard::Model

  # associations
  belongs_to :user
  belongs_to :talk, touch: true

  validates :user_id, uniqueness: {scope: :talk_id}

  # callbacks
  after_commit :update_user_talks_count

  private

  def update_user_talks_count
    user.update_column(:talks_count, user.kept_talks.count)
  end
end
