class BackfillWatchedAtOnWatchedTalks < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      UPDATE watched_talks
      SET watched_at = created_at
      WHERE watched_at IS NULL
    SQL

    change_column_null :watched_talks, :watched_at, false
  end

  def down
    change_column_null :watched_talks, :watched_at, true
  end
end
