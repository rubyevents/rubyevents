# == Schema Information
#
# Table name: user_talks
# Database name: primary
#
#  id           :integer          not null, primary key
#  discarded_at :datetime
#  speaker_name :string           uniquely indexed => [talk_id]
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  talk_id      :integer          not null, uniquely indexed => [user_id], uniquely indexed => [speaker_name], indexed
#  user_id      :integer          uniquely indexed => [talk_id], indexed
#
# Indexes
#
#  idx_user_talks_linked_unique    (talk_id,user_id) UNIQUE WHERE user_id IS NOT NULL
#  idx_user_talks_unlinked_unique  (talk_id,speaker_name) UNIQUE WHERE speaker_name IS NOT NULL
#  index_user_talks_on_talk_id     (talk_id)
#  index_user_talks_on_user_id     (user_id)
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
