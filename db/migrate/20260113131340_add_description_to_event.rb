class AddDescriptionToEvent < ActiveRecord::Migration[8.2]
  def change
    add_column :events, :description, :string
  end
end
