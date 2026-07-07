# == Schema Information
#
# Table name: requested_talk_topic_votes
# Database name: primary
#
#  id                      :integer          not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  requested_talk_topic_id :integer          not null, uniquely indexed => [user_id], indexed
#  user_id                 :integer          not null, uniquely indexed => [requested_talk_topic_id], indexed
#
# Indexes
#
#  idx_on_requested_talk_topic_id_user_id_2e6363157c            (requested_talk_topic_id,user_id) UNIQUE
#  index_requested_talk_topic_votes_on_requested_talk_topic_id  (requested_talk_topic_id)
#  index_requested_talk_topic_votes_on_user_id                  (user_id)
#
# Foreign Keys
#
#  requested_talk_topic_id  (requested_talk_topic_id => requested_talk_topics.id)
#  user_id                  (user_id => users.id)
#
class RequestedTalkTopicVote < ApplicationRecord
  belongs_to :requested_talk_topic, counter_cache: :votes_count
  belongs_to :user

  validates :user_id,
    uniqueness: {scope: :requested_talk_topic_id}
end
