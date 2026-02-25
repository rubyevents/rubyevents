class AddBskyMetadataToSpeaker < ActiveRecord::Migration[8.0]
  def change
    add_column :speakers, :bsky_metadata, :jsonb, null: false, default: {}
  end
end
