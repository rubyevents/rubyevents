class AddYouTubeThumbnailCheckedAtToTalks < ActiveRecord::Migration[8.2]
  def change
    add_column :talks, :youtube_thumbnail_checked_at, :datetime
  end
end
