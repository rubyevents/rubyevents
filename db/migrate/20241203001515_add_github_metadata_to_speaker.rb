class AddGitHubMetadataToSpeaker < ActiveRecord::Migration[8.0]
  def change
    add_column :speakers, :github_metadata, :jsonb, null: false, default: {}
  end
end
