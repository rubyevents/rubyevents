# == Schema Information
#
# Table name: watched_talks
# Database name: primary
#
#  id                 :integer          not null, primary key
#  feedback           :json
#  feedback_shared_at :datetime
#  progress_seconds   :integer          default(0), not null
#  watched            :boolean          default(FALSE), not null
#  watched_at         :datetime         not null
#  watched_on         :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  talk_id            :integer          not null, indexed, uniquely indexed => [user_id]
#  user_id            :integer          not null, uniquely indexed => [talk_id], indexed
#
# Indexes
#
#  index_watched_talks_on_talk_id              (talk_id)
#  index_watched_talks_on_talk_id_and_user_id  (talk_id,user_id) UNIQUE
#  index_watched_talks_on_user_id              (user_id)
#
class WatchedTalk < ApplicationRecord
  WATCHED_ON_OPTIONS = {
    "in_person" => {label: "In-person", icon: "users"},
    "rubyevents" => {label: "RubyEvents.org", icon: "globe"},
    "youtube" => {label: "YouTube", icon: "youtube-brands"},
    "vimeo" => {label: "Vimeo", icon: "vimeo-v-brands"},
    "mp4" => {label: "Direct video", icon: "video"},
    "another_version" => {label: "Another version of this talk", icon: "clone"},
    "other" => {label: "Other", icon: "ellipsis"}
  }.freeze

  # These are designed to be constructive feedback for speakers
  FEEDBACK_QUESTIONS = {
    "liked" => {label: "Did you enjoy this talk?", icon: "heart"},
    "would_recommend" => {label: "Would you recommend it to others?", icon: "thumbs-up"},
    "beginner_friendly" => {label: "Good for early-career devs?", icon: "seedling"},
    "learned_something" => {label: "Did you learn something new?", icon: "lightbulb"},
    "clear_delivery" => {label: "Was it easy to follow?", icon: "comment-check"},
    "inspiring" => {label: "Did it inspire you to learn more?", icon: "rocket"}
  }.freeze

  FEELING_OPTIONS = {
    "enjoyed" => {emoji: "face-smile", label: "Enjoyed", selected_class: "border-green-500 bg-green-500 text-white hover:bg-green-600"},
    "excited" => {emoji: "party-horn", label: "Excited", selected_class: "border-orange-500 bg-orange-500 text-white hover:bg-orange-600"},
    "inspired" => {emoji: "lightbulb", label: "Inspired", selected_class: "border-yellow-500 bg-yellow-500 text-white hover:bg-yellow-600"},
    "surprised" => {emoji: "face-surprise", label: "Surprised", selected_class: "border-pink-500 bg-pink-500 text-white hover:bg-pink-600"},
    "mind_blown" => {emoji: "face-explode", label: "Mind-blown", selected_class: "border-purple-500 bg-purple-500 text-white hover:bg-purple-600"},
    "reflective" => {emoji: "face-thinking", label: "Reflective", selected_class: "border-blue-500 bg-blue-500 text-white hover:bg-blue-600"},
    "neutral" => {emoji: "face-meh", label: "Neutral", selected_class: "border-gray-400 bg-gray-400 text-white hover:bg-gray-500"},
    "not_for_me" => {emoji: "face-meh-blank", label: "Not for me", selected_class: "border-gray-500 bg-gray-500 text-white hover:bg-gray-600"}
  }.freeze

  belongs_to :user, default: -> { Current.user }, touch: true, counter_cache: :watched_talks_count
  belongs_to :talk

  scope :watched, -> { where(watched: true) }
  scope :in_progress, -> { where(watched: false).where("progress_seconds > 0") }

  store_accessor :feedback, *FEEDBACK_QUESTIONS.keys, :feeling
  before_create :set_default_watched_at

  private

  def set_default_watched_at
    self.watched_at ||= Time.current
  end

  public

  def progress_percentage
    return 0.0 unless progress_seconds && talk.duration_in_seconds
    return 0.0 if talk.duration_in_seconds.zero?

    (progress_seconds.to_f / talk.duration_in_seconds * 100).round(2)
  end

  def has_feedback?
    watched_on.present? || has_rating_feedback?
  end

  def has_rating_feedback?
    feeling.present? || (feedback.present? && feedback.values.any?(&:present?))
  end

  def in_progress?
    !watched? && progress_seconds.positive?
  end

  def self.watched_on_options_for(talk)
    provider = talk.video_provider
    video_providers = %w[youtube vimeo mp4]

    options = WATCHED_ON_OPTIONS.reject do |key, _|
      key.in?(video_providers) && key != provider
    end

    if provider.in?(Talk::WATCHABLE_PROVIDERS) && !options.key?(provider)
      options[provider] = {label: provider.titleize, icon: "video"}
    end

    options
  end
end
