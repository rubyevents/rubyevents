class AddConnectIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :connect_id, :string
  end
end
