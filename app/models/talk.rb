# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: talks
#
#  id             :integer          not null, primary key
#  title          :string           default(""), not null
#  description    :text             default(""), not null
#  slug           :string           default(""), not null
#  video_id       :string           default(""), not null
#  video_provider :string           default(""), not null
#  thumbnail_sm   :string           default(""), not null
#  thumbnail_md   :string           default(""), not null
#  thumbnail_lg   :string           default(""), not null
#  year           :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_id       :integer
#
# rubocop:enable Layout/LineLength
class Talk < ApplicationRecord
  include Sluggable
  include Suggestable
  slug_from :title
  include MeiliSearch::Rails
  extend Pagy::Meilisearch

  # associations
  belongs_to :event, optional: true
  has_many :speaker_talks, dependent: :destroy, inverse_of: :talk, foreign_key: :talk_id
  has_many :speakers, through: :speaker_talks

  # validations
  validates :title, presence: true

  # delegates
  delegate :name, to: :event, prefix: true, allow_nil: true

  # search
  meilisearch enqueue: true, raise_on_failure: Rails.env.development? do
    attribute :title
    attribute :description
    attribute :slug
    attribute :video_id
    attribute :video_provider
    attribute :thumbnail_sm
    attribute :thumbnail_md
    attribute :thumbnail_lg
    attribute :speakers do
      speakers.pluck(:name)
    end
    add_attribute :_vector do
      _vector # doesn't work yet
    end
    searchable_attributes [:title, :description, :_vector]
    sortable_attributes [:title]

    attributes_to_highlight ["*"]
  end

  def to_meta_tags
    {
      title: title,
      description: description
    }
  end

  def thumbnail_xs
    self[:thumbnail_xs].presence || "https://i.ytimg.com/vi/#{video_id}/default.jpg"
  end

  def thumbnail_sm
    self[:thumbnail_sm].presence || "https://i.ytimg.com/vi/#{video_id}/mqdefault.jpg"
  end

  def thumbnail_md
    self[:thumbnail_md].presence || "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"
  end

  def thumbnail_lg
    self[:thumbnail_lg].presence || "https://i.ytimg.com/vi/#{video_id}/sddefault.jpg"
  end

  def thumbnail_xl
    self[:thumbnail_xl].presence || "https://i.ytimg.com/vi/#{video_id}/maxresdefault.jpg"
  end

  def _vector
    return nil unless ENV["OPENAI_ACCESS_TOKEN"].present?
    @_vector ||= self.class.embedding(title, description)
  end

  def self.embedding(*inputs)
    client = OpenAI::Client.new
    response = client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",
        input: inputs.join("\n\n"),
      },
    )
    response.dig("data", 0, "embedding")
  end
end
