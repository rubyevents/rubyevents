class AddNotesToFavoriteUser < ActiveRecord::Migration[8.2]
  def change
    add_column :favorite_users, :notes, :text
  end
end
