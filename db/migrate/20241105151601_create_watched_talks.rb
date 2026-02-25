class CreateWatchedTalks < ActiveRecord::Migration[8.0]
  def change
    create_table :watched_talks do |t|
      t.belongs_to :user, null: false
      t.belongs_to :talk, null: false

      t.timestamps

      t.index [:talk_id, :user_id], unique: true
    end
  end
end
