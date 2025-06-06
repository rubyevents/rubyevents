class AddStartAndEndDateToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :start_date, :date
    add_column :events, :end_date, :date

    Event.all.each do |event|
      event.update(start_date: event.static_metadata.start_date, end_date: event.static_metadata.end_date)
    end
  end
end
