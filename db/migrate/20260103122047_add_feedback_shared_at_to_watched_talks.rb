class AddFeedbackSharedAtToWatchedTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :watched_talks, :feedback_shared_at, :datetime
  end
end
