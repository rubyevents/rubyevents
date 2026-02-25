class AddWatchedTalksCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :watched_talks_count, :integer, default: 0, null: false
  end
end
