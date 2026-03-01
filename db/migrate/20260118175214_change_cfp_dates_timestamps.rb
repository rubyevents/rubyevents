class ChangeCFPDatesTimestamps < ActiveRecord::Migration[8.2]
  def up
    change_column :cfps, :open_date, :datetime
    change_column :cfps, :close_date, :datetime
  end

  def down
    change_column :cfps, :open_date, :date
    change_column :cfps, :close_date, :date
  end
end
