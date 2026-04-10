class AddVideoAvailabilityFieldsToTalks < ActiveRecord::Migration[8.2]
  def change
    add_column :talks, :video_unavailable_at, :datetime
    add_column :talks, :video_availability_checked_at, :datetime
  end
end
