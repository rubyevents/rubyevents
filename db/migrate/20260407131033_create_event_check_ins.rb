class CreateEventCheckIns < ActiveRecord::Migration[8.2]
  def change
    create_table :event_check_ins do |t|
      t.string :connect_id, null: false
      t.references :event, null: false, foreign_key: true
      t.datetime :checked_in_at, null: false

      t.timestamps
    end

    add_index :event_check_ins, [:connect_id, :event_id], unique: true
    add_index :event_check_ins, :connect_id
  end
end
