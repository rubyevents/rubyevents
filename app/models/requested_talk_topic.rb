# == Schema Information
#
# Table name: requested_talk_topics
# Database name: primary
#
#  id          :integer          not null, primary key
#  description :text
#  status      :string           default("open"), not null, indexed
#  title       :string           not null
#  votes_count :integer          default(0), not null, indexed
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null, indexed
#
# Indexes
#
#  index_requested_talk_topics_on_status       (status)
#  index_requested_talk_topics_on_user_id      (user_id)
#  index_requested_talk_topics_on_votes_count  (votes_count)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class RequestedTalkTopic < ApplicationRecord
  belongs_to :user

  has_many :requested_talk_topic_votes, dependent: :destroy
  has_many :voters, through: :requested_talk_topic_votes, source: :user

  validates :title, presence: true
  validates :description, presence: true

  enum :status, {
    open: "open",
    planned: "planned",
    presented: "presented",
    closed: "closed"
  }

  scope :search, ->(query) {
    return all if query.blank?

    query = "%#{query.downcase}%"

    where(
      "LOWER(title) LIKE :query OR LOWER(description) LIKE :query",
      query: query
    )
  }

  scope :with_status, ->(status) {
    status.present? ? where(status: status) : all
  }

  scope :sorted, ->(sort) {
    case sort
    when "newest"
      order(created_at: :desc)
    when "oldest"
      order(created_at: :asc)
    when "least_votes"
      order(votes_count: :asc)
    else
      order(votes_count: :desc)
    end
  }
end
