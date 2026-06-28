class BackfillEventSeriesSubscriptionsFromParticipations < ActiveRecord::Migration[8.2]
  def up
    execute <<~SQL
      INSERT INTO event_series_subscriptions (user_id, event_series_id, created_at, updated_at)
      SELECT DISTINCT ep.user_id, e.event_series_id, MIN(ep.created_at), MIN(ep.created_at)
      FROM event_participations ep
      INNER JOIN events e ON e.id = ep.event_id
      WHERE e.event_series_id IS NOT NULL
        AND ep.attended_as = 'visitor'
      GROUP BY ep.user_id, e.event_series_id
      ON CONFLICT (user_id, event_series_id) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM event_series_subscriptions
      WHERE id IN (
        SELECT esf.id
        FROM event_series_subscriptions esf
        INNER JOIN event_participations ep ON ep.user_id = esf.user_id AND ep.attended_as = 'visitor'
        INNER JOIN events e ON e.id = ep.event_id AND e.event_series_id = esf.event_series_id
      )
    SQL
  end
end
