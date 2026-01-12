class CreateFavoriteUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :favorite_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :favorite_user, null: false, foreign_key: {to_table: :users}

      t.timestamps
    end
  end
end
