class SimplifyEventParticipationRoles < ActiveRecord::Migration[8.2]
  def up
    # keep only the highest-ranked participation per user and event
    execute <<~SQL
      DELETE FROM event_participations
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY user_id, event_id
            ORDER BY CASE attended_as
              WHEN 'keynote_speaker' THEN 3
              WHEN 'speaker' THEN 3
              WHEN 'visitor' THEN 2
              ELSE 1
            END DESC, id ASC
          ) AS position
          FROM event_participations
        ) WHERE position = 1
      )
    SQL

    execute "UPDATE event_participations SET attended_as = 'speaker' WHERE attended_as = 'keynote_speaker'"
    execute "UPDATE event_participations SET attended_as = 'attendee' WHERE attended_as = 'visitor'"

    remove_index :event_participations, [:user_id, :event_id, :attended_as]
    rename_column :event_participations, :attended_as, :role
    add_index :event_participations, [:user_id, :event_id], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
