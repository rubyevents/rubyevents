class AddWrappedPublicToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :wrapped_public, :boolean, default: false, null: false
  end
end
