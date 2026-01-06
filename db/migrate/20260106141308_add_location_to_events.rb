class AddLocationToEvents < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :location, :string
  end
end
