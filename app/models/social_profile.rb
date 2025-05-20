# == Schema Information
#
# Table name: social_profiles
#
#  id            :integer          not null, primary key
#  provider      :string           not null
#  sociable_type :string           not null, indexed => [sociable_id]
#  value         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  sociable_id   :integer          not null, indexed => [sociable_type]
#
# Indexes
#
#  index_social_profiles_on_sociable  (sociable_type,sociable_id)
#
class SocialProfile < ApplicationRecord
  include Suggestable
  PROVIDERS = %w[twitter linkedin bsky mastodon speakerdeck website]

  belongs_to :sociable, polymorphic: true

  enum :provider, PROVIDERS.index_by(&:itself), validate: {presence: true}

  after_initialize do
    self.value = self.class.normalize_value_for(provider.to_sym, value) if provider.present?
  end

  validates :provider, presence: true
  validates :value, presence: true, uniqueness: {scope: :provider}

  scope :excluding_provider, ->(provider) { where.not(provider:) }

  # normalizes
  normalizes :twitter, with: ->(value) { value.gsub(%r{https?://(?:www\.)?(?:x\.com|twitter\.com)/}, "").gsub(/@/, "") }
  normalizes :linkedin, with: ->(value) { value.gsub(%r{https?://(?:www\.)?(?:linkedin\.com/in)/}, "") }
  normalizes :bsky, with: ->(value) { value.gsub(%r{https?://(?:www\.)?(?:x\.com|bsky\.app/profile)/}, "").gsub(/@/, "") }
  normalizes :speakerdeck, with: ->(value) { value.gsub(/^(?:https?:\/\/)?(?:www\.)?speakerdeck\.com\//, "").gsub(/^@/, "") }
  normalizes :mastodon, with: ->(value) {
    return value if value&.match?(URI::DEFAULT_PARSER.make_regexp)
    return "" unless value.count("@") == 2

    _, handle, instance = value.split("@")

    "https://#{instance}/@#{handle}"
  }

  def url
    case provider.to_sym
    when :twitter, :speakerdeck
      "https://#{provider}.com/#{value}"
    when :linkedin
      "https://linkedin.com/in/#{value}"
    when :bsky
      "https://bsky.app/profile/#{value}"
    else
      value
    end
  end

  private

  def managed_by?(visiting_user)
    sociable.managed_by?(visiting_user)
  end
end
