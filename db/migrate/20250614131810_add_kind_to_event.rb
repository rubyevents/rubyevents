class AddKindToEvent < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :kind, :string, default: "event", null: false
    add_index :events, :kind
  end

  def down
    remove_index :events, :kind
    remove_column :events, :kind
  end
end
