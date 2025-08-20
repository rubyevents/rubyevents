# == Schema Information
#
# Table name: watched_talks
#
#  id               :integer          not null, primary key
#  progress_seconds :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  talk_id          :integer          not null, indexed, uniquely indexed => [user_id]
#  user_id          :integer          not null, uniquely indexed => [talk_id], indexed
#
# Indexes
#
#  index_watched_talks_on_talk_id              (talk_id)
#  index_watched_talks_on_talk_id_and_user_id  (talk_id,user_id) UNIQUE
#  index_watched_talks_on_user_id              (user_id)
#
class WatchedTalk < ApplicationRecord
  belongs_to :user, default: -> { Current.user }, touch: true, counter_cache: :watched_talks_count
  belongs_to :talk
end
