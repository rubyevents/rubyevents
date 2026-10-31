class CreateSubscriptions < ActiveRecord::Migration[8.2]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :subscribable, null: false, polymorphic: true
      t.text :notes

      t.timestamps
    end

    add_index :subscriptions, [:user_id, :subscribable_type, :subscribable_id], unique: true
  end
end
