# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: topics
# Database name: primary
#
#  id           :integer          not null, primary key
#  description  :text
#  name         :string           uniquely indexed
#  published    :boolean          default(FALSE)
#  slug         :string           default(""), not null, indexed
#  status       :string           default("pending"), not null, indexed
#  talks_count  :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  canonical_id :integer          indexed
#
# Indexes
#
#  index_topics_on_canonical_id  (canonical_id)
#  index_topics_on_name          (name) UNIQUE
#  index_topics_on_slug          (slug)
#  index_topics_on_status        (status)
#
# Foreign Keys
#
#  canonical_id  (canonical_id => topics.id)
#
# rubocop:enable Layout/LineLength
class Topic < ApplicationRecord
  include Sluggable
  include Topic::TypesenseSearchable

  has_object :gem_info

  configure_slug(attribute: :name, auto_suffix_on_collision: false)

  has_many :talk_topics
  has_many :talks, through: :talk_topics
  has_many :topic_gems, dependent: :destroy
  belongs_to :canonical, class_name: "Topic", optional: true
  has_many :aliases, class_name: "Topic", foreign_key: "canonical_id"

  # validations
  validates :name, presence: true, uniqueness: true
  validates :canonical, exclusion: {in: ->(topic) { [topic] }, message: "can't be itself"}

  # normalize attributes
  normalizes :name, with: ->(name) { name.squish }

  # scopes
  scope :with_talks, -> { where("talks_count >= 1") }
  scope :without_talks, -> { where(talks_count: 0) }
  scope :with_n_talk, ->(n) { where("talks_count = ?", n) }

  scope :canonical, -> { where(canonical_id: nil) }
  scope :not_canonical, -> { where.not(canonical_id: nil) }

  # enums
  enum :status, %w[pending approved rejected duplicate].index_by(&:itself)

  def self.create_from_list(topics, status: :pending)
    topics.map { |topic|
      slug = topic.parameterize
      Topic.find_by(slug: slug)&.primary_topic || Topic.find_or_create_by(name: topic.squish) { |t| t.status = status }
    }.uniq
  end

  def assign_canonical_topic!(canonical_topic:)
    ActiveRecord::Base.transaction do
      self.canonical = canonical_topic
      save!

      talk_topics.each do |talk_topic|
        talk_topic.update(topic: canonical_topic)
      end

      # We need to destroy the remaining topics. They can be remaining topics given the unicity constraint
      # on the talk_topics table. the update above swallows the error if the talk_topic duet exists already
      TalkTopic.where(topic_id: id).destroy_all
      duplicate!
    end
  end

  def primary_topic
    canonical || self
  end

  def to_meta_tags
    {
      title: name,
      description: description,
      og: {
        title: name,
        type: :website,
        description: description,
        site_name: "RubyEvents.org"
      },
      twitter: {
        card: "summary",
        title: name,
        description: description
      }
    }
  end

  # enums state machine

  def rejected!
    ActiveRecord::Base.transaction do
      update!(status: :rejected)
      TalkTopic.where(topic_id: id).destroy_all
    end
  end
end
