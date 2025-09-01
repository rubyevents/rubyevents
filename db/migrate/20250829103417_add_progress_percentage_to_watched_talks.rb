class AddProgressPercentageToWatchedTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :watched_talks, :progress_percentage, :float, default: 0.0, null: false
  end
end
