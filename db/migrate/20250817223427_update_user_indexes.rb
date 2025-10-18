class UpdateUserIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :github_handle, name: :index_users_on_github_handle
    remove_index :users, :email, name: :index_users_on_email
    remove_index :users, :name, name: :index_users_on_name
    remove_index :users, :slug, name: :index_users_on_slug

    add_index :users, :github_handle, unique: true, where: "github_handle IS NOT NULL AND github_handle != ''"
    add_index :users, :email
    add_index :users, :name
    add_index :users, :slug, unique: true, where: "slug IS NOT NULL AND slug != ''"
  end
end
