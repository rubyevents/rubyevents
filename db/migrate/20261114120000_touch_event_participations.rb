class TouchEventParticipations < ActiveRecord::Migration[8.2]
  def up
    execute "UPDATE event_participations SET updated_at = CURRENT_TIMESTAMP"
  end

  def down
  end
end
