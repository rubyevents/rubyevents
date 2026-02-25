class AddDiscardedAtSpeakerTalk < ActiveRecord::Migration[8.0]
  def change
    add_column :speaker_talks, :discarded_at, :datetime
  end
end
