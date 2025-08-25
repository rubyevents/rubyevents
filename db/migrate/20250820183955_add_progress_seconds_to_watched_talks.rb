class AddProgressSecondsToWatchedTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :watched_talks, :progress_seconds, :integer, default: 0, null: false
  end
end
