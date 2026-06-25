class RemoveRedundantVisitorParticipations < ActiveRecord::Migration[8.2]
  def up
    execute <<-SQL
      DELETE FROM event_participations
      WHERE attended_as = 'visitor'
        AND EXISTS (
          SELECT 1 FROM event_participations AS speaker_participations
          WHERE speaker_participations.user_id = event_participations.user_id
            AND speaker_participations.event_id = event_participations.event_id
            AND speaker_participations.attended_as IN ('speaker', 'keynote_speaker')
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
