class AddCompletedToWatchedTalks < ActiveRecord::Migration[8.1]
  def up
    add_column :watched_talks, :completed, :boolean, default: false, null: false

    execute "UPDATE watched_talks SET completed = true"
  end

  def down
    remove_column :watched_talks, :completed
  end
end
