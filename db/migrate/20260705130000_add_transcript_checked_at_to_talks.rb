class AddTranscriptCheckedAtToTalks < ActiveRecord::Migration[8.2]
  def change
    add_column :talks, :transcript_checked_at, :datetime
  end
end
