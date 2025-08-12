# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: speakers
#
#  id              :integer          not null, primary key
#  bio             :text             default(""), not null
#  bsky            :string           default(""), not null
#  bsky_metadata   :json             not null
#  github          :string           default(""), not null, uniquely indexed
#  github_metadata :json             not null
#  linkedin        :string           default(""), not null
#  mastodon        :string           default(""), not null
#  name            :string           default(""), not null, indexed
#  pronouns        :string           default(""), not null
#  pronouns_type   :string           default("not_specified"), not null
#  slug            :string           default(""), not null, uniquely indexed
#  speakerdeck     :string           default(""), not null
#  talks_count     :integer          default(0), not null
#  twitter         :string           default(""), not null
#  website         :string           default(""), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  canonical_id    :integer          indexed
#
# Indexes
#
#  index_speakers_on_canonical_id  (canonical_id)
#  index_speakers_on_github        (github) UNIQUE WHERE github IS NOT NULL AND github != ''
#  index_speakers_on_name          (name)
#  index_speakers_on_slug          (slug) UNIQUE
#
# Foreign Keys
#
#  canonical_id  (canonical_id => speakers.id)
#
# rubocop:enable Layout/LineLength
class Speaker < ApplicationRecord
  include ActionView::RecordIdentifier
  include Sluggable
  include Suggestable
  include Speaker::Searchable
  configure_slug(attribute: :name, auto_suffix_on_collision: true)

  PRONOUNS = {
    "Not specified": :not_specified,
    "Don't specify": :dont_specify,
    "they/them": :they_them,
    "she/her": :she_her,
    "he/him": :he_him,
    Custom: :custom
  }.freeze

  # associations
  has_many :speaker_talks, dependent: :destroy, inverse_of: :speaker, foreign_key: :speaker_id
  has_many :talks, through: :speaker_talks, inverse_of: :speakers
  has_many :kept_talks, -> { joins(:speaker_talks).where(speaker_talks: {discarded_at: nil}).distinct },
    through: :speaker_talks, inverse_of: :speakers, class_name: "Talk", source: :talk
  has_many :events, -> { distinct }, through: :talks, inverse_of: :speakers
  has_many :aliases, class_name: "Speaker", foreign_key: "canonical_id"
  has_many :topics, through: :talks

  belongs_to :canonical, class_name: "Speaker", optional: true
  belongs_to :user, primary_key: :github_handle, foreign_key: :github, optional: true

  has_object :profiles

  # validations
  validates :canonical, exclusion: {in: ->(speaker) { [speaker] }, message: "can't be itself"}
  validates :github, uniqueness: {case_sensitive: false}, allow_blank: true

  # scope
  scope :with_talks, -> { where.not(talks_count: 0) }
  scope :with_github, -> { where.not(github: "") }
  scope :without_github, -> { where(github: "") }
  scope :canonical, -> { where(canonical_id: nil) }
  scope :not_canonical, -> { where.not(canonical_id: nil) }

  # normalizes
  normalizes :github, with: ->(value) {
    value.gsub(/^(?:https?:\/\/)?(?:www\.)?github\.com\//, "").gsub(/^@/, "").downcase
  }
  normalizes :twitter, with: ->(value) { value.gsub(%r{https?://(?:www\.)?(?:x\.com|twitter\.com)/}, "").gsub(/@/, "") }
  normalizes :bsky, with: ->(value) {
                            value.gsub(%r{https?://(?:www\.)?(?:x\.com|bsky\.app/profile)/}, "").gsub(/@/, "")
                          }
  normalizes :linkedin, with: ->(value) { value.gsub(%r{https?://(?:www\.)?(?:linkedin\.com/in)/}, "") }
  normalizes :bsky, with: ->(value) { value.gsub(%r{https?://(?:www\.)?(?:[^\/]+\.com)/}, "").gsub(/@/, "") }

  normalizes :mastodon, with: ->(value) {
    return value if value&.match?(URI::DEFAULT_PARSER.make_regexp)
    return "" unless value.count("@") == 2

    _, handle, instance = value.split("@")

    "https://#{instance}/@#{handle}"
  }

  normalizes :website, with: ->(website) {
    return "" if website.blank?

    # if it already starts with https://, return as is
    return website if website.start_with?("https://")

    # if it starts with http://, return as is
    return website if website.start_with?("http://")

    # otherwise, prepend https://
    "https://#{website}"
  }

  def self.reset_talks_counts
    find_each do |speaker|
      speaker.update_column(:talks_count, speaker.talks.count)
    end
  end

  def title
    name
  end

  def canonical_slug
    canonical&.slug
  end

  def verified?
    user.present?
  end

  def managed_by?(visiting_user)
    return false unless visiting_user.present?
    return true if visiting_user.admin?

    user == visiting_user
  end

  def create_suggestion_from(params:, user: Current.user)
    if (params.key?("github") || params.key?("slug")) && managed_by?(self.user)
      slug = params["slug"]
      github = params["github"]

      content = {}
      content["slug"] = slug if slug
      content["github"] = github if github

      params = params.reject { |key, _value| key.in?(["github", "slug"]) }

      suggestion = suggestions.create(content: content, suggested_by_id: user&.id)

      return suggestion if params.keys.none?
    end

    super
  end

  def avatar_url(...)
    bsky_avatar_url(...) || github_avatar_url(...) || fallback_avatar_url(...)
  end

  def avatar_rank
    return 1 if bsky_avatar_url.present?
    return 2 if github_avatar_url.present?

    3
  end

  def custom_avatar?
    bsky_avatar_url.present? || github_avatar_url.present?
  end

  def bsky_avatar_url(...)
    bsky_metadata.dig("avatar")
  end

  def github_avatar_url(size: 200)
    return nil if github.blank?

    metadata_avatar_url = github_metadata.dig("profile", "avatar_url")

    return "#{metadata_avatar_url}&size=#{size}" if metadata_avatar_url.present?

    "https://github.com/#{github}.png?size=#{size}"
  end

  def fallback_avatar_url(size: 200)
    url_safe_initials = name.split(" ").map(&:first).join("+")

    "https://ui-avatars.com/api/?name=#{url_safe_initials}&size=#{size}&background=DC133C&color=fff"
  end

  def broadcast_header
    broadcast_update target: dom_id(self, :header_content), partial: "speakers/header_content", locals: {speaker: self}
  end

  def to_meta_tags
    {
      title: name,
      description: meta_description,
      og: {
        title: name,
        type: :website,
        image: {
          _: github_avatar_url,
          alt: name
        },
        description: meta_description,
        site_name: "RubyEvents.org"
      },
      twitter: {
        card: "summary",
        site: "@#{twitter}",
        title: name,
        description: meta_description,
        image: {
          src: github_avatar_url
        }
      }
    }
  end

  def to_combobox_display
    name
  end

  def meta_description
    <<~HEREDOC
      Discover all the talks given by #{name} on subjects related to Ruby language or Ruby Frameworks such as Rails, Hanami and others
    HEREDOC
  end

  def assign_canonical_speaker!(canonical_speaker:)
    ActiveRecord::Base.transaction do
      self.canonical = canonical_speaker
      self.github = ""
      save!

      speaker_talks.each do |speaker_talk|
        SpeakerTalk.create(talk: speaker_talk.talk, speaker: canonical_speaker)
      end

      # We need to destroy the remaining speaker_talks. They can be remaining given the unicity constraint
      # on the speaker_talks table. The update above swallows the error if the speaker_talk duet exists already
      SpeakerTalk.where(speaker_id: id).destroy_all
    end
  end

  def primary_speaker
    canonical || self
  end

  # Add this method for rejecting a speaker
  def rejected!
    ActiveRecord::Base.transaction do
      update!(status: :rejected)
      SpeakerTalk.where(speaker_id: id).destroy_all
    end
  end

  def suggestion_summary
    <<~HEREDOC
      Speaker: #{name}
      github: #{github}
      twitter: #{twitter}
      website: #{website}
      bio: #{bio}
    HEREDOC
  end

  def to_mobile_json(request)
    {
      id: id,
      name: name,
      slug: slug,
      avatar_url: avatar_url,
      url: Router.speaker_url(self, host: "#{request.protocol}#{request.host}:#{request.port}")
    }
  end
end
