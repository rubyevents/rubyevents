class AddYouTubeChannelIdToOrganisation < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :youtube_channel_id, :string, default: "", null: false
    add_column :organisations, :youtube_channel_name, :string, default: "", null: false
  end
end
