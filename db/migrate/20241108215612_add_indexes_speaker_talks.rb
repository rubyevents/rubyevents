class AddIndexesSpeakerTalks < ActiveRecord::Migration[8.0]
  def change
    add_index :speaker_talks, :speaker_id
    add_index :speaker_talks, :talk_id
  end
end
