class AddFeedbackToWatchedTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :watched_talks, :watched_on, :string
    add_column :watched_talks, :watched_at, :datetime
    add_column :watched_talks, :feedback, :json, default: {}
  end
end
