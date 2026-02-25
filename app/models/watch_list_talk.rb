# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: watch_list_talks
# Database name: primary
#
#  id            :integer          not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  talk_id       :integer          not null, indexed, uniquely indexed => [watch_list_id]
#  watch_list_id :integer          not null, indexed, uniquely indexed => [talk_id]
#
# Indexes
#
#  index_watch_list_talks_on_talk_id                    (talk_id)
#  index_watch_list_talks_on_watch_list_id              (watch_list_id)
#  index_watch_list_talks_on_watch_list_id_and_talk_id  (watch_list_id,talk_id) UNIQUE
#
# Foreign Keys
#
#  talk_id        (talk_id => talks.id)
#  watch_list_id  (watch_list_id => watch_lists.id)
#
# rubocop:enable Layout/LineLength
class WatchListTalk < ApplicationRecord
  belongs_to :watch_list, counter_cache: :talks_count
  belongs_to :talk
  has_one :user, through: :watch_list, touch: true

  validates :watch_list_id, uniqueness: {scope: :talk_id}

  def reset_watch_list_counter_cache
    WatchList.reset_counters(watch_list_id, :talks)
  end
end
