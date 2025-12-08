class CreateUserTalks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_talks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :talk, null: false, foreign_key: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :user_talks, [:user_id, :talk_id], unique: true
  end
end
