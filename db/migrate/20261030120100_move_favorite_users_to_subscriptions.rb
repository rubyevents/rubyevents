class MoveFavoriteUsersToSubscriptions < ActiveRecord::Migration[8.2]
  def up
    execute <<~SQL
      INSERT INTO subscriptions (user_id, subscribable_type, subscribable_id, notes, created_at, updated_at)
      SELECT user_id, 'User', favorite_user_id, notes, created_at, updated_at
      FROM favorite_users
      WHERE user_id != favorite_user_id
      ORDER BY id
      ON CONFLICT (user_id, subscribable_type, subscribable_id) DO NOTHING
    SQL

    drop_table :favorite_users
  end

  def down
    create_table :favorite_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :favorite_user, null: false, foreign_key: {to_table: :users}
      t.text :notes

      t.timestamps
    end

    execute <<~SQL
      INSERT INTO favorite_users (user_id, favorite_user_id, notes, created_at, updated_at)
      SELECT user_id, subscribable_id, notes, created_at, updated_at
      FROM subscriptions
      WHERE subscribable_type = 'User'
      ORDER BY id
    SQL

    execute "DELETE FROM subscriptions WHERE subscribable_type = 'User'"
  end
end
