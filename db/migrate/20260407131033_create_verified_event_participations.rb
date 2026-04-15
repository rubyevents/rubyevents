class CreateVerifiedEventParticipations < ActiveRecord::Migration[8.2]
  def change
    create_table :verified_event_participations do |t|
      t.string :connect_id, null: false
      t.references :event, null: false, foreign_key: true
      t.datetime :scanned_at, null: false

      t.timestamps
    end

    add_index :verified_event_participations, [:connect_id, :event_id], unique: true
    add_index :verified_event_participations, :connect_id
  end
end
