class AddWatchedToWatchedTalks < ActiveRecord::Migration[8.1]
  def up
    add_column :watched_talks, :watched, :boolean, default: false

    execute <<-SQL
      UPDATE watched_talks
      SET watched = true
    SQL

    change_column_null :watched_talks, :watched, false
  end

  def down
    remove_column :watched_talks, :watched
  end
end
