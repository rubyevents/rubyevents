class AddPublishedAtAndAnnouncedAtToTalk < ActiveRecord::Migration[8.0]
  def change
    add_column :talks, :announced_at, :datetime, null: true
    add_column :talks, :published_at, :datetime, null: true
  end
end
