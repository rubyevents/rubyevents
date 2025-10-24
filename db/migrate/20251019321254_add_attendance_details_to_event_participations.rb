class AddAttendanceDetailsToEventParticipations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_participations, :verified_at, :timestamp
    add_column :event_participations, :attendance_details, :json
  end
end
