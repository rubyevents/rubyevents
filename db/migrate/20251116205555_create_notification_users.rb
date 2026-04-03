class CreateNotificationUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_users do |t|
      t.references :notification, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :object_id, null: false
      t.string :object_class, null: false
      t.boolean :read, default: false, null: false

      t.timestamps
    end
  end
end
