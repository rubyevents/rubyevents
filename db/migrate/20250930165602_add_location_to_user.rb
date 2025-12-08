class AddLocationToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :location, :string, default: ""
  end
end
