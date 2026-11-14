class TouchEventParticipations < ActiveRecord::Migration[8.2]
  # SimplifyEventParticipationRoles renamed roles (e.g. visitor -> attendee) with
  # raw SQL that didn't bump updated_at, so cached profile event cards kept
  # showing the old role. Touching every row invalidates those cache entries.
  def up
    execute "UPDATE event_participations SET updated_at = CURRENT_TIMESTAMP"
  end

  def down
  end
end
