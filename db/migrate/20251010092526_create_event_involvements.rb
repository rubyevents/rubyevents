class CreateEventInvolvements < ActiveRecord::Migration[8.1]
  def change
    create_table :event_involvements do |t|
      t.references :involvementable, polymorphic: true, null: false
      t.references :event, null: false, foreign_key: true
      t.string :role, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :event_involvements, [:involvementable_type, :involvementable_id, :event_id, :role], unique: true, name: "idx_involvements_on_involvementable_and_event_and_role"
    add_index :event_involvements, :role
  end
end
