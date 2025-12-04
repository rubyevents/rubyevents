class AddStaticIdToTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :talks, :static_id, :string
    add_index :talks, :static_id, unique: true
  end
end
