# == Schema Information
#
# Table name: talk_transcripts
# Database name: primary
#
#  id                  :integer          not null, primary key
#  auto_generated      :boolean
#  enhanced_transcript :text
#  language            :string           default("en"), not null, uniquely indexed => [talk_id]
#  raw_transcript      :text
#  translated          :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  talk_id             :integer          not null, indexed, uniquely indexed => [language]
#
# Indexes
#
#  index_talk_transcripts_on_talk_id               (talk_id)
#  index_talk_transcripts_on_talk_id_and_language  (talk_id,language) UNIQUE
#
# Foreign Keys
#
#  talk_id  (talk_id => talks.id)
#
class Talk::Transcript < ApplicationRecord
  belongs_to :talk, touch: true

  serialize :enhanced_transcript, coder: Talk::Transcript::Serializer
  serialize :raw_transcript, coder: Talk::Transcript::Serializer

  validates :language, presence: true, uniqueness: {scope: :talk_id}

  scope :empty, -> { where("raw_transcript IS NULL OR raw_transcript = '[]'") }
  scope :by_language, ->(language) { where(language: language) }

  def transcript
    enhanced_transcript.presence || raw_transcript
  end
end
