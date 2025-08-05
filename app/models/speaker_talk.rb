# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: speaker_talks
#
#  id           :integer          not null, primary key
#  discarded_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  speaker_id   :integer          not null, indexed, uniquely indexed => [talk_id]
#  talk_id      :integer          not null, uniquely indexed => [speaker_id], indexed
#
# Indexes
#
#  index_speaker_talks_on_speaker_id              (speaker_id)
#  index_speaker_talks_on_speaker_id_and_talk_id  (speaker_id,talk_id) UNIQUE
#  index_speaker_talks_on_talk_id                 (talk_id)
#
# rubocop:enable Layout/LineLength
class SpeakerTalk < ApplicationRecord
  self.table_name = "speaker_talks"

  # mixins
  include Discard::Model

  # associations
  belongs_to :speaker
  belongs_to :talk, touch: true

  validates :speaker_id, uniqueness: {scope: :talk_id}

  # callbacks
  after_commit :update_speaker_talks_count

  private

  def update_speaker_talks_count
    speaker.update_column(:talks_count, speaker.kept_talks.count)
  end
end
