# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: talk_topics
# Database name: primary
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  talk_id    :integer          not null, indexed, uniquely indexed => [topic_id]
#  topic_id   :integer          not null, indexed, uniquely indexed => [talk_id]
#
# Indexes
#
#  index_talk_topics_on_talk_id               (talk_id)
#  index_talk_topics_on_topic_id              (topic_id)
#  index_talk_topics_on_topic_id_and_talk_id  (topic_id,talk_id) UNIQUE
#
# Foreign Keys
#
#  talk_id   (talk_id => talks.id)
#  topic_id  (topic_id => topics.id)
#
# rubocop:enable Layout/LineLength
class TalkTopic < ApplicationRecord
  belongs_to :talk
  belongs_to :topic, counter_cache: :talks_count

  validates :talk_id, uniqueness: {scope: :topic_id}

  def reset_topic_counter_cache
    Topic.reset_counters(topic_id, :talks)
  end
end
