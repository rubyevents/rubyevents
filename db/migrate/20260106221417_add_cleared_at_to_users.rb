class AddClearedAtToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :cleared_at, :datetime
  end
end
