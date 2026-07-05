class AddRecordingsPublishedDateToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :recordings_published_date, :date
  end
end
