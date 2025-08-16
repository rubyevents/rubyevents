# frozen_string_literal: true

class AddDatePrecisionToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :date_precision, :string, null: false, default: "day"

    Event.all.each do |event|
      event.update(start_date: event.static_metadata.start_date, end_date: event.static_metadata.end_date)
    end

    Event.find_in_batches.each do |events|
      events.each do |event|
        if event.static_metadata.meetup?
          event.update!(kind: "meetup")
        elsif event.static_metadata.conference?
          event.update!(kind: "conference")
        else
          event.update!(kind: "event")
        end
      end
    end
  end
end
