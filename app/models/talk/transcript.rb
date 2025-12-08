# == Schema Information
#
# Table name: talk_transcripts
# Database name: primary
#
#  id                  :integer          not null, primary key
#  enhanced_transcript :text
#  raw_transcript      :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  talk_id             :integer          not null, indexed
#
# Indexes
#
#  index_talk_transcripts_on_talk_id  (talk_id)
#
# Foreign Keys
#
#  talk_id  (talk_id => talks.id)
#
class Talk::Transcript < ApplicationRecord
  belongs_to :talk, touch: true

  serialize :enhanced_transcript, coder: TranscriptSerializer
  serialize :raw_transcript, coder: TranscriptSerializer

  def transcript
    enhanced_transcript.presence || raw_transcript
  end
end
