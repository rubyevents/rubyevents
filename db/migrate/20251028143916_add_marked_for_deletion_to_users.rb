class AddMarkedForDeletionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :marked_for_deletion, :boolean, default: false, null: false
    add_index :users, :marked_for_deletion
  end
end
