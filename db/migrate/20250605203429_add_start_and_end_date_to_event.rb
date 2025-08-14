class AddStartAndEndDateToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :start_date, :date
    add_column :events, :end_date, :date
  end
end
