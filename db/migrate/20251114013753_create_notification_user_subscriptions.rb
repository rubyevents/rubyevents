class CreateNotificationUserSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_user_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notification, null: false, foreign_key: true
      t.integer :object_id
      t.string :object_class

      t.timestamps
    end
  end
end
