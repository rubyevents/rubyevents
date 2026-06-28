class CreateEventSeriesSubscriptions < ActiveRecord::Migration[8.2]
  def change
    create_table :event_series_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event_series, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_series_subscriptions, [:user_id, :event_series_id], unique: true
  end
end
